#!/usr/bin/env python3
"""Guard the dedicated local AI packet preview route and screen."""
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
SCREEN = ROOT / "GradeDraft" / "UI" / "Screens" / "AIPacketPreviewScreen.swift"
SHELL = ROOT / "GradeDraft" / "UI" / "AppShell" / "AppTabShell.swift"
PROJECT = ROOT / "GradeDraft.xcodeproj" / "project.pbxproj"


def main() -> int:
    failures: list[str] = []
    if not SCREEN.exists():
        failures.append("AIPacketPreviewScreen.swift is missing")
    else:
        text = SCREEN.read_text(encoding="utf-8")
        required = [
            "Form {",
            "buildAIPacketPreview()",
            "does not generate a draft",
            "approve a grade",
            "export a report",
            "upload data",
            "read other students",
        ]
        for token in required:
            if token not in text:
                failures.append(f"AIPacketPreviewScreen.swift missing required token: {token}")
        forbidden_patterns = [
            r"\bconfirmAndDraftGrade\s*\(",
            r"\bdraftGrade\s*\(",
            r"\bapproveFinalReview\s*\(",
            r"\bexport[A-Za-z0-9_]*\s*\(",
            r"\bshare[A-Za-z0-9_]*\s*\(",
        ]
        for pattern in forbidden_patterns:
            if re.search(pattern, text):
                failures.append(f"AIPacketPreviewScreen.swift contains unsafe action pattern: {pattern}")

    shell_text = SHELL.read_text(encoding="utf-8")
    if "case .packetPreview(let id):\n            AIPacketPreviewScreen(viewModel: viewModel, assignmentID: id)" not in shell_text:
        failures.append("AppTabShell .packetPreview route must open AIPacketPreviewScreen")

    project_text = PROJECT.read_text(encoding="utf-8")
    if "AIPacketPreviewScreen.swift" not in project_text:
        failures.append("AIPacketPreviewScreen.swift is missing from the Xcode project")

    if failures:
        print("AI packet preview screen check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("AI packet preview screen check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
