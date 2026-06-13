#!/usr/bin/env python3
"""Guard routed screens and export sharing against fake current-assignment state."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

FORBIDDEN_SNIPPETS = {
    "GradeDraft/UI/Screens": [
        "assignment(for: assignmentID) ?? viewModel.assignment",
        "assignmentID!}",
        "assignmentID!,",
    ],
    "GradeDraft/Views": [
        "assignment(for: assignmentID) ?? viewModel.assignment",
        "exportURL",
        "Share Last Export",
    ],
    "GradeDraft/Views/GradeWizardView.swift": [
        "viewModel.exportStudentPDF()",
        "viewModel.exportStudentReport()",
    ],
    "GradeDraft/UI/Screens/ExportsRestoreScreen.swift": [
        ".studentMarkdown, .teacherAuditMarkdown, .csvGradebook, .backupJSON",
    ],
    "GradeDraft/UI/DesignSystem/ExportComponents.swift": [
        "private extension ExportRiskSummary",
        "init(kind: ExportConfirmationKind",
    ],
}

REQUIRED_SNIPPETS = {
    ROOT / "GradeDraft" / "UI" / "Screens" / "ScreenModels.swift": [
        "struct MissingAssignmentRouteView",
        "struct PreparedExportArtifact",
        ".studentPDF || $0.exportKind == .studentMarkdown",
    ],
    ROOT / "GradeDraft" / "UI" / "Screens" / "StudentWorkScreen.swift": [
        "MissingAssignmentRouteView",
    ],
    ROOT / "GradeDraft" / "UI" / "Screens" / "ReviewScannedTextScreen.swift": [
        "MissingAssignmentRouteView",
    ],
    ROOT / "GradeDraft" / "UI" / "Screens" / "RubricInstructionsScreen.swift": [
        "MissingAssignmentRouteView",
        "rubricPreview(for: assignmentID)",
        "confirmMarkdownRubricImport(preview, for: assignmentID",
    ],
    ROOT / "GradeDraft" / "UI" / "Screens" / "ExportsRestoreScreen.swift": [
        "MissingAssignmentRouteView",
        "preparedExportArtifact",
        "clipboardCopyAvailable(for: artifact.kind)",
    ],
    ROOT / "GradeDraft" / "Views" / "GradeWizardView.swift": [
        "confirmationKind",
        "ExportConfirmationSheet",
        "performConfirmedExport(kind)",
        "preparedExportArtifact",
        ".studentPDF || artifact.kind == .studentMarkdown",
    ],
    ROOT / "GradeDraft" / "Export" / "ExportPolicy.swift": [
        "static func summary(",
        "var containsDraftGradingContent",
        "var gradebookExportContainsDraftState",
    ],
    ROOT / "GradeDraft" / "UI" / "DesignSystem" / "ExportComponents.swift": [
        "ExportRiskSummary.summary(",
    ],
}

REQUIRED_GLOB_SNIPPETS = {
    "GradeDraft/GradeDraftViewModel*.swift": [
        "@Published var preparedExportArtifact",
        "var rubricPreviewsByAssignmentID",
        "func rubricPreview(for assignmentID: UUID)",
        "func clearPreparedExport()",
        "func currentSavedAssignmentForAction(_ actionName: String) -> AssignmentRecord?",
        "no saved assignment is selected",
        "currentSavedAssignmentForAction(\"Markdown rubric preview\")",
        "currentSavedAssignmentForAction(\"Roster preview\")",
        "currentSavedAssignmentForAction(\"Clear student work\")",
        "currentSavedAssignmentForAction(\"AI readiness\")",
        "currentSavedAssignmentForAction(\"AI packet preview\")",
        "currentSavedAssignmentForAction(\"Local draft generation\")",
        "currentSavedAssignmentForAction(\"Export audit record\")",
        "currentSavedAssignmentForAction(\"Rubric template application\")",
        "currentSavedAssignmentForAction(\"Paste student work\")",
        "currentSavedAssignmentForAction(\"Rubric text update\")",
        "currentSavedAssignmentForAction(\"Curriculum reference mapping\")",
        "currentSavedAssignmentForAction(\"Start final review from draft\")",
        "currentSavedAssignmentForAction(\"Approve final review\")",
        "currentSavedAssignmentForAction(\"Mark scanned text reviewed\")",
        "currentSavedAssignmentForAction(\"Add scanned text evidence\")",
        "exportURL = nil",
        "exportKind = nil",
        "Confirm, correct, or reject every scanned text line",
        "Review each low-confidence OCR line",
    ],
}


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> int:
    failures: list[str] = []

    for relative_root, snippets in FORBIDDEN_SNIPPETS.items():
        source_path = ROOT / relative_root
        swift_paths = [source_path] if source_path.is_file() else source_path.rglob("*.swift")
        for path in swift_paths:
            text = read(path)
            for snippet in snippets:
                if snippet in text:
                    failures.append(f"{path.relative_to(ROOT)} contains forbidden snippet: {snippet}")

    for path, snippets in REQUIRED_SNIPPETS.items():
        if not path.exists():
            failures.append(f"Missing required file: {path.relative_to(ROOT)}")
            continue
        text = read(path)
        for snippet in snippets:
            if snippet not in text:
                failures.append(f"{path.relative_to(ROOT)} missing required snippet: {snippet}")

    for pattern, snippets in REQUIRED_GLOB_SNIPPETS.items():
        paths = sorted(ROOT.glob(pattern))
        if not paths:
            failures.append(f"Missing required files matching: {pattern}")
            continue
        text = "\n".join(read(path) for path in paths)
        for snippet in snippets:
            if snippet not in text:
                failures.append(f"{pattern} missing required snippet: {snippet}")

    if failures:
        print("Route/export truthfulness guardrail failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("Route/export truthfulness guardrail passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
