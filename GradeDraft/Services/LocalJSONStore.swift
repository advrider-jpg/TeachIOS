import Foundation

protocol AssignmentStoring {
    func loadAssignments() throws -> [AssignmentRecord]
    func saveAssignments(_ assignments: [AssignmentRecord]) throws
    func deleteAssignment(id: UUID) throws
    func applicationSupportDirectory() throws -> URL
    func loadClassGroups() throws -> [ClassGroupRecord]
    func saveClassGroup(_ classGroup: ClassGroupRecord) throws
    func deleteClassGroup(id: UUID) throws
    func loadStudents() throws -> [StudentRecord]
    func saveStudent(_ student: StudentRecord) throws
    func deleteStudent(id: UUID) throws
    func loadAssignmentRoster(assignmentID: UUID) throws -> [AssignmentRosterEntry]
    func saveAssignmentRoster(_ entries: [AssignmentRosterEntry]) throws
    func saveSourceInputs(_ sourceInputs: [SourceInputRef], assignmentID: UUID) throws
    func saveOCRDocument(_ document: OCRDocument, assignmentID: UUID) throws
    func saveFinalReview(_ review: FinalGradeReview, assignmentID: UUID) throws
    func saveEvidenceReferences(_ references: [EvidenceReference], assignmentID: UUID) throws
    func loadFullAssignmentGraph(id: UUID) throws -> AssignmentRecord?
}

final class LocalJSONStore: AssignmentStoring {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let assignmentsURL: URL
    private let classGroupsURL: URL
    private let studentsURL: URL
    private let rosterURL: URL
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
        classGroupsURL = appDirectory.appendingPathComponent("classgroups-v3.json")
        studentsURL = appDirectory.appendingPathComponent("students-v3.json")
        rosterURL = appDirectory.appendingPathComponent("roster-v3.json")
    }

    func applicationSupportDirectory() throws -> URL {
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }
        return appDirectory
    }

    func loadAssignments() throws -> [AssignmentRecord] {
        guard fileManager.fileExists(atPath: assignmentsURL.path) else { return [] }
        let data = try Data(contentsOf: assignmentsURL)
        return try decoder.decode([AssignmentRecord].self, from: data)
    }

    func saveAssignments(_ assignments: [AssignmentRecord]) throws {
        let directory = assignmentsURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let data = try encoder.encode(assignments.sorted { $0.updatedAt > $1.updatedAt })
        try data.write(to: assignmentsURL, options: [.atomic])
    }

    func deleteAssignment(id: UUID) throws {
        var assignments = try loadAssignments()
        assignments.removeAll { $0.id == id }
        try saveAssignments(assignments)
    }

    func loadClassGroups() throws -> [ClassGroupRecord] {
        guard fileManager.fileExists(atPath: classGroupsURL.path) else { return [] }
        return (try? decoder.decode([ClassGroupRecord].self, from: Data(contentsOf: classGroupsURL))) ?? []
    }

    func saveClassGroup(_ classGroup: ClassGroupRecord) throws {
        var groups = try loadClassGroups()
        if let index = groups.firstIndex(where: { $0.id == classGroup.id }) {
            groups[index] = classGroup
        } else {
            groups.append(classGroup)
        }
        try encoder.encode(groups).write(to: classGroupsURL, options: [.atomic])
    }

    func deleteClassGroup(id: UUID) throws {
        var groups = try loadClassGroups()
        groups.removeAll { $0.id == id }
        try encoder.encode(groups).write(to: classGroupsURL, options: [.atomic])
    }

    func loadStudents() throws -> [StudentRecord] {
        guard fileManager.fileExists(atPath: studentsURL.path) else { return [] }
        return (try? decoder.decode([StudentRecord].self, from: Data(contentsOf: studentsURL))) ?? []
    }

    func saveStudent(_ student: StudentRecord) throws {
        var students = try loadStudents()
        if let index = students.firstIndex(where: { $0.id == student.id }) {
            students[index] = student
        } else {
            students.append(student)
        }
        try encoder.encode(students).write(to: studentsURL, options: [.atomic])
    }

    func deleteStudent(id: UUID) throws {
        var students = try loadStudents()
        students.removeAll { $0.id == id }
        try encoder.encode(students).write(to: studentsURL, options: [.atomic])
    }

    func loadAssignmentRoster(assignmentID: UUID) throws -> [AssignmentRosterEntry] {
        try loadAllRosterEntries().filter { $0.assignmentID == assignmentID }
    }

    func saveAssignmentRoster(_ entries: [AssignmentRosterEntry]) throws {
        let assignmentIDs = Set(entries.map(\.assignmentID))
        var all = try loadAllRosterEntries()
        all.removeAll { assignmentIDs.contains($0.assignmentID) }
        all.append(contentsOf: entries)
        try encoder.encode(all).write(to: rosterURL, options: [.atomic])
    }

    private func loadAllRosterEntries() throws -> [AssignmentRosterEntry] {
        guard fileManager.fileExists(atPath: rosterURL.path) else { return [] }
        return (try? decoder.decode([AssignmentRosterEntry].self, from: Data(contentsOf: rosterURL))) ?? []
    }
}

