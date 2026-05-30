#!/usr/bin/env python3
"""Static guardrails for GradeDraft export-hardening invariants."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
failures: list[str] = []


def rel(path: pathlib.Path) -> str:
    return str(path.relative_to(ROOT))


def add_failure(path: pathlib.Path, lineno: int | None, message: str) -> None:
    loc = f"{rel(path)}:{lineno}" if lineno else rel(path)
    failures.append(f"{loc}: {message}")


def swift_files() -> list[pathlib.Path]:
    return [p for p in ROOT.rglob("*.swift") if ".git" not in p.parts and "DerivedData" not in p.parts]


# CSV rows must go through the central CSVWriter rather than ad-hoc comma joins.
for path in swift_files():
    if rel(path).replace("\\", "/") == "GradeDraft/Export/CSVCodec.swift":
        continue
    text = path.read_text(encoding="utf-8")
    for lineno, line in enumerate(text.splitlines(), start=1):
        if '.joined(separator: ",")' in line:
            add_failure(path, lineno, "CSV-style comma joins must use CSVWriter.string(rows:) instead of raw joined(separator: \",\").")


# Student-facing Markdown should not render draft-only or teacher-only internals.
report_path = ROOT / "GradeDraft/Services/LocalJSONStore.swift"
report_text = report_path.read_text(encoding="utf-8")
match = re.search(r"static func studentMarkdown\(for assignment: AssignmentRecord\) -> String \{", report_text)
if not match:
    add_failure(report_path, None, "Could not find MarkdownReportBuilder.studentMarkdown(for:).")
else:
    start = match.end()
    depth = 1
    idx = start
    while idx < len(report_text) and depth > 0:
        char = report_text[idx]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        idx += 1
    body = report_text[start:idx]
    forbidden_tokens = [
        "latestDraft",
        "rawModelResponse",
        "privateTeacherNotes",
        "teacherRationale",
        "auditEvents",
        "sourceInputs",
        "evidenceSourceRefs",
        "ocrDocument",
        "ocrReviewStatus",
        "boundingBox",
        "packetFingerprint",
    ]
    for token in forbidden_tokens:
        if token in body:
            line = report_text[: report_text.find(token, start)].count("\n") + 1
            add_failure(report_path, line, f"studentMarkdown(for:) references teacher-only/internal token {token!r}.")


# Temporary export filename generation must use ExportFilenameBuilder rather than title/student-derived names.
def function_body(text: str, func_name: str) -> tuple[int, str] | None:
    match = re.search(rf"(?:static\s+)?func\s+{re.escape(func_name)}\b", text)
    if not match:
        return None
    brace = text.find("{", match.end())
    if brace == -1:
        return None
    depth = 1
    idx = brace + 1
    while idx < len(text) and depth > 0:
        char = text[idx]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        idx += 1
    return brace + 1, text[brace + 1:idx - 1]

for path, funcs in {
    ROOT / "GradeDraft/Services/LocalJSONStore.swift": ["writeTemporaryReport"],
    ROOT / "GradeDraft/GradeDraftViewModel.swift": ["temporaryExportURL", "exportCSVGradebook", "exportArchiveBundle", "exportBackupJSON"],
}.items():
    text = path.read_text(encoding="utf-8")
    for func_name in funcs:
        body_info = function_body(text, func_name)
        if not body_info:
            add_failure(path, None, f"Could not inspect export filename helper {func_name}.")
            continue
        body_start, body = body_info
        for token in ["safeTitle", "assignment.title", "studentDisplayName"]:
            if token in body:
                token_index = text.find(token, body_start)
                line = text[:token_index].count("\n") + 1
                add_failure(path, line, f"export filename/helper path {func_name} still references {token!r}; use ExportFilenameBuilder.")


# Restore logic must include the safe destination helper and not rely on substring traversal checks alone.
bundle_path = ROOT / "GradeDraft/Export/BundleExportService.swift"
bundle_text = bundle_path.read_text(encoding="utf-8")
if "safeRestoreDestination(for archiveEntryPath" not in bundle_text or "safeRelativeSourcePath" not in bundle_text:
    add_failure(bundle_path, None, "Bundle restore must expose safeRestoreDestination and validate source path components.")
if 'entry.path.contains("..")' in bundle_text:
    line = bundle_text[: bundle_text.find('entry.path.contains("..")')].count("\n") + 1
    add_failure(bundle_path, line, "restoreSourceFiles must not rely on contains(\"..\") traversal checks.")


# Archive exports must include a machine-readable inventory.
if "archive_inventory.json" not in bundle_text or "ExportArchiveInventoryItem" not in bundle_text:
    add_failure(bundle_path, None, "ZIP exports must write archive_inventory.json with ExportArchiveInventoryItem rows.")


if failures:
    print("Export-hardening guardrail failed:\n")
    print("\n".join(failures))
    sys.exit(1)

print("Export-hardening guardrail passed.")
