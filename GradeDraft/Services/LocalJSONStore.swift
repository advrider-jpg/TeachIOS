import Foundation

protocol AssignmentStoring {
    func loadAssignments() throws -> [AssignmentRecord]
    func saveAssignments(_ assignments: [AssignmentRecord]) throws
    func deleteAssignment(id: UUID) throws
    func applicationSupportDirectory() throws -> URL
}

final class LocalJSONStore: AssignmentStoring {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let assignmentsURL: URL
    private let appDirectory: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        appDirectory = supportURL.appendingPathComponent("GradeDraft", isDirectory: true)
        assignmentsURL = appDirectory.appendingPathComponent("assignments-v3.json")
    }

    func applicationSupportDirectory() throws -> URL {
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        return appDirectory
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
    static func studentMarkdown(for assignment: AssignmentRecord) -> String {
        var output = reportHeader(title: "GradeDraft Student Feedback", assignment: assignment)
        output.append("\n> This student-facing report excludes private teacher notes and raw model responses.\n")

        if let final = assignment.finalReview {
            output.append("\n## Final teacher-approved grade\n")
            output.append("**Score:** \(GradeTotals.formatted(final.totalScore)) / \(GradeTotals.formatted(final.maxScore))\n")
            output.append("\n### Student feedback\n")
            output.append(final.studentFeedback.isEmpty ? "No feedback provided.\n" : "\(final.studentFeedback)\n")
            output.append("\n### Criteria\n")
            appendFinalCriteria(final.criteria, includeTeacherRationale: false, to: &output)
        } else if let draft = assignment.latestDraft {
            output.append("\n## Draft grade for teacher review\n")
            output.append("**Score:** \(GradeTotals.formatted(draft.totalScore)) / \(GradeTotals.formatted(draft.maxScore))\n")
            output.append("\nThis is not a finalized grade. A teacher must review and approve it before use.\n")
            output.append("\n### Draft student feedback\n")
            output.append("\(draft.studentFeedback)\n")
            output.append("\n### Draft criteria\n")
            appendDraftCriteria(draft.criteria, to: &output)
        } else {
            output.append("\n## No grade has been drafted yet\n")
        }

        return output
    }

    static func teacherAuditMarkdown(for assignment: AssignmentRecord) -> String {
        var output = reportHeader(title: "GradeDraft Teacher Audit Report", assignment: assignment)
        output.append("\n> This teacher audit report may include private notes, reviewed text, OCR warnings, source fingerprints, and grading-state metadata. Treat it as sensitive student data.\n")

        output.append("\n## Readiness and source state\n")
        output.append("- OCR review status: \(assignment.ocrReviewStatus.displayName)\n")
        output.append("- Source inputs: \(assignment.sourceInputs.count)\n")
        output.append("- Current grading packet fingerprint: \(assignment.gradingPacketFingerprint)\n")
        if assignment.latestDraftIsStale {
            output.append("- Draft status: stale; input changed after the draft was generated.\n")
        }
        if assignment.finalReviewIsStale {
            output.append("- Final review status: stale; input changed after the final review was created.\n")
        }

        if !assignment.sourceInputs.isEmpty {
            output.append("\n### Source inputs\n")
            for source in assignment.sourceInputs {
                output.append("- \(source.sourceType.displayName) page \(source.pageIndex.map { String($0 + 1) } ?? "n/a"): \(source.localRelativePath ?? "no local path") [\(source.digestAlgorithm ?? "no digest"): \(source.contentDigest ?? "none")]\n")
            }
        }

        if let ocrDocument = assignment.ocrDocument {
            output.append("\n## OCR summary\n")
            output.append("- Engine: \(ocrDocument.engine)\n")
            output.append("- Review status: \(ocrDocument.reviewStatus.displayName)\n")
            output.append("- Quality: \(ocrDocument.qualitySummary.displaySummary)\n")
        }

        output.append("\n## Reviewed student text\n\n")
        output.append(assignment.reviewedStudentText.isEmpty ? "No reviewed student text saved.\n" : "\(assignment.reviewedStudentText)\n")

        if let final = assignment.finalReview {
            output.append("\n## Final teacher review\n")
            output.append("- Status: \(final.status.rawValue)\n")
            output.append("- Score: \(GradeTotals.formatted(final.totalScore)) / \(GradeTotals.formatted(final.maxScore))\n")
            output.append("- Packet fingerprint: \(final.packetFingerprint)\n")
            output.append("\n### Final criteria\n")
            appendFinalCriteria(final.criteria, includeTeacherRationale: true, to: &output)
            if !final.privateTeacherNotes.isEmpty {
                output.append("\n### Private teacher notes\n\(final.privateTeacherNotes)\n")
            }
        }

        if let draft = assignment.latestDraft {
            output.append("\n## Model draft\n")
            output.append("- Draft status: \(draft.status.rawValue)\n")
            output.append("- Score: \(GradeTotals.formatted(draft.totalScore)) / \(GradeTotals.formatted(draft.maxScore))\n")
            output.append("- Packet fingerprint: \(draft.packetFingerprint)\n")
            output.append("\n### Draft criteria\n")
            appendDraftCriteria(draft.criteria, to: &output)
            if !draft.uncertaintyFlags.isEmpty {
                output.append("\n### Uncertainty flags\n")
                for flag in draft.uncertaintyFlags { output.append("- \(flag)\n") }
            }
            if !draft.complianceFlags.isEmpty {
                output.append("\n### Compliance flags\n")
                for flag in draft.complianceFlags { output.append("- \(flag)\n") }
            }
        }

        output.append("\n## Rubric\n\n")
        output.append(assignment.rubricText.isEmpty ? "No rubric saved.\n" : "\(assignment.rubricText)\n")

        output.append("\n## Audit events\n")
        if assignment.auditEvents.isEmpty {
            output.append("No audit events recorded.\n")
        } else {
            for event in assignment.auditEvents.sorted(by: { $0.timestamp < $1.timestamp }) {
                output.append("- \(event.timestamp): \(event.eventType.rawValue) — \(event.detail)\n")
            }
        }

        return output
    }

    static func writeTemporaryStudentReport(for assignment: AssignmentRecord) throws -> URL {
        try writeTemporaryReport(for: assignment, kind: .studentMarkdown, markdown: studentMarkdown(for: assignment))
    }

    static func writeTemporaryTeacherAuditReport(for assignment: AssignmentRecord) throws -> URL {
        try writeTemporaryReport(for: assignment, kind: .teacherAuditMarkdown, markdown: teacherAuditMarkdown(for: assignment))
    }

    private static func reportHeader(title: String, assignment: AssignmentRecord) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var output = "# \(title)\n\n"
        output += "**Assignment:** \(assignment.title)\n"
        output += "**Student:** \(assignment.studentDisplayName.isEmpty ? "Not specified" : assignment.studentDisplayName)\n"
        output += "**Class:** \(assignment.className.isEmpty ? "Not specified" : assignment.className)\n"
        output += "**Subject:** \(assignment.subject.isEmpty ? "Not specified" : assignment.subject)\n"
        output += "**Grade level:** \(assignment.gradeLevel.isEmpty ? "Not specified" : assignment.gradeLevel)\n"
        output += "**Assignment type:** \(assignment.assignmentType.displayName)\n"
        output += "**Updated:** \(dateFormatter.string(from: assignment.updatedAt))\n"
        output += "\n> Generated from local app state. GradeDraft does not upload this report.\n"
        return output
    }

    private static func appendDraftCriteria(_ criteria: [CriterionScore], to output: inout String) {
        for criterion in criteria {
            output.append("\n#### \(criterion.criterion)\n")
            output.append("- Score: \(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))\n")
            output.append("- Rating: \(criterion.rating.isEmpty ? "Not specified" : criterion.rating)\n")
            output.append("- Explanation: \(criterion.explanation.isEmpty ? "None provided." : criterion.explanation)\n")
            if !criterion.evidence.isEmpty {
                output.append("- Evidence:\n")
                for evidence in criterion.evidence { output.append("  - \(evidence)\n") }
            }
            if criterion.teacherReviewRequired {
                output.append("- Teacher review required: yes\n")
            }
        }
    }

    private static func appendFinalCriteria(_ criteria: [FinalCriterionScore], includeTeacherRationale: Bool, to output: inout String) {
        for criterion in criteria {
            output.append("\n#### \(criterion.criterion)\n")
            output.append("- Final score: \(GradeTotals.formatted(criterion.finalPoints)) / \(GradeTotals.formatted(criterion.maxPoints))\n")
            output.append("- Proposed score: \(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))\n")
            output.append("- Rating: \(criterion.rating.isEmpty ? "Not specified" : criterion.rating)\n")
            output.append("- Explanation: \(criterion.explanation.isEmpty ? "None provided." : criterion.explanation)\n")
            if !criterion.evidence.isEmpty {
                output.append("- Evidence:\n")
                for evidence in criterion.evidence { output.append("  - \(evidence)\n") }
            }
            if includeTeacherRationale && !criterion.teacherRationale.isEmpty {
                output.append("- Teacher rationale: \(criterion.teacherRationale)\n")
            }
        }
    }

    private static func writeTemporaryReport(for assignment: AssignmentRecord, kind: ExportKind, markdown: String) throws -> URL {
        let safeTitle = assignment.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
        let suffix = kind == .studentMarkdown ? "Student" : "TeacherAudit"
        let filename = "GradeDraft-\(suffix)-\(safeTitle.isEmpty ? assignment.id.uuidString : safeTitle).md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            throw GradeDraftError.exportFailed(error.localizedDescription)
        }
    }
}
