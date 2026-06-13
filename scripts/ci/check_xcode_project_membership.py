#!/usr/bin/env python3
"""Fail when Swift source files are missing from the Xcode project.

This is a pragmatic membership guardrail: it checks that each Swift filename
under the app and test source roots appears in project.pbxproj. It does not
fully parse target membership graphs, but it catches the common CI failure
where a new source file is added on disk and never added to the project.
"""
from __future__ import annotations

import pathlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
PROJECT_FILE = ROOT / "GradeDraft.xcodeproj" / "project.pbxproj"
SCHEME_DIR = ROOT / "GradeDraft.xcodeproj" / "xcshareddata" / "xcschemes"
SOURCE_ROOTS = [ROOT / "GradeDraft", ROOT / "GradeDraftTests", ROOT / "GradeDraftUITests"]
IGNORED_PARTS = {"DerivedData", ".build", ".swiftpm"}
REFERENCE_KEYS = {
    "baseConfigurationReference",
    "buildConfigurationList",
    "containerPortal",
    "fileRef",
    "mainGroup",
    "productReference",
    "productRefGroup",
    "target",
    "targetProxy",
}
ARRAY_KEYS = {"buildConfigurations", "buildPhases", "children", "dependencies", "files", "packageReferences", "targets"}
SAFE_UNQUOTED_PATH = re.compile(r"^[A-Za-z0-9_./-]+$")


def swift_files() -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for source_root in SOURCE_ROOTS:
        files.extend(
            path
            for path in source_root.rglob("*.swift")
            if path.is_file() and not any(part in IGNORED_PARTS for part in path.parts)
        )
    return sorted(files)


def scheme_reference_failures(object_ids: set[str]) -> list[str]:
    failures: list[str] = []
    for scheme_path in sorted(SCHEME_DIR.glob("*.xcscheme")):
        try:
            scheme = ET.parse(scheme_path)
        except ET.ParseError as error:
            failures.append(f"{scheme_path.relative_to(ROOT).as_posix()} is not valid XML: {error}")
            continue
        for reference in scheme.findall(".//BuildableReference"):
            blueprint_id = reference.attrib.get("BlueprintIdentifier", "")
            blueprint_name = reference.attrib.get("BlueprintName", "<unknown>")
            if not re.fullmatch(r"[A-Fa-f0-9]{24}", blueprint_id):
                failures.append(
                    f"{scheme_path.relative_to(ROOT).as_posix()} has non-Xcode BlueprintIdentifier "
                    f"{blueprint_id} for {blueprint_name}"
                )
            elif blueprint_id not in object_ids:
                failures.append(
                    f"{scheme_path.relative_to(ROOT).as_posix()} references missing BlueprintIdentifier "
                    f"{blueprint_id} for {blueprint_name}"
                )
    return failures


def file_reference_path_failures(project_text: str) -> list[str]:
    failures: list[str] = []
    for line_number, line in enumerate(project_text.splitlines(), start=1):
        if "isa = PBXFileReference" not in line or " path = " not in line:
            continue
        match = re.search(r"\bpath = ([^;]+);", line)
        if match is None:
            continue
        value = match.group(1).strip()
        if value.startswith('"') and value.endswith('"'):
            continue
        if not SAFE_UNQUOTED_PATH.fullmatch(value):
            failures.append(
                f"line {line_number} has unquoted PBXFileReference path {value!r}; "
                "quote paths containing special characters"
            )
    return failures


def main() -> int:
    project_text = PROJECT_FILE.read_text(encoding="utf-8")
    object_ids = set(re.findall(r"^\s*([A-Za-z0-9]{24})(?:\s*/\*.*?\*/)?\s*=", project_text, flags=re.MULTILINE))
    object_ids.update(
        re.findall(r"^\s*([A-Za-z0-9]+)\s*/\*.*?\*/\s*=\s*\{isa\s*=", project_text, flags=re.MULTILINE)
    )
    invalid_object_ids = sorted(object_id for object_id in object_ids if not re.fullmatch(r"[A-Fa-f0-9]{24}", object_id))
    dangling: list[str] = []
    scheme_failures = scheme_reference_failures(object_ids)
    path_failures = file_reference_path_failures(project_text)

    for key in REFERENCE_KEYS:
        for match in re.finditer(rf"\b{key}\s*=\s*([A-Za-z0-9]{{24}})\b", project_text):
            ref = match.group(1)
            if ref not in object_ids:
                dangling.append(f"{key} references missing object {ref}")

    for key in ARRAY_KEYS:
        for match in re.finditer(rf"\b{key}\s*=\s*\((.*?)\);", project_text, flags=re.S):
            for ref in re.findall(r"\b([A-Za-z0-9]+)\s*/\*", match.group(1)):
                if ref not in object_ids:
                    dangling.append(f"{key} contains missing object {ref}")

    missing = [
        path.relative_to(ROOT).as_posix()
        for path in swift_files()
        if path.name not in project_text
    ]
    if invalid_object_ids or dangling or scheme_failures or path_failures or missing:
        if invalid_object_ids:
            print("GradeDraft.xcodeproj/project.pbxproj contains non-Xcode object IDs:")
            for object_id in invalid_object_ids:
                print(f"- {object_id}")
        if dangling:
            print("GradeDraft.xcodeproj/project.pbxproj contains dangling object references:")
            for item in sorted(set(dangling)):
                print(f"- {item}")
        if scheme_failures:
            print("GradeDraft.xcodeproj shared schemes contain invalid project references:")
            for item in scheme_failures:
                print(f"- {item}")
        if path_failures:
            print("GradeDraft.xcodeproj/project.pbxproj contains paths that Xcode cannot parse:")
            for item in path_failures:
                print(f"- {item}")
        if missing:
            print("Swift files missing from GradeDraft.xcodeproj/project.pbxproj:")
            for path in missing:
                print(f"- {path}")
        return 1
    print(f"All {len(swift_files())} Swift source/test files appear in the Xcode project.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
