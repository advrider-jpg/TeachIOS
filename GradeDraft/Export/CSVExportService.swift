import Foundation
import SwiftCSV

enum SpreadsheetSafety {
    static func sanitizedCell(_ value: String) -> String {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return candidate }

        if candidate.hasPrefix("=") || candidate.hasPrefix("+") || candidate.hasPrefix("-") || candidate.hasPrefix("@") {
            return "'" + candidate
        }
        return candidate
    }
}

enum CSVExportService {
    static func buildStudentRows(from assignments: [AssignmentRecord]) -> [[String]] {
        var rows: [[String]] = []
        rows.append(["assignment_id", "title", "subject", "grade_level", "student", "total_score", "max_score", "ocr_status", "final_status"])
        for assignment in assignments {
            let ocrStatus = assignment.ocrReviewStatus.rawValue
            let draftTotal = assignment.latestDraft?.totalScore ?? assignment.finalReview?.totalScore ?? 0
            let draftMax = assignment.latestDraft?.maxScore ?? assignment.finalReview?.maxScore ?? 0
            let finalStatus = assignment.finalReview == nil ? "pending" : "approved"
            rows.append([
                assignment.id.uuidString,
                SpreadsheetSafety.sanitizedCell(assignment.title),
                SpreadsheetSafety.sanitizedCell(assignment.subject),
                SpreadsheetSafety.sanitizedCell(assignment.gradeLevel),
                SpreadsheetSafety.sanitizedCell(assignment.studentDisplayName),
                String(draftTotal),
                String(draftMax),
                SpreadsheetSafety.sanitizedCell(ocrStatus),
                SpreadsheetSafety.sanitizedCell(finalStatus),
            ])
        }
        return rows
    }

    static func exportedCSV(from assignments: [AssignmentRecord]) -> String {
        let rows = buildStudentRows(from: assignments)
        return rows.map { row in
            row.map { "\"\(csvEscaped($0))\"" }.joined(separator: ",")
        }.joined(separator: "\n")
    }

    static func writeCSV(from assignments: [AssignmentRecord], to destination: URL) throws -> URL {
        try exportedCSV(from: assignments).write(to: destination, atomically: true, encoding: .utf8)
        return destination
    }

    private static func csvEscaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\"\"")
    }
}
