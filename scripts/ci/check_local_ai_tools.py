#!/usr/bin/env python3
"""Static checks for local AI tool safety boundaries."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
TOOLS = ROOT / "GradeDraft" / "AI" / "Tools" / "LocalGradingToolSupport.swift"
LEGACY = ROOT / "GradeDraft" / "Services" / "LocalAIGradingTools.swift"

REQUIRED_SNIPPETS = [
    "struct LocalGradingToolPolicy",
    "allowWrites: false",
    "allowNetwork: false",
    "maxToolCallsPerRequest",
    "maxToolOutputCharacters",
    "struct LocalToolSnippet",
    "struct LocalToolOutput",
    "struct LocalToolCallAudit",
    "struct StudentEvidenceIndex",
    "final class LocalGradingToolSession",
    "Tool call limit reached",
    "read-only/no-network grading policy",
]

FORBIDDEN_SNIPPETS = [
    "URLSession",
    "approveFinalGrade(",
    "saveFinalReview(",
    "exportStudentReport",
    "writeAssignmentRecord(",
    "deleteAssignment(",
    "readOtherStudents(",
]


def main() -> int:
    failures: list[str] = []
    if not TOOLS.exists():
        failures.append("Missing GradeDraft/AI/Tools/LocalGradingToolSupport.swift")
    if not LEGACY.exists():
        failures.append("Missing GradeDraft/Services/LocalAIGradingTools.swift")
    if failures:
        print("Local AI tool safety check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    source = TOOLS.read_text(encoding="utf-8")
    legacy_source = LEGACY.read_text(encoding="utf-8")
    for snippet in REQUIRED_SNIPPETS:
        if snippet not in source:
            failures.append(f"Tool support missing required snippet: {snippet}")

    for snippet in FORBIDDEN_SNIPPETS:
        if snippet in source:
            failures.append(f"Tool support contains unsafe snippet: {snippet}")

    for forbidden_name in [
        "approveFinalGrade",
        "exportStudentReport",
        "uploadData",
        "fetchWeb",
        "readOtherStudents",
        "writeAssignmentRecord",
        "deleteData",
    ]:
        if forbidden_name not in legacy_source:
            failures.append(f"Legacy tool policy missing forbidden tool name: {forbidden_name}")

    if failures:
        print("Local AI tool safety check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Local AI tool safety check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
