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

        if let final = assignment.finalReview, final.status == .approved, !assignment.finalReviewIsStale {
            output.append("\n## Final teacher-approved grade\n")
            output.append("**Score:** \(GradeTotals.formatted(final.totalScore)) / \(GradeTotals.formatted(final.maxScore))\n")
            output.append("\n### Student feedback\n")
            output.append(final.studentFeedback.isEmpty ? "No feedback provided.\n" : "\(final.studentFeedback)\n")
            output.append("\n### Criteria\n")
            appendFinalCriteria(final.criteria, includeTeacherRationale: false, to: &output)
        } else {
            output.append("\n## No final teacher-approved grade is available\n")
            output.append("Student-facing export is blocked until the teacher approves a current final grade. Draft suggestions and stale reviews are available only in teacher-only records.\n")
        }

        return output
    }

    static func teacherAuditMarkdown(for assignment: AssignmentRecord, generatedAt: Date = Date(), generatedForExportKind: ExportKind? = nil) -> String {
        var output = reportHeader(title: "GradeDraft Teacher Review", assignment: assignment)
        output.append("\n> This teacher-only review may include private notes, reviewed student work, scanned-text review details, original-file details, and local review history. Treat it as sensitive student data.\n")
        output.append("\n**Report generated:** \(generatedAt)\n")
        if let generatedForExportKind {
            output.append("**Generated for export:** \(generatedForExportKind.displayName)\n")
        }

        output.append("\n## Readiness and student work status\n")
        output.append("- Scanned-text review status: \(assignment.ocrReviewStatus.displayName)\n")
        output.append("- Original files: \(assignment.sourceInputs.count)\n")
        output.append("- Local review detail: \(assignment.gradingPacketFingerprint)\n")
        if !assignment.selectedInstructionTemplateIDs.isEmpty {
            output.append("- Selected AI constraint templates: \(assignment.selectedInstructionTemplateIDs.joined(separator: ", "))\n")
            for template in GradingConstraintTemplates.templates(for: assignment.selectedInstructionTemplateIDs) {
                output.append("  - \(template.title): \(template.text)\n")
            }
        }
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

        output.append("\n## Grading packet context\n")
        output.append("- Packet version: \(assignment.gradingPacket.packetVersion)\n")
        output.append("- Fingerprint schema: \(assignment.gradingPacketFingerprintVersion)\n")
        output.append("- Local review detail: \(assignment.gradingPacketFingerprint)\n")
        appendTeacherOnlySection(title: "Rubric", value: assignment.rubricText, emptyMessage: "No rubric saved.", to: &output)
        appendTeacherOnlySection(title: "Custom teacher instructions", value: GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.customInstructions), emptyMessage: "No custom teacher instructions saved.", to: &output)
        appendTeacherOnlySection(title: "Formative focus", value: GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.formativeFocusText), emptyMessage: "No formative focus saved.", to: &output)
        appendTeacherOnlySection(title: "Answer key", value: GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.answerKeyText), emptyMessage: "No answer key saved.", to: &output)
        appendTeacherOnlySection(title: "Exemplar", value: GradeDraftTemplateApplication.withoutTemplateMarkers(assignment.exemplarText), emptyMessage: "No exemplar saved.", to: &output)
        if !assignment.appliedTemplates.isEmpty {
            output.append("\n### Applied templates\n")
            for record in assignment.appliedTemplates.sorted(by: { $0.appliedAt < $1.appliedAt }) {
                output.append("- \(record.appliedAt): \(record.templateKind.displayName) — \(record.templateName) [id: \(record.templateID); mode: \(record.insertionMode.rawValue)]\n")
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
            if let audit = draft.localModelAudit {
                output.append("\n### Local model audit\n")
                output.append("- Provider: \(audit.provider)\n")
                output.append("- Framework: \(audit.framework)\n")
                output.append("- Prompt version: \(audit.promptVersion)\n")
                output.append("- Schema version: \(audit.schemaVersion)\n")
                output.append("- Validator version: \(audit.validatorVersion)\n")
                output.append("- Generation mode: \(audit.generationMode.rawValue)\n")
                output.append("- Prompt fingerprint: \(audit.promptFingerprint)\n")
                output.append("- Input packet fingerprint: \(audit.inputPacketFingerprint)\n")
                output.append("- Selected template IDs: \(audit.selectedInstructionTemplateIDs.joined(separator: ", "))\n")
                output.append("- Selected template fingerprint: \(audit.selectedInstructionTemplateFingerprint)\n")
                output.append("- Context size tokens: \(audit.contextSizeTokens.map(String.init) ?? "not measured")\n")
                output.append("- Estimated/measured input tokens: \(audit.estimatedOrMeasuredInputTokens.map(String.init) ?? "not measured")\n")
                output.append("- Reserved output tokens: \(audit.reservedOutputTokens.map(String.init) ?? "not measured")\n")
                output.append("- Criteria requested/generated: \(audit.criteriaRequested)/\(audit.criteriaGenerated)\n")
                output.append("- OCR status: \(audit.ocrReviewStatus.displayName)\n")
                output.append("- OCR quality: \(audit.ocrQualitySummary.displaySummary)\n")
                if !audit.validationWarnings.isEmpty {
                    output.append("- Validation warnings:\n")
                    for warning in audit.validationWarnings { output.append("  - \(warning)\n") }
                }
                if let errorSummary = audit.generationErrorSummary {
                    output.append("- Generation error summary: \(errorSummary)\n")
                }
            }
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

        if !assignment.exportRecords.isEmpty {
            output.append("\n## Export records\n")
            for record in assignment.exportRecords.sorted(by: { $0.createdAt < $1.createdAt }) {
                output.append("- \(record.createdAt): \(record.exportKind.displayName); private notes included: \(record.includesPrivateTeacherNotes ? "yes" : "no"); original files included: \(record.includesOriginalSources ? "yes" : "no"); detail: \(record.contentFingerprint)\n")
            }
        }

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

    static func writeTemporaryTeacherAuditReport(for assignment: AssignmentRecord, generatedAt: Date = Date()) throws -> URL {
        try writeTemporaryReport(for: assignment, kind: .teacherAuditMarkdown, content: teacherAuditMarkdown(for: assignment, generatedAt: generatedAt, generatedForExportKind: .teacherAuditMarkdown))
    }

    private static func appendTeacherOnlySection(title: String, value: String, emptyMessage: String, to output: inout String) {
        output.append("\n### \(title)\n\n")
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        output.append(trimmed.isEmpty ? "\(emptyMessage)\n" : "\(trimmed)\n")
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
        let filenameExtension: String
        switch kind {
        case .studentMarkdown, .teacherAuditMarkdown:
            filenameExtension = "md"
        case .studentPDF, .teacherAuditPDF:
            filenameExtension = "pdf"
        case .csvGradebook:
            filenameExtension = "csv"
        case .zipArchive, .fullBackupArchive:
            filenameExtension = "zip"
        case .backupJSON:
            filenameExtension = "json"
        }
        let filename = ExportFilenameBuilder.filename(kind: kind, assignmentID: assignment.id, extension: filenameExtension)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            ExportFileHardening.applyBestEffortProtection(to: url)
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
