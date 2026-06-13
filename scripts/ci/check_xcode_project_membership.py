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

ROOT = pathlib.Path(__file__).resolve().parents[2]
PROJECT_FILE = ROOT / "GradeDraft.xcodeproj" / "project.pbxproj"
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


def swift_files() -> list[pathlib.Path]:
    files: list[pathlib.Path] = []
    for source_root in SOURCE_ROOTS:
        files.extend(
            path
            for path in source_root.rglob("*.swift")
            if path.is_file() and not any(part in IGNORED_PARTS for part in path.parts)
        )
    return sorted(files)


def main() -> int:
    project_text = PROJECT_FILE.read_text(encoding="utf-8")
    object_ids = set(re.findall(r"^\s*([A-Za-z0-9]{24})(?:\s*/\*.*?\*/)?\s*=", project_text, flags=re.MULTILINE))
    dangling: list[str] = []

    for key in REFERENCE_KEYS:
        for match in re.finditer(rf"\b{key}\s*=\s*([A-Za-z0-9]{{24}})\b", project_text):
            ref = match.group(1)
            if ref not in object_ids:
                dangling.append(f"{key} references missing object {ref}")

    for key in ARRAY_KEYS:
        for match in re.finditer(rf"\b{key}\s*=\s*\((.*?)\);", project_text, flags=re.S):
            for ref in re.findall(r"\b([A-Za-z0-9]{24})\s*/\*", match.group(1)):
                if ref not in object_ids:
                    dangling.append(f"{key} contains missing object {ref}")

    missing = [
        path.relative_to(ROOT).as_posix()
        for path in swift_files()
        if path.name not in project_text
    ]
    if dangling or missing:
        if dangling:
            print("GradeDraft.xcodeproj/project.pbxproj contains dangling object references:")
            for item in sorted(set(dangling)):
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
