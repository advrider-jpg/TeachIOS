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

    export_scan = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "export_hardening_scan.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    print(export_scan.stdout.strip())
    if export_scan.returncode != 0:
        print(export_scan.stderr.strip())
        return export_scan.returncode

    curriculum_scan = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "ci" / "check_curriculum_catalog.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    print(curriculum_scan.stdout.strip())
    if curriculum_scan.returncode != 0:
        print(curriculum_scan.stderr.strip())
        return curriculum_scan.returncode

    release_scan = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "ci" / "check_release_readiness_static.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    print(release_scan.stdout.strip())
    if release_scan.returncode != 0:
        print(release_scan.stderr.strip())
        return release_scan.returncode

    ai_eval_scan = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "ci" / "check_ai_evaluation_fixtures.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    print(ai_eval_scan.stdout.strip())
    if ai_eval_scan.returncode != 0:
        print(ai_eval_scan.stderr.strip())
        return ai_eval_scan.returncode

    app_intents_scan = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "ci" / "check_app_intents_safety.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    print(app_intents_scan.stdout.strip())
    if app_intents_scan.returncode != 0:
        print(app_intents_scan.stderr.strip())
        return app_intents_scan.returncode

    local_ai_tools_scan = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "ci" / "check_local_ai_tools.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    print(local_ai_tools_scan.stdout.strip())
    if local_ai_tools_scan.returncode != 0:
        print(local_ai_tools_scan.stderr.strip())
        return local_ai_tools_scan.returncode

    ai_prompt_safety_scan = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "ci" / "check_ai_prompt_safety.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    print(ai_prompt_safety_scan.stdout.strip())
    if ai_prompt_safety_scan.returncode != 0:
        print(ai_prompt_safety_scan.stderr.strip())
        return ai_prompt_safety_scan.returncode

    ai_batch_readiness_scan = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "ci" / "check_ai_batch_readiness.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    print(ai_batch_readiness_scan.stdout.strip())
    if ai_batch_readiness_scan.returncode != 0:
        print(ai_batch_readiness_scan.stderr.strip())
        return ai_batch_readiness_scan.returncode

    ai_packet_preview_screen_scan = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "ci" / "check_ai_packet_preview_screen.py")],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    print(ai_packet_preview_screen_scan.stdout.strip())
    if ai_packet_preview_screen_scan.returncode != 0:
        print(ai_packet_preview_screen_scan.stderr.strip())
        return ai_packet_preview_screen_scan.returncode

    print("Required files present.")
    print("Health check passed. Use Xcode to compile and run unit tests.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
