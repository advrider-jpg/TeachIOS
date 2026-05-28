#!/usr/bin/env python3
"""Lightweight GradeDraft repository health check."""
from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "GradeDraft.xcodeproj/project.pbxproj",
    "GradeDraft/ContentView.swift",
    "GradeDraft/GradeDraftViewModel.swift",
    "GradeDraft/Models/GradeDraftModels.swift",
    "GradeDraft/Services/FoundationModelGradingService.swift",
    "GradeDraft/Services/OCRService.swift",
    "GradeDraft/Services/LocalJSONStore.swift",
    "GradeDraft/Resources/PrivacyInfo.xcprivacy",
    "GradeDraftTests/GradeDraftTests.swift",
    "docs/OFFLINE_CAPABILITY.md",
    "docs/CORE_RULES.md",
    "docs/DATA_MODEL_V3.md",
    "docs/V3_IMPLEMENTATION_NOTES.md",
]


def main() -> int:
    missing = [path for path in REQUIRED_FILES if not (ROOT / path).exists()]
    if missing:
        print("Missing required files:")
        for path in missing:
            print(f"- {path}")
        return 1

    scan = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "no_network_scan.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    print(scan.stdout.strip())
    if scan.returncode != 0:
        print(scan.stderr.strip())
        return scan.returncode

    print("Required files present.")
    print("Health check passed. Use Xcode to compile and run unit tests.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
