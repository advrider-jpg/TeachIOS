import Foundation

protocol AssignmentStoring {
    func loadAssignments() throws -> [AssignmentRecord]
    func saveAssignments(_ assignments: [AssignmentRecord]) throws
    func deleteAssignment(id: UUID) throws
}

final class LocalJSONStore: AssignmentStoring {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let assignmentsURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let appDirectory = supportURL.appendingPathComponent("GradeDraft", isDirectory: true)
        assignmentsURL = appDirectory.appendingPathComponent("assignments.json")
    }

    func loadAssignments() throws -> [AssignmentRecord] {
        guard fileManager.fileExists(atPath: assignmentsURL.path) else {
            return []
        }
        let data = try Data(contentsOf: assignmentsURL)
        return try decoder.decode([AssignmentRecord].self, from: data)
    }

    func saveAssignments(_ assignments: [AssignmentRecord]) throws {
        let directory = assignmentsURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let sorted = assignments.sorted { $0.updatedAt > $1.updatedAt }
        let data = try encoder.encode(sorted)
        try data.write(to: assignmentsURL, options: [.atomic])
    }

    func deleteAssignment(id: UUID) throws {
        var assignments = try loadAssignments()
        assignments.removeAll { $0.id == id }
        try saveAssignments(assignments)
    }
}

enum MarkdownReportBuilder {
    static func markdown(for assignment: AssignmentRecord) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var output: [String] = []
        output.append("# GradeDraft Report")
        output.append("")
        output.append("**Assignment:** \(assignment.title)")
        output.append("**Subject:** \(assignment.subject.isEmpty ? "Not specified" : assignment.subject)")
        output.append("**Grade level:** \(assignment.gradeLevel.isEmpty ? "Not specified" : assignment.gradeLevel)")
        output.append("**Assignment type:** \(assignment.assignmentType.displayName)")
        output.append("**Updated:** \(dateFormatter.string(from: assignment.updatedAt))")
        output.append("")
        output.append("> This report is generated from local app state. It is not uploaded by GradeDraft.")
        output.append("")

        if let final = assignment.finalReview {
            output.append("## Final teacher-approved grade")
            output.append("")
            output.append("**Score:** \(GradeTotals.formatted(final.totalScore)) / \(GradeTotals.formatted(final.maxScore))")
            output.append("")
            output.append("### Student feedback")
            output.append(final.studentFeedback.isEmpty ? "No feedback provided." : final.studentFeedback)
            output.append("")
            output.append("### Criteria")
            appendCriteria(final.criteria, to: &output)
            if !final.privateTeacherNotes.isEmpty {
                output.append("")
                output.append("### Private teacher notes")
                output.append(final.privateTeacherNotes)
            }
        } else if let draft = assignment.latestDraft {
            output.append("## Draft grade")
            output.append("")
            output.append("**Score:** \(GradeTotals.formatted(draft.totalScore)) / \(GradeTotals.formatted(draft.maxScore))")
            output.append("")
            output.append("### Student response summary")
            output.append(draft.studentResponseSummary)
            output.append("")
            output.append("### Student feedback")
            output.append(draft.studentFeedback)
            output.append("")
            output.append("### Criteria")
            appendCriteria(draft.criteria, to: &output)
        } else {
            output.append("## No grade has been drafted yet")
        }

        output.append("")
        output.append("## Reviewed student text")
        output.append("")
        output.append(assignment.reviewedStudentText.isEmpty ? "No reviewed student text saved." : assignment.reviewedStudentText)
        output.append("")
        output.append("## Rubric")
        output.append("")
        output.append(assignment.rubricText.isEmpty ? "No rubric saved." : assignment.rubricText)
        return output.joined(separator: "\n")
    }

    private static func appendCriteria(_ criteria: [CriterionScore], to output: inout [String]) {
        for criterion in criteria {
            output.append("")
            output.append("#### \(criterion.criterion)")
            output.append("- Score: \(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))")
            output.append("- Rating: \(criterion.rating.isEmpty ? "Not specified" : criterion.rating)")
            output.append("- Explanation: \(criterion.explanation.isEmpty ? "None provided." : criterion.explanation)")
            if !criterion.evidence.isEmpty {
                output.append("- Evidence:")
                for evidence in criterion.evidence {
                    output.append("  - \(evidence)")
                }
            }
            if criterion.teacherReviewRequired {
                output.append("- Teacher review required: yes")
            }
        }
    }

    static func writeTemporaryReport(for assignment: AssignmentRecord) throws -> URL {
        let safeTitle = assignment.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
        let filename = "GradeDraft-\(safeTitle.isEmpty ? assignment.id.uuidString : safeTitle).md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try markdown(for: assignment).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            throw GradeDraftError.exportFailed(error.localizedDescription)
        }
    }
}
