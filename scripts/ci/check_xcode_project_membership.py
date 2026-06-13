#!/usr/bin/env python3
"""Fail when Swift source files are missing from the Xcode project.

This is a pragmatic membership guardrail: it checks that each Swift filename
under the app and test source roots appears in project.pbxproj. It does not
fully parse target membership graphs, but it catches the common CI failure
where a new source file is added on disk and never added to the project.
"""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
PROJECT_FILE = ROOT / "GradeDraft.xcodeproj" / "project.pbxproj"
SOURCE_ROOTS = [ROOT / "GradeDraft", ROOT / "GradeDraftTests", ROOT / "GradeDraftUITests"]
IGNORED_PARTS = {"DerivedData", ".build", ".swiftpm"}


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
    missing = [
        path.relative_to(ROOT).as_posix()
        for path in swift_files()
        if path.name not in project_text
    ]
    if missing:
        print("Swift files missing from GradeDraft.xcodeproj/project.pbxproj:")
        for path in missing:
            print(f"- {path}")
        return 1
    print(f"All {len(swift_files())} Swift source/test files appear in the Xcode project.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
