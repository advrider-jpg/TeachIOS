#!/usr/bin/env python3
"""Probe temporary Xcode project variants on macOS CI.

This diagnostic script never edits the checkout. It copies the project into a
temporary directory, removes selected hand-authored project sections, and runs
`xcodebuild -list` to isolate which section Xcode rejects.
"""
from __future__ import annotations

import os
import pathlib
import re
import shutil
import subprocess


ROOT = pathlib.Path(__file__).resolve().parents[2]
PROJECT = ROOT / "GradeDraft.xcodeproj"
PBXPROJ = PROJECT / "project.pbxproj"
PROBE_ROOT = pathlib.Path(os.environ.get("RUNNER_TEMP", ROOT / ".tmp-xcode-probes")) / "GradeDraftProjectProbes"

UI_TEST_IDS = {
    "A90000000000000000000023",
    "A90000000000000000000024",
    "A90000000000000000000025",
    "A90000000000000000000026",
    "A90000000000000000000027",
    "A90000000000000000000028",
    "A90000000000000000000029",
    "A9000000000000000000002A",
    "A9000000000000000000002B",
    "A9000000000000000000002C",
    "A9000000000000000000002D",
    "A9000000000000000000002E",
    "A90000000000000000000040",
}

BASE_APP_RESOURCES = (
    "\t\t1D1DCE0D308435F6082AAF5E /* Resources */ = {isa = PBXResourcesBuildPhase; "
    "buildActionMask = 2147483647; files = ( F00000000000000000000004 /* Assets.xcassets in Resources */, "
    "7B431331244B2236C5880029 /* PrivacyInfo.xcprivacy in Resources */, "
    "C10000000000000000000200 /* grade_draft_content_catalog.json in Resources */, "
    "F00000000000000000000005 /* curriculum_catalog_acara_v9.json in Resources */, "
    "F00000000000000000000006 /* curriculum_catalog_acara_v9_manifest.json in Resources */, "
    "F00000000000000000000007 /* curriculum_catalog_acara_v9_summary.json in Resources */, ); "
    "runOnlyForDeploymentPostprocessing = 0; };"
)

SECTIONS = [
    "PBXBuildFile",
    "PBXContainerItemProxy",
    "PBXFileReference",
    "PBXFrameworksBuildPhase",
    "PBXGroup",
    "PBXNativeTarget",
    "PBXProject",
    "PBXResourcesBuildPhase",
    "PBXSourcesBuildPhase",
    "PBXTargetDependency",
    "XCRemoteSwiftPackageReference",
    "XCSwiftPackageProductDependency",
    "XCBuildConfiguration",
    "XCConfigurationList",
]


def remove_object_blocks(text: str, object_ids: set[str]) -> str:
    lines = text.splitlines()
    output: list[str] = []
    skip = False
    depth = 0
    for line in lines:
        if not skip:
            match = re.match(r"\t\t([A-Za-z0-9]{24}) (?:/\* .*? \*/ )?= \{", line)
            if match and match.group(1) in object_ids:
                skip = True
                depth = line.count("{") - line.count("}")
                if depth <= 0:
                    skip = False
                continue
            output.append(line)
        else:
            depth += line.count("{") - line.count("}")
            if depth <= 0:
                skip = False
    return "\n".join(output) + "\n"


def remove_references(text: str, object_ids: set[str]) -> str:
    for object_id in object_ids:
        text = re.sub(rf",\s*{object_id} /\* .*? \*/", "", text)
        text = re.sub(rf"{object_id} /\* .*? \*/,\s*", "", text)
        text = re.sub(rf"\n\t+\s*{object_id} /\* .*? \*/,\n", "\n", text)
        text = re.sub(rf"\n\t+\s*{object_id} = \{{ .*? \}};\n", "\n", text)
    return text


def variant_no_ui_target(text: str) -> str:
    return remove_references(remove_object_blocks(text, UI_TEST_IDS), UI_TEST_IDS)


