import Foundation

enum SpreadsheetSafety {
    /// A cell starting with one of these (or with whitespace followed by one of the visible ones)
    /// can be run as a formula by a spreadsheet, so it gets a leading apostrophe.
    static let dangerousFormulaPrefixes = ["=", "+", "-", "@", "\t", "\r"]

    static func sanitizedCell(_ value: String) -> String {
        guard !value.isEmpty else { return value }
        if value.first == "'" { return value }
        if isNumericalText(value) { return value }
        if startsWithDangerousPrefix(value) { return "'" + value }
        if let firstVisible = value.first(where: { !$0.isWhitespace }), startsWithDangerousPrefix(String(firstVisible)) {
            return "'" + value
        }
        return value
    }

    static func isNumericalText(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if Int(trimmed) != nil { return true }
        if Double(trimmed) != nil { return true }
        return false
    }

    // Compared by Unicode scalars so that "\r" is recognised even when it is followed by "\n".
    private static func startsWithDangerousPrefix(_ value: String) -> Bool {
        dangerousFormulaPrefixes.contains { value.unicodeScalars.starts(with: $0.unicodeScalars) }
    }
}

enum CSVExportService {
    static let header = ["student", "local_id", "status", "total_score", "max_score", "ai_draft_suggestion"]

    /// One row per student for one assignment. `total_score` is blank unless the final review is
    /// approved and current; the model's suggestion is only ever shown in `ai_draft_suggestion`.
    static func gradebookCSV(setup: AssignmentSetup, submissions: [SubmissionGraph]) -> String {
        let rubric = setup.parsedRubric.criteria
        let maxScore = rubric.isEmpty ? "" : GradeTotals.formatted(rubric.reduce(0) { $0 + $1.maxPoints })

        var rows: [[String]] = [header]
        for submission in submissions {
            let total = ExportPolicy.allowsStudentReport(setup: setup, submission: submission)
                ? submission.finalReview.map { GradeTotals.formatted($0.totalScore) } ?? ""
                : ""
            rows.append([
                SpreadsheetSafety.sanitizedCell(submission.student.displayName),
                SpreadsheetSafety.sanitizedCell(submission.student.localIdentifier),
                status(of: submission, setup: setup),
                total,
                maxScore,
                submission.draft.map { GradeTotals.formatted($0.totalScore) } ?? ""
            ])
        }
        return "\u{FEFF}" + CSVWriter.string(rows: rows, rowSeparator: "\r\n") + "\r\n"
    }

    private static func status(of submission: SubmissionGraph, setup: AssignmentSetup) -> String {
        guard let review = submission.finalReview else { return "pending_final_review" }
        if submission.finalReviewIsStale(setup: setup) { return "stale_review" }
        return review.status == .approved ? "approved" : "in_progress"
    }
}
