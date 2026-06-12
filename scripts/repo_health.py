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


def run_check(label: str, command: list[str], timeout_seconds: int = 120) -> int:
    """Run one component check without allowing the aggregate health gate to hang indefinitely."""
    print(f"Running {label}...")
    try:
        result = subprocess.run(
            command,
            cwd=ROOT,
            timeout=timeout_seconds,
        )
    except subprocess.TimeoutExpired as error:
        print(f"{label} timed out after {timeout_seconds} seconds.")
        return 124

    return result.returncode


def main() -> int:
    missing = [path for path in REQUIRED_FILES if not (ROOT / path).exists()]
    if missing:
        print("Missing required files:")
        for path in missing:
            print(f"- {path}")
        return 1

    checks = [
        ("no-network scan", [sys.executable, str(ROOT / "scripts" / "no_network_scan.py")]),
        ("export hardening scan", [sys.executable, str(ROOT / "scripts" / "export_hardening_scan.py")]),
        ("curriculum catalog scan", [sys.executable, str(ROOT / "scripts" / "ci" / "check_curriculum_catalog.py")]),
        ("AI evaluation fixture scan", [sys.executable, str(ROOT / "scripts" / "ci" / "check_ai_evaluation_fixtures.py")]),
        ("App Intents safety scan", [sys.executable, str(ROOT / "scripts" / "ci" / "check_app_intents_safety.py")]),
        ("local AI tools scan", [sys.executable, str(ROOT / "scripts" / "ci" / "check_local_ai_tools.py")]),
        ("AI prompt safety scan", [sys.executable, str(ROOT / "scripts" / "ci" / "check_ai_prompt_safety.py")]),
        ("AI batch readiness scan", [sys.executable, str(ROOT / "scripts" / "ci" / "check_ai_batch_readiness.py")]),
        ("AI packet preview screen scan", [sys.executable, str(ROOT / "scripts" / "ci" / "check_ai_packet_preview_screen.py")]),
        ("release static readiness scan", [sys.executable, str(ROOT / "scripts" / "ci" / "check_release_readiness_static.py")]),
    ]
    for label, command in checks:
        status = run_check(label, command)
        if status != 0:
            return status

    print("Required files present.")
    print("Health check passed. Use Xcode to compile and run unit tests.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