def variant_minimal_resources(text: str) -> str:
    return re.sub(
        r"\t\t1D1DCE0D308435F6082AAF5E /\* Resources \*/ = \{isa = PBXResourcesBuildPhase;.*?runOnlyForDeploymentPostprocessing = 0; \};",
        BASE_APP_RESOURCES,
        text,
        count=1,
    )


def section_pattern(section: str) -> re.Pattern[str]:
    return re.compile(
        rf"/\* Begin {re.escape(section)} section \*/.*?/\* End {re.escape(section)} section \*/",
        re.DOTALL,
    )


def replace_section(text: str, source_text: str, section: str) -> str:
    source_match = section_pattern(section).search(source_text)
    if source_match is None:
        return text
    replacement = source_match.group(0)
    updated, count = section_pattern(section).subn(replacement, text, count=1)
    if count != 1:
        print(f"section {section} not found in destination")
        return text
    return updated


def replace_sections(text: str, source_text: str, sections: list[str]) -> str:
    updated = text
    for section in sections:
        updated = replace_section(updated, source_text, section)
    return updated


def load_main_project_text() -> str:
    result = subprocess.run(
        ["git", "show", "origin/main:GradeDraft.xcodeproj/project.pbxproj"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        subprocess.run(
            ["git", "fetch", "--depth=1", "origin", "main:refs/remotes/origin/main"],
            cwd=ROOT,
            check=True,
        )
        result = subprocess.run(
            ["git", "show", "origin/main:GradeDraft.xcodeproj/project.pbxproj"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    if result.returncode != 0:
        print(result.stderr)
        raise RuntimeError("Unable to load origin/main project.pbxproj for probes")
    return result.stdout


def write_variant(name: str, text: str) -> pathlib.Path:
    destination = PROBE_ROOT / name / "GradeDraft.xcodeproj"
    if destination.parent.exists():
        shutil.rmtree(destination.parent)
    shutil.copytree(PROJECT, destination)
    (destination / "project.pbxproj").write_text(text, encoding="utf-8", newline="\n")
    return destination


def run_list(name: str, project: pathlib.Path) -> int:
    print(f"## probe {name}")
    lint = subprocess.run(
        ["plutil", "-lint", str(project / "project.pbxproj")],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    print(lint.stdout)
    print(f"probe {name} plutil exit: {lint.returncode}")
    result = subprocess.run(
        ["xcodebuild", "-list", "-project", str(project)],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    print(result.stdout)
    print(f"probe {name} exit: {result.returncode}")
    return result.returncode


def main() -> int:
    text = PBXPROJ.read_text(encoding="utf-8")
    main_text = load_main_project_text()
    target_model_sections = [
        "PBXContainerItemProxy",
        "PBXFrameworksBuildPhase",
        "PBXNativeTarget",
        "PBXProject",
        "PBXResourcesBuildPhase",
        "PBXSourcesBuildPhase",
        "PBXTargetDependency",
        "XCBuildConfiguration",
        "XCConfigurationList",
    ]
    variants = {
        "current": text,
        "origin-main-pbxproj": main_text,
        "without-ui-test-target": variant_no_ui_target(text),
        "minimal-app-resources": variant_minimal_resources(text),
        "minimal-resources-without-ui": variant_no_ui_target(variant_minimal_resources(text)),
        "current-with-main-target-model": replace_sections(text, main_text, target_model_sections),
        "current-with-main-files-groups": replace_sections(
            text,
            main_text,
            ["PBXBuildFile", "PBXFileReference", "PBXGroup"],
        ),
        "current-with-main-packages": replace_sections(
            text,
            main_text,
            ["XCRemoteSwiftPackageReference", "XCSwiftPackageProductDependency"],
        ),
    }
    for section in SECTIONS:
        variants[f"current-with-main-{section}"] = replace_section(text, main_text, section)
    failures = 0
    for name, variant_text in variants.items():
        project = write_variant(name, variant_text)
        failures += 0 if run_list(name, project) == 0 else 1
    return 0 if failures < len(variants) else 1


if __name__ == "__main__":
    raise SystemExit(main())