enum MarkdownReportBuilder {
    static func studentMarkdown(for assignment: AssignmentRecord) -> String {
        var output = reportHeader(title: "GradeDraft Student Report", assignment: assignment)
        output.append("\n> This student-facing report includes only teacher-approved student-facing content and excludes private teacher notes, review history, scanned-text review details, original-file details, and unreviewed AI suggestions.\n")

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
            output.append("\n### Feedback suggestion for teacher review\n")
            output.append("\(draft.studentFeedback)\n")
            output.append("\n### Criteria suggestions\n")
            appendDraftCriteria(draft.criteria, to: &output)
        } else {
            output.append("\n## No grade has been drafted yet\n")
        }

        return output
    }

    static func teacherAuditMarkdown(for assignment: AssignmentRecord) -> String {
        var output = reportHeader(title: "GradeDraft Teacher Review", assignment: assignment)
        output.append("\n> This teacher-only review may include private notes, reviewed student work, scanned-text review details, original-file details, and local review history. Treat it as sensitive student data.\n")

        output.append("\n## Readiness and student work status\n")
        output.append("- Scanned-text review status: \(assignment.ocrReviewStatus.displayName)\n")
        output.append("- Original files: \(assignment.sourceInputs.count)\n")
        output.append("- Local review detail: \(assignment.gradingPacketFingerprint)\n")
        if assignment.latestDraftIsStale {
            output.append("- Draft status: Needs recheck; student work or rubric changed after the feedback suggestion was created.\n")
        }
        if assignment.finalReviewIsStale {
            output.append("- Final review status: Needs recheck; student work or rubric changed after the final review was created.\n")
        }

        if !assignment.sourceInputs.isEmpty {
            output.append("\n### Original files\n")
            for source in assignment.sourceInputs {
                output.append("- \(source.sourceType.displayName) page \(source.pageIndex.map { String($0 + 1) } ?? "n/a"): \(source.localRelativePath ?? "not recorded") [\(source.digestAlgorithm ?? "no digest"): \(source.contentDigest ?? "none")]\n")
            }
        }

        if let ocrDocument = assignment.ocrDocument {
            output.append("\n## Scanned-text review summary\n")
            output.append("- Engine: \(ocrDocument.engine)\n")
            output.append("- Review status: \(ocrDocument.reviewStatus.displayName)\n")
            output.append("- Quality: \(ocrDocument.qualitySummary.displaySummary)\n")
        }

        if !assignment.curriculumReference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !assignment.curriculumMappings.isEmpty {
            output.append("\n## Curriculum references\n")
            output.append(assignment.curriculumReference.isEmpty ? CurriculumCatalogService.sourceWarning : "\(assignment.curriculumReference)\n")
            for mapping in assignment.curriculumMappings {
                if let item = CurriculumCatalogService.item(id: mapping.curriculumItemID) {
                    output.append("- \(CurriculumCatalogService.displaySummary(for: item))\n")
                }
            }
        }

        output.append("\n## Reviewed student text\n\n")
        output.append(assignment.reviewedStudentText.isEmpty ? "No reviewed student text saved.\n" : "\(assignment.reviewedStudentText)\n")

        if let final = assignment.finalReview {
            output.append("\n## Final teacher review\n")
            output.append("- Status: \(finalReviewStatusLabel(final.status))\n")
            output.append("- Score: \(GradeTotals.formatted(final.totalScore)) / \(GradeTotals.formatted(final.maxScore))\n")
            output.append("- Local review detail: \(final.packetFingerprint)\n")
            output.append("\n### Final criteria\n")
            appendFinalCriteria(final.criteria, includeTeacherRationale: true, to: &output)
            if !final.privateTeacherNotes.isEmpty {
                output.append("\n### Private teacher notes\n\(final.privateTeacherNotes)\n")
            }
        }

        if let draft = assignment.latestDraft {
            output.append("\n## Feedback suggestion for teacher review\n")
            output.append("- Draft status: \(draftStatusLabel(draft.status))\n")
            output.append("- Score: \(GradeTotals.formatted(draft.totalScore)) / \(GradeTotals.formatted(draft.maxScore))\n")
            output.append("- Local review detail: \(draft.packetFingerprint)\n")
            output.append("\n### Criteria suggestions\n")
            appendDraftCriteria(draft.criteria, to: &output)
            if !draft.uncertaintyFlags.isEmpty {
                output.append("\n### Items needing attention\n")
                for flag in draft.uncertaintyFlags { output.append("- \(flag)\n") }
            }
            if !draft.complianceFlags.isEmpty {
                output.append("\n### Review notes\n")
                for flag in draft.complianceFlags { output.append("- \(flag)\n") }
            }
        }

        output.append("\n## Rubric\n\n")
        output.append(assignment.rubricText.isEmpty ? "No rubric saved.\n" : "\(assignment.rubricText)\n")

        if !assignment.evidenceReferences.isEmpty {
            output.append("\n## Evidence\n")
            for evidence in assignment.evidenceReferences {
                output.append("- \(evidence.quote) — \(evidence.displaySource)")
                if let box = evidence.boundingBox {
                    output.append(" — bbox: \(box.stableDisplay)")
                }
                output.append("\n")
            }
        }

        output.append("\n## Review history\n")
        if assignment.auditEvents.isEmpty {
            output.append("No review history recorded.\n")
        } else {
            for event in assignment.auditEvents.sorted(by: { $0.timestamp < $1.timestamp }) {
                output.append("- \(event.timestamp): \(event.eventType.rawValue) — \(event.detail)\n")
            }
        }

        return output
    }

    static func writeTemporaryStudentReport(for assignment: AssignmentRecord) throws -> URL {
        try writeTemporaryReport(for: assignment, kind: .studentMarkdown, content: studentMarkdown(for: assignment))
    }

    static func writeTemporaryTeacherAuditReport(for assignment: AssignmentRecord) throws -> URL {
        try writeTemporaryReport(for: assignment, kind: .teacherAuditMarkdown, content: teacherAuditMarkdown(for: assignment))
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
            if includeTeacherRationale {
                output.append("- Suggestion score: \(GradeTotals.formatted(criterion.proposedPoints)) / \(GradeTotals.formatted(criterion.maxPoints))\n")
            }
            output.append("- Rating: \(criterion.rating.isEmpty ? "Not specified" : criterion.rating)\n")
            output.append("- Explanation: \(criterion.explanation.isEmpty ? "None provided." : criterion.explanation)\n")
            if !criterion.evidence.isEmpty {
                output.append("- Evidence:\n")
                for evidence in criterion.evidence { output.append("  - \(evidence)\n") }
            }
            if includeTeacherRationale, let refs = criterion.evidenceSourceRefs, !refs.isEmpty {
                output.append("- Teacher-only evidence details:\n")
                for ref in refs { output.append("  - \(ref)\n") }
            }
            if includeTeacherRationale && !criterion.teacherRationale.isEmpty {
                output.append("- Teacher rationale: \(criterion.teacherRationale)\n")
            }
        }
    }


    private static func finalReviewStatusLabel(_ status: FinalReviewStatus) -> String {
        switch status {
        case .inProgress:
            return "Review final grade"
        case .approved:
            return "Approved"
        case .stale:
            return "Needs recheck"
        }
    }

    private static func draftStatusLabel(_ status: DraftStatus) -> String {
        switch status {
        case .generated:
            return "Ready for teacher review"
        case .stale:
            return "Needs recheck"
        case .teacherReviewRequired:
            return "Needs attention"
        }
    }

    private static func writeTemporaryReport(for assignment: AssignmentRecord, kind: ExportKind, content: String) throws -> URL {
        let safeTitle = assignment.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
        let suffix: String
        let filenameExtension: String
        switch kind {
        case .studentMarkdown:
            suffix = "Student"
            filenameExtension = "md"
        case .teacherAuditMarkdown:
            suffix = "TeacherReview"
            filenameExtension = "md"
        case .studentPDF:
            suffix = "Student"
            filenameExtension = "pdf"
        case .teacherAuditPDF:
            suffix = "TeacherReview"
            filenameExtension = "pdf"
        case .csvGradebook:
            suffix = "CSV"
            filenameExtension = "csv"
        case .zipArchive:
            suffix = "Archive"
            filenameExtension = "zip"
        case .fullBackupArchive:
            suffix = "FullBackup"
            filenameExtension = "zip"
        case .backupJSON:
            suffix = "Backup"
            filenameExtension = "json"
        }
        let filename = "GradeDraft-\(suffix)-\(safeTitle.isEmpty ? assignment.id.uuidString : safeTitle).\(filenameExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            throw GradeDraftError.exportFailed(error.localizedDescription)
        }
    }
}

