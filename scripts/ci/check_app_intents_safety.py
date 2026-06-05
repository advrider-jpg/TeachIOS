#!/usr/bin/env python3
"""Static safety checks for GradeDraft App Intents."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
APP_INTENTS = ROOT / "GradeDraft" / "AppIntents" / "GradeDraftAppIntents.swift"

DANGEROUS_INTENT_NAME_PARTS = [
    "Approve",
    "AutoGrade",
    "BackgroundGrade",
    "Cloud",
    "ExportStudent",
    "FinalGrade",
    "GenerateGrade",
    "Submit",
    "Upload",
]

DANGEROUS_BODY_SNIPPETS = [
    ".approveFinalGrade",
    ".export",
    ".draftGrade(",
    "exportReports",
    "fetchWeb",
    "latestDraft =",
    "saveFinalReview",
    "URLSession",
]


def block_after(source: str, marker: str, next_markers: list[str]) -> str:
    start = source.find(marker)
    if start == -1:
        return ""
    end_candidates = [
        source.find(next_marker, start + len(marker))
        for next_marker in next_markers
        if source.find(next_marker, start + len(marker)) != -1
    ]
    end = min(end_candidates) if end_candidates else len(source)
    return source[start:end]


def intent_blocks(source: str) -> list[tuple[str, str]]:
    matches = list(re.finditer(r"struct\s+(\w+Intent)\s*:\s*AppIntent\s*\{", source))
    blocks: list[tuple[str, str]] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(source)
        blocks.append((match.group(1), source[match.start():end]))
    return blocks


def main() -> int:
    failures: list[str] = []
    if not APP_INTENTS.exists():
        failures.append("Missing GradeDraftAppIntents.swift")
        print("\n".join(failures))
        return 1

    source = APP_INTENTS.read_text(encoding="utf-8")
    if "struct AssignmentEntity: AppEntity" not in source:
        failures.append("Missing AssignmentEntity AppEntity surface")
    if "struct AssignmentEntityQuery: EntityQuery, EntityStringQuery" not in source:
        failures.append("Missing local AssignmentEntityQuery")

    assignment_entity = block_after(source, "struct AssignmentEntity: AppEntity", ["struct AssignmentEntityQuery"])
    stored_property_lines = [
        line.strip()
        for line in assignment_entity.splitlines()
        if line.strip().startswith(("let ", "var "))
    ]
    for line in stored_property_lines:
        if any(term in line for term in ["student", "className", "studentID", "roster"]):
            failures.append(f"AssignmentEntity stores sensitive metadata: {line}")

    display_block = block_after(assignment_entity, "var displayRepresentation", ["static func safeDisplayTitle"])
    if any(term in display_block for term in ["studentDisplayName", "studentID", "className"]):
        failures.append("AssignmentEntity displayRepresentation directly exposes student/class metadata")
    if "safeDisplayTitle(for" not in source or "[redacted identity]" not in source:
        failures.append("AssignmentEntity does not redact known student/class identity from display titles")

    for entity_name in ["StudentEntity", "ClassEntity", "DraftReviewEntity"]:
        if f"struct {entity_name}" in source:
            failures.append(f"Unsafe or review-required AppEntity added: {entity_name}")

    for intent_name, block in intent_blocks(source):
        if any(part in intent_name for part in DANGEROUS_INTENT_NAME_PARTS):
            failures.append(f"Dangerous intent name exposed: {intent_name}")
        if intent_name != "SearchLocalGradeDraftAssignmentsIntent" and "static var openAppWhenRun: Bool = true" not in block:
            failures.append(f"{intent_name} must open the app for foreground teacher review")
        for snippet in DANGEROUS_BODY_SNIPPETS:
            if snippet in block:
                failures.append(f"{intent_name} contains unsafe action snippet: {snippet}")

    search_block = block_after(source, "struct SearchLocalGradeDraftAssignmentsIntent", ["struct GradeDraftShortcutsProvider"])
    if "static var openAppWhenRun: Bool = false" not in search_block:
        failures.append("SearchLocalGradeDraftAssignmentsIntent should not launch the app")
    if "studentDisplayName" in search_block or "className" in search_block or "uuidString" in search_block:
        failures.append("SearchLocalGradeDraftAssignmentsIntent leaks identity metadata or assignment UUIDs")
    if "AssignmentIntentResolver.loadAssignments()" not in search_block:
        failures.append("SearchLocalGradeDraftAssignmentsIntent must use local assignment storage only")

    if failures:
        print("App Intents safety check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("App Intents safety check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
