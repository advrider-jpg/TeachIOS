import Foundation

enum SpreadsheetSafety {
    private static let dangerousFormulaPrefixes: Set<Character> = ["=", "+", "-", "@"]

    static func sanitizedCell(_ value: String) -> String {
        guard !value.isEmpty else { return value }
        guard let firstNonWhitespace = value.first(where: { !$0.isWhitespace }) else { return value }
        if value.first == "'" { return value }
        if isNumericalText(value) { return value }
        if dangerousFormulaPrefixes.contains(firstNonWhitespace) {
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
}

enum CSVExportService {
    static func buildStudentRows(from assignments: [AssignmentRecord]) -> [[String]] {
        var rows: [[String]] = []
        rows.append([
            "assignment_id",
            "title",
            "subject",
            "grade_level",
            "class_name",
            "student",
            "assignment_type",
            "assessment_purpose",
            "total_score",
            "max_score",
            "final_status",
            "ocr_status",
            "draft_status",
            "final_review_stale",
            "draft_stale",
            "updated_at"
        ])

        for assignment in assignments {
            let finalStatus = exportFinalStatus(for: assignment)
            let (totalScore, maxScore) = exportTotals(for: assignment)

            rows.append([
                assignment.id.uuidString,
                SpreadsheetSafety.sanitizedCell(assignment.title),
                SpreadsheetSafety.sanitizedCell(assignment.subject),
                SpreadsheetSafety.sanitizedCell(assignment.gradeLevel),
                SpreadsheetSafety.sanitizedCell(assignment.className),
                SpreadsheetSafety.sanitizedCell(assignment.studentDisplayName),
                SpreadsheetSafety.sanitizedCell(assignment.assignmentType.rawValue),
                SpreadsheetSafety.sanitizedCell(assignment.assessmentPurpose.rawValue),
                String(totalScore),
                String(maxScore),
                SpreadsheetSafety.sanitizedCell(finalStatus),
                SpreadsheetSafety.sanitizedCell(assignment.ocrReviewStatus.rawValue),
                SpreadsheetSafety.sanitizedCell(exportDraftStatus(for: assignment)),
                String(assignment.finalReviewIsStale),
                String(assignment.finalReview == nil && assignment.latestDraftIsStale),
                ISO8601DateFormatter.gradingExport.string(from: assignment.updatedAt)
            ])
        }
        return rows
    }

    static func exportedCSV(from assignments: [AssignmentRecord]) -> String {
        CSVWriter.string(rows: buildStudentRows(from: assignments))
    }

    static func writeCSV(from assignments: [AssignmentRecord], to destination: URL) throws -> URL {
        try exportedCSV(from: assignments).write(to: destination, atomically: true, encoding: .utf8)
        ExportFileHardening.applyBestEffortProtection(to: destination)
        return destination
    }

    private static func exportFinalStatus(for assignment: AssignmentRecord) -> String {
        guard let review = assignment.finalReview else {
            return "pending_final_review"
        }

        if review.status == .approved {
            if assignment.finalReviewIsStale {
                return "stale_review"
            }
            return "approved"
        }

        if assignment.finalReviewIsStale || review.status == .stale {
            return "stale_review"
        }

        return "in_progress"
    }

    private static func exportDraftStatus(for assignment: AssignmentRecord) -> String {
        if assignment.finalReview != nil {
            return DraftStatus.teacherReviewRequired.rawValue
        }
        guard let draft = assignment.latestDraft else {
            return "not_generated"
        }

        if assignment.latestDraftIsStale {
            return "stale"
        }

        return draft.status.rawValue
    }

    private static func exportTotals(for assignment: AssignmentRecord) -> (Double, Double) {
        if let finalReview = assignment.finalReview {
            return (finalReview.totalScore, finalReview.maxScore)
        }

        if let draft = assignment.latestDraft {
            return (draft.totalScore, draft.maxScore)
        }

        return (0, 0)
    }
}

private extension ISO8601DateFormatter {
    nonisolated(unsafe) static let gradingExport: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