extension AssignmentStoring {
    func loadClassGroups() throws -> [ClassGroupRecord] { [] }
    func saveClassGroup(_ classGroup: ClassGroupRecord) throws { _ = classGroup }
    func deleteClassGroup(id: UUID) throws { _ = id }
    func loadStudents() throws -> [StudentRecord] { [] }
    func saveStudent(_ student: StudentRecord) throws { _ = student }
    func deleteStudent(id: UUID) throws { _ = id }
    func loadAssignmentRoster(assignmentID: UUID) throws -> [AssignmentRosterEntry] { _ = assignmentID; return [] }
    func saveAssignmentRoster(_ entries: [AssignmentRosterEntry]) throws { _ = entries }
    func saveSourceInputs(_ sourceInputs: [SourceInputRef], assignmentID: UUID) throws { _ = sourceInputs; _ = assignmentID }
    func saveOCRDocument(_ document: OCRDocument, assignmentID: UUID) throws { _ = document; _ = assignmentID }
    func saveFinalReview(_ review: FinalGradeReview, assignmentID: UUID) throws { _ = review; _ = assignmentID }
    func saveEvidenceReferences(_ references: [EvidenceReference], assignmentID: UUID) throws { _ = references; _ = assignmentID }
    func loadFullAssignmentGraph(id: UUID) throws -> AssignmentRecord? { try loadAssignments().first { $0.id == id } }
}
