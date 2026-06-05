#!/usr/bin/env python3
"""Static checks for AI batch readiness safety."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BATCH = ROOT / "GradeDraft" / "AI" / "Batch" / "AIBatchReadiness.swift"

REQUIRED_SNIPPETS = [
    "struct AIBatchReadinessRow",
    "struct AIBatchReadinessReport",
    "enum AIBatchReadinessAnalyzer",
    "one assignment at a time",
    "pause/cancel controls",
    "never creates drafts",
    "final approvals",
    "student-facing exports",
    "safeDisplayTitle",
    "[redacted identity]",
]

FORBIDDEN_SNIPPETS = [
    "draftGrade(",
    "startFinalReview",
    "approveFinal",
    "saveFinalReview",
    "exportStudent",
    "latestDraft =",
]


def main() -> int:
    failures: list[str] = []
    if not BATCH.exists():
        failures.append("Missing GradeDraft/AI/Batch/AIBatchReadiness.swift")
    else:
        source = BATCH.read_text(encoding="utf-8")
        for snippet in REQUIRED_SNIPPETS:
            if snippet not in source:
                failures.append(f"Batch readiness missing required snippet: {snippet}")
        for snippet in FORBIDDEN_SNIPPETS:
            if snippet in source:
                failures.append(f"Batch readiness contains unsafe mutation/action snippet: {snippet}")

    if failures:
        print("AI batch readiness check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("AI batch readiness check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
