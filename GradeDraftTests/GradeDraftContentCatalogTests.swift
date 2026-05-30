import XCTest
@testable import GradeDraft

final class GradeDraftContentCatalogTests: XCTestCase {
    func testPlannedContentCatalogsContainRequiredTemplatesAndRules() throws {
        try GradeDraftContentValidator.validateAllCatalogs()
        XCTAssertEqual(RubricTemplateCatalog.builtIn.count, 9)
        XCTAssertEqual(TeacherInstructionTemplateCatalog.all.count, 11)
        XCTAssertEqual(AnswerKeyTemplateCatalog.all.count, 3)
        XCTAssertEqual(ExemplarTemplateCatalog.all.count, 1)
        XCTAssertEqual(FormativeFocusTemplateCatalog.all.count, 1)
        XCTAssertEqual(ExportWarningCatalog.all.count, 13)
        XCTAssertEqual(GradeDraftCopyCatalog.SourceOfTruth.nonNegotiableRules.count, 20)
        XCTAssertTrue(GradeDraftCopyCatalog.SourceOfTruth.nonNegotiableRules.contains { $0.contains("Every proposed criterion score must cite student evidence") })
        XCTAssertFalse(GradeDraftCopyCatalog.OCRReview.states.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.OCRReview.confidenceBands.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.TeacherReview.workflowCopy.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.StudentFeedbackRules.rules.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.Privacy.localFirst.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.ReadinessCopy.emptyStates.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.RegionalCurriculum.safeguards.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.InclusiveSafeguards.rules.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.FormativeMode.schema.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.FutureModeGuardrails.unavailableModes.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.ExportFormatRequirements.requirements.isEmpty)
        XCTAssertFalse(GradeDraftCopyCatalog.AcceptanceCriteria.criteria.isEmpty)
    }

    func testSwiftCatalogsMatchStructuredJSONResource() throws {
        let catalog = try loadResourceCatalog()

        XCTAssertEqual(catalog.rubricTemplates.map(\.id), RubricTemplateCatalog.builtIn.map(\.id))
        XCTAssertEqual(catalog.teacherInstructionTemplates.map(\.id), TeacherInstructionTemplateCatalog.all.map(\.id))
        XCTAssertEqual(catalog.answerKeyTemplates.map(\.id), AnswerKeyTemplateCatalog.all.map(\.id))
        XCTAssertEqual(catalog.exemplarTemplates.map(\.id), ExemplarTemplateCatalog.all.map(\.id))
        XCTAssertEqual(catalog.formativeFocusTemplates.map(\.id), FormativeFocusTemplateCatalog.all.map(\.id))
        XCTAssertEqual(catalog.exportWarnings.map(\.id), ExportWarningCatalog.all.map(\.id))

        for (resource, swift) in zip(catalog.rubricTemplates, RubricTemplateCatalog.builtIn) {
            XCTAssertEqual(resource.name, swift.name)
            XCTAssertEqual(resource.assignmentType, swift.assignmentType.rawValue)
            XCTAssertEqual(resource.assessmentPurpose, swift.assessmentPurpose.rawValue)
            XCTAssertEqual(resource.description, swift.description)
            XCTAssertEqual(resource.rubricText, swift.rubricText)
            XCTAssertEqual(resource.customInstructions, swift.customInstructions)
        }

        for (resource, swift) in zip(catalog.teacherInstructionTemplates, TeacherInstructionTemplateCatalog.all) {
            XCTAssertEqual(resource.name, swift.name)
            XCTAssertEqual(resource.description, swift.description)
            XCTAssertEqual(resource.text, swift.text)
            XCTAssertEqual(resource.scope, swift.scope.rawValue)
            XCTAssertEqual(resource.priority, swift.priority.rawValue)
            XCTAssertEqual(resource.studentFacing, swift.studentFacing)
            XCTAssertEqual(resource.privateTeacherOnly, swift.privateTeacherOnly)
        }

        for (resource, swift) in zip(catalog.answerKeyTemplates, AnswerKeyTemplateCatalog.all) {
            XCTAssertEqual(resource.name, swift.name)
            XCTAssertEqual(resource.assignmentTypes, swift.assignmentTypes.map(\.rawValue))
            XCTAssertEqual(resource.description, swift.description)
            XCTAssertEqual(resource.markdownTemplate, swift.markdownTemplate)
        }

        for (resource, swift) in zip(catalog.exemplarTemplates, ExemplarTemplateCatalog.all) {
            XCTAssertEqual(resource.name, swift.name)
            XCTAssertEqual(resource.assignmentTypes, swift.assignmentTypes.map(\.rawValue))
            XCTAssertEqual(resource.description, swift.description)
            XCTAssertEqual(resource.markdownTemplate, swift.markdownTemplate)
        }

        for (resource, swift) in zip(catalog.formativeFocusTemplates, FormativeFocusTemplateCatalog.all) {
            XCTAssertEqual(resource.name, swift.name)
            XCTAssertEqual(resource.assignmentTypes, swift.assignmentTypes.map(\.rawValue))
            XCTAssertEqual(resource.description, swift.description)
            XCTAssertEqual(resource.markdownTemplate, swift.markdownTemplate)
        }

        for (resource, swift) in zip(catalog.exportWarnings, ExportWarningCatalog.all) {
            XCTAssertEqual(resource.name, swift.name)
            XCTAssertEqual(resource.title, swift.title)
            XCTAssertEqual(resource.body, swift.body)
            XCTAssertEqual(resource.warningLine, swift.warningLine)
            XCTAssertEqual(resource.securityNote, swift.securityNote)
            XCTAssertEqual(resource.checklist, swift.checklist)
            XCTAssertEqual(resource.primaryButton, swift.primaryButton)
            XCTAssertEqual(resource.secondaryButton, swift.secondaryButton)
            XCTAssertEqual(resource.finalButton, swift.finalButton)
            XCTAssertEqual(resource.optionalCheckbox, swift.optionalCheckbox)
            XCTAssertEqual(resource.postPreviewConfirmation, swift.postPreviewConfirmation)
            XCTAssertEqual(resource.escalatedConfirmation, swift.escalatedConfirmation)
            XCTAssertEqual(resource.defaultChoice, swift.defaultChoice)
            XCTAssertEqual(resource.acknowledgementText, swift.acknowledgementText)
            XCTAssertEqual(resource.requiresAcknowledgement, swift.requiresAcknowledgement)
            XCTAssertEqual(resource.blocksStudentFacingExportByDefault, swift.blocksStudentFacingExportByDefault)
        }

        XCTAssertEqual(catalog.canonicalPromptTemplate, GradeDraftCopyCatalog.SourceOfTruth.canonicalPromptTemplate)
        XCTAssertEqual(catalog.nonNegotiableRules, GradeDraftCopyCatalog.SourceOfTruth.nonNegotiableRules)
        XCTAssertEqual(catalog.safeUILabels, GradeDraftCopyCatalog.Labels.safe)
        XCTAssertEqual(catalog.prohibitedUILabels, GradeDraftCopyCatalog.Labels.prohibited)
        XCTAssertEqual(catalog.ocrReviewStates, GradeDraftCopyCatalog.OCRReview.states)
        XCTAssertEqual(catalog.ocrConfidenceBands, GradeDraftCopyCatalog.OCRReview.confidenceBands)
        XCTAssertEqual(catalog.teacherReviewWorkflowCopy, GradeDraftCopyCatalog.TeacherReview.workflowCopy)
        XCTAssertEqual(catalog.studentFeedbackRules, GradeDraftCopyCatalog.StudentFeedbackRules.rules)
        XCTAssertEqual(catalog.emptyStateCopy, GradeDraftCopyCatalog.ReadinessCopy.emptyStates)
        XCTAssertEqual(catalog.regionalCurriculumSafeguards, GradeDraftCopyCatalog.RegionalCurriculum.safeguards)
        XCTAssertEqual(catalog.inclusiveSafeguards, GradeDraftCopyCatalog.InclusiveSafeguards.rules)
        XCTAssertEqual(catalog.formativeModeSchema, GradeDraftCopyCatalog.FormativeMode.schema)
        XCTAssertEqual(catalog.futureModeGuardrails, GradeDraftCopyCatalog.FutureModeGuardrails.unavailableModes)
        XCTAssertEqual(catalog.exportFormatRequirements, GradeDraftCopyCatalog.ExportFormatRequirements.requirements)
        XCTAssertEqual(catalog.acceptanceCriteria, GradeDraftCopyCatalog.AcceptanceCriteria.criteria)
    }

    func testTemplateInsertionUpdatesExpectedFieldsFingerprintMetadataAndIdempotency() throws {
        let original = AssignmentRecord(title: "Example", rubricText: "Criterion: 0-1 point", reviewedStudentText: "Student answer")
        let initialFingerprint = original.plannedContentPacketFingerprint

        let instruction = try XCTUnwrap(TeacherInstructionTemplateCatalog.template(id: "general-evidence-first"))
        let withInstruction = GradeDraftTemplateApplication.appendingInstructionTemplate(instruction, to: original)
        XCTAssertTrue(withInstruction.customInstructions.contains(instruction.text))
        XCTAssertTrue(withInstruction.customInstructions.contains("GradeDraftTemplate:teacherInstruction:general-evidence-first"))
        XCTAssertTrue(withInstruction.gradingPacket.teacherInstructions.first?.text.contains("GradeDraftTemplate") == false)
        XCTAssertEqual(withInstruction.appliedTemplates.last?.templateID, instruction.id)
        XCTAssertNotEqual(withInstruction.plannedContentPacketFingerprint, initialFingerprint)

        let duplicateInstruction = GradeDraftTemplateApplication.appendingInstructionTemplate(instruction, to: withInstruction)
        XCTAssertEqual(duplicateInstruction.customInstructions, withInstruction.customInstructions)
        XCTAssertEqual(duplicateInstruction.appliedTemplates.count, withInstruction.appliedTemplates.count)

        let answerKey = try XCTUnwrap(AnswerKeyTemplateCatalog.template(id: "short-answer-answer-key"))
        let withAnswerKey = GradeDraftTemplateApplication.insertingAnswerKeyTemplate(answerKey, to: withInstruction)
        XCTAssertTrue(withAnswerKey.answerKeyText.contains("Full-credit answer"))
        XCTAssertEqual(withAnswerKey.appliedTemplates.last?.templateKind, .answerKey)
        XCTAssertNotEqual(withAnswerKey.plannedContentPacketFingerprint, withInstruction.plannedContentPacketFingerprint)

        let exemplar = try XCTUnwrap(ExemplarTemplateCatalog.template(id: "paragraph-essay-exemplar"))
        let withExemplar = GradeDraftTemplateApplication.insertingExemplarTemplate(exemplar, to: withAnswerKey)
        XCTAssertTrue(withExemplar.exemplarText.contains(exemplar.markdownTemplate))
        XCTAssertEqual(withExemplar.appliedTemplates.last?.templateKind, .exemplar)
        XCTAssertNotEqual(withExemplar.plannedContentPacketFingerprint, withAnswerKey.plannedContentPacketFingerprint)

        let formative = try XCTUnwrap(FormativeFocusTemplateCatalog.template(id: "formative-focus"))
        let withFormative = GradeDraftTemplateApplication.insertingFormativeFocusTemplate(formative, to: withExemplar)
        XCTAssertTrue(withFormative.formativeFocusText.contains(formative.markdownTemplate))
        XCTAssertFalse(withFormative.customInstructions.contains(formative.markdownTemplate))
        XCTAssertEqual(withFormative.assessmentPurpose, .formative)
        XCTAssertEqual(withFormative.appliedTemplates.last?.templateKind, .formativeFocus)
        XCTAssertNotEqual(withFormative.plannedContentPacketFingerprint, withExemplar.plannedContentPacketFingerprint)
    }

    @MainActor
    func testViewModelTemplateApplicationMarksExistingDraftAndFinalReviewStaleAndAuditsBoth() throws {
        var assignment = AssignmentRecord(title: "Stale-state test", rubricText: "Criterion: 0-1 point", reviewedStudentText: "Student answer")
        let startingFingerprint = assignment.gradingPacketFingerprint
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: startingFingerprint,
            status: .generated,
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Feedback",
            teacherNotes: "Teacher note",
            uncertaintyFlags: []
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: startingFingerprint,
            status: .approved,
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Feedback",
            privateTeacherNotes: "Private note",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)
        let template = try XCTUnwrap(TeacherInstructionTemplateCatalog.template(id: "general-evidence-first"))

        viewModel.applyTeacherInstructionTemplate(template)

        XCTAssertEqual(viewModel.assignment.latestDraft?.status, .stale)
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .stale)
        XCTAssertTrue(viewModel.assignment.auditEvents.contains { $0.eventType == .draftMarkedStale })
        XCTAssertTrue(viewModel.assignment.auditEvents.contains { $0.eventType == .finalReviewMarkedStale })
        XCTAssertNotEqual(viewModel.assignment.gradingPacketFingerprint, startingFingerprint)
    }

    func testRubricTemplateApplicationPreservesExistingPublicAPIAndDoesNotClearReviewByDefault() throws {
        let template = try XCTUnwrap(RubricTemplateCatalog.template(id: "formative-exit-ticket-8pt"))
        var assignment = AssignmentRecord(title: "Exit ticket", assessmentPurpose: .summative)
        assignment.latestDraft = GradeDraftResult(studentResponseSummary: "Summary", criteria: [], totalScore: 0, maxScore: 0, studentFeedback: "Draft", teacherNotes: "Note", uncertaintyFlags: [])
        let updated = GradeDraftTemplateApplication.applyingRubricTemplate(template, to: assignment)
        XCTAssertEqual(updated.assignmentType, .shortAnswer)
        XCTAssertEqual(updated.assessmentPurpose, .formative)
        XCTAssertTrue(updated.rubricText.contains("Shows current understanding"))
        XCTAssertNotNil(updated.latestDraft)
        XCTAssertEqual(RubricTemplates.builtIn.map(\.id), RubricTemplateCatalog.builtIn.map(\.id))
    }

    func testExportWarningsAreMappedToExportKindsAndExposeExpandedFields() throws {
        XCTAssertEqual(ExportWarningCatalog.warningIDs(for: .studentMarkdown), ["student-report-warning"])
        XCTAssertEqual(ExportWarningCatalog.warningIDs(for: .teacherAuditMarkdown), ["teacher-only-record-warning"])
        XCTAssertEqual(ExportWarningCatalog.warningIDs(for: .studentPDF), ["pdf-warning", "student-report-warning"])
        XCTAssertEqual(ExportWarningCatalog.warningIDs(for: .teacherAuditPDF), ["teacher-only-record-warning", "pdf-warning"])
        XCTAssertEqual(ExportWarningCatalog.warningIDs(for: .csvGradebook), ["csv-warning"])
        XCTAssertEqual(ExportWarningCatalog.warningIDs(for: .zipArchive), ["zip-archive-warning"])
        XCTAssertEqual(ExportWarningCatalog.warningIDs(for: .fullBackupArchive), ["zip-archive-warning", "json-backup-warning"])
        XCTAssertEqual(ExportWarningCatalog.warningIDs(for: .backupJSON), ["json-backup-warning"])
        XCTAssertTrue(ExportWarningCatalog.warningIDs(for: .assignmentGradebookArchive).contains("zip-archive-warning"))
        XCTAssertTrue(ExportWarningCatalog.warningIDs(for: .assignmentGradebookArchive).contains("csv-warning"))
        XCTAssertEqual(ExportWarningCatalog.primaryWarning(for: .fullBackupArchive)?.id, "zip-archive-warning")

        let teacherPDFWarnings = ExportConfirmationKind.teacherReviewPDF.baseWarnings
        XCTAssertEqual(teacherPDFWarnings.map(\.id), ["teacher-only-record-warning", "pdf-warning"])
        XCTAssertNotNil(teacherPDFWarnings.first { $0.id == "pdf-warning" }?.postPreviewConfirmation)
        XCTAssertEqual(ExportConfirmationKind.fullBackup.baseWarnings.map(\.id), ["zip-archive-warning", "json-backup-warning"])
        XCTAssertNotNil(ExportWarningCatalog.warning(id: "delete-local-data-warning")?.escalatedConfirmation)
        XCTAssertEqual(ExportWarningCatalog.clearStudentWorkWarning.id, "clear-student-work-warning")

        for warning in ExportWarningCatalog.all {
            XCTAssertFalse(warning.primaryButton.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(warning.secondaryButton.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(warning.requiresAcknowledgement)
        }
    }

    func testPromptUsesCanonicalTemplateOptionalSectionsAndSafeNonRecursiveRendering() {
        var assignment = AssignmentRecord(title: "Prompt", rubricText: "Criterion: 0-1 point", reviewedStudentText: "Student text")
        assignment.customInstructions = "Use concise comments."
        assignment.answerKeyText = "Expected element."
        assignment.exemplarText = "Exemplar response."
        assignment.formativeFocusText = "Focus on next steps."
        assignment.curriculumReference = "Local reference."

        let prompt = PromptBuilder.gradingPrompt(input: assignment.gradingInput)
        XCTAssertTrue(prompt.contains("Use concise comments."))
        XCTAssertTrue(prompt.contains("Expected element."))
        XCTAssertTrue(prompt.contains("Exemplar response."))
        XCTAssertTrue(prompt.contains("Focus on next steps."))
        XCTAssertTrue(prompt.contains("Local reference."))
        XCTAssertTrue(prompt.contains("No supporting evidence found."))
        XCTAssertTrue(prompt.contains("source reference tags"))
        XCTAssertFalse(prompt.contains("Additional local app constraints"))
        XCTAssertFalse(prompt.contains("{{answerKeySection}}"))

        var noOptionalFields = assignment
        noOptionalFields.customInstructions = ""
        noOptionalFields.answerKeyText = ""
        noOptionalFields.exemplarText = ""
        noOptionalFields.formativeFocusText = ""
        noOptionalFields.curriculumReference = ""
        let promptWithoutOptionalFields = PromptBuilder.gradingPrompt(input: noOptionalFields.gradingInput)
        XCTAssertFalse(promptWithoutOptionalFields.contains("Custom teacher instructions:"))
        XCTAssertFalse(promptWithoutOptionalFields.contains("Answer key:"))
        XCTAssertFalse(promptWithoutOptionalFields.contains("Exemplar response:"))
        XCTAssertFalse(promptWithoutOptionalFields.contains("Formative focus:"))
        XCTAssertFalse(promptWithoutOptionalFields.contains("Curriculum reference:"))

        var tokenInjection = assignment
        tokenInjection.reviewedStudentText = "The student literally wrote {{answerKeySection}} in the answer."
        tokenInjection.answerKeyText = "Do not replace this into the student text."
        let tokenPrompt = PromptBuilder.gradingPrompt(input: tokenInjection.gradingInput)
        XCTAssertTrue(tokenPrompt.contains("The student literally wrote {{answerKeySection}} in the answer."))
    }

    func testReportsKeepStudentTeacherSeparationAndTeacherContext() {
        var assignment = AssignmentRecord(title: "Report", rubricText: "Criterion: 0-1 point", reviewedStudentText: "Student answer")
        assignment.customInstructions = "Teacher-only instruction."
        assignment.formativeFocusText = "Teacher-only formative focus."
        assignment.answerKeyText = "Teacher-only answer key."
        assignment.exemplarText = "Teacher-only exemplar."
        assignment.appliedTemplates = [AppliedTemplateRecord(templateID: "general-evidence-first", templateName: "Evidence first", templateKind: .teacherInstruction, insertionMode: .append)]
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [],
            totalScore: 1,
            maxScore: 1,
            studentFeedback: "Student-facing feedback.",
            privateTeacherNotes: "Private teacher note.",
            teacherEdited: true
        )
        assignment.exportRecords = [ExportRecord(exportKind: .teacherAuditMarkdown, contentFingerprint: "export-fingerprint", includesPrivateTeacherNotes: true, includesOriginalSources: false)]
        assignment.appendAuditEvent(.inputChanged, detail: "Review history detail.")

        let student = MarkdownReportBuilder.studentMarkdown(for: assignment)
        XCTAssertTrue(student.contains("Student-facing feedback."))
        XCTAssertFalse(student.contains("Teacher-only instruction."))
        XCTAssertFalse(student.contains("Teacher-only formative focus."))
        XCTAssertFalse(student.contains("Teacher-only answer key."))
        XCTAssertFalse(student.contains("Teacher-only exemplar."))
        XCTAssertFalse(student.contains("Private teacher note."))
        XCTAssertFalse(student.contains("export-fingerprint"))
        XCTAssertFalse(student.contains("Review history detail."))

        var draftOnly = AssignmentRecord(title: "Draft-only", rubricText: "Criterion: 0-1 point", reviewedStudentText: "Student answer")
        draftOnly.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(criterion: "Claim", rating: "Good", proposedPoints: 1, maxPoints: 1, evidence: ["Student answer"], explanation: "Met.", teacherReviewRequired: false)],
            totalScore: 1,
            maxScore: 1,
            studentFeedback: "Draft-only feedback.",
            teacherNotes: "Private draft teacher note.",
            uncertaintyFlags: []
        )
        let draftStudent = MarkdownReportBuilder.studentMarkdown(for: draftOnly)
        XCTAssertTrue(draftStudent.contains("No final teacher-approved grade is available"))
        XCTAssertFalse(draftStudent.contains("Draft-only feedback."))
        XCTAssertFalse(draftStudent.contains("Private draft teacher note."))
        XCTAssertTrue(MarkdownReportBuilder.teacherAuditMarkdown(for: draftOnly, generatedForExportKind: .teacherAuditMarkdown).contains("Draft-only feedback."))

        let teacher = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment, generatedForExportKind: .teacherAuditMarkdown)
        XCTAssertTrue(teacher.contains("Teacher-only instruction."))
        XCTAssertTrue(teacher.contains("Teacher-only formative focus."))
        XCTAssertTrue(teacher.contains("Teacher-only answer key."))
        XCTAssertTrue(teacher.contains("Teacher-only exemplar."))
        XCTAssertTrue(teacher.contains("Applied templates"))
        XCTAssertTrue(teacher.contains("general-evidence-first"))
        XCTAssertTrue(teacher.contains("Private teacher note."))
        XCTAssertTrue(teacher.contains("export-fingerprint"))
        XCTAssertTrue(teacher.contains("Review history detail."))
        XCTAssertTrue(teacher.contains(assignment.gradingPacketFingerprint))
        XCTAssertTrue(teacher.contains("Generated for export"))
    }

    func testProhibitedLabelsAreNotInUserFacingCatalogCopyOrSwiftUISource() throws {
        var visibleCopy: [String] = GradeDraftCopyCatalog.Labels.safe
        visibleCopy += RubricTemplateCatalog.builtIn.flatMap { [$0.name, $0.description, $0.rubricText, $0.customInstructions] }
        visibleCopy += TeacherInstructionTemplateCatalog.all.flatMap { [$0.name, $0.description, $0.text] }
        visibleCopy += AnswerKeyTemplateCatalog.all.flatMap { [$0.name, $0.description, $0.markdownTemplate] }
        visibleCopy += ExemplarTemplateCatalog.all.flatMap { [$0.name, $0.description, $0.markdownTemplate] }
        visibleCopy += FormativeFocusTemplateCatalog.all.flatMap { [$0.name, $0.description, $0.markdownTemplate] }
        visibleCopy += ExportWarningCatalog.all.flatMap { warning in
            [warning.name, warning.title, warning.body, warning.warningLine ?? "", warning.securityNote ?? "", warning.primaryButton, warning.secondaryButton, warning.finalButton ?? "", warning.acknowledgementText] + warning.checklist
        }
        visibleCopy += ReportTemplateCatalog.studentReportTemplates
        visibleCopy += ReportTemplateCatalog.teacherAuditReportTemplates
        visibleCopy.append(GradeDraftCopyCatalog.SourceOfTruth.canonicalPromptTemplate)

        try GradeDraftContentValidator.assertNoProhibitedLabels(in: visibleCopy)
        try assertNoProhibitedLabelsInSwiftUISource()
    }

    func testReportTemplateRulesPreserveStudentTeacherSeparation() {
        let exclusions = ReportTemplateCatalog.studentReportExclusionRules.joined(separator: "\n")
        XCTAssertTrue(exclusions.contains("private teacher notes"))
        XCTAssertTrue(exclusions.contains("raw model responses"))
        XCTAssertTrue(exclusions.contains("internal compliance flags"))

        let auditSections = ReportTemplateCatalog.teacherAuditRequiredSections.joined(separator: "\n")
        XCTAssertTrue(auditSections.contains("Answer key"))
        XCTAssertTrue(auditSections.contains("Exemplar"))
        XCTAssertTrue(auditSections.contains("Export records"))
        XCTAssertTrue(auditSections.contains("Audit events"))
    }

    private func assertNoProhibitedLabelsInSwiftUISource() throws {
        let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let gradeDraftURL = repoRoot.appendingPathComponent("GradeDraft")
        let excludedRelativePaths: Set<String> = [
            "GradeDraft/Content/GradeDraftCopyCatalog.swift"
        ]
        let prohibited = GradeDraftCopyCatalog.Labels.prohibited.map { $0.lowercased() }
        guard let enumerator = FileManager.default.enumerator(at: gradeDraftURL, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
            if excludedRelativePaths.contains(relative) { continue }
            let text = try String(contentsOf: url).lowercased()
            for label in prohibited where text.contains(label) {
                XCTFail("Prohibited label \(label) appears in \(relative)")
            }
        }
    }

    private func loadResourceCatalog() throws -> ResourceCatalog {
        let decoder = JSONDecoder()
        let url = try resourceCatalogURL()
        let data = try Data(contentsOf: url)
        return try decoder.decode(ResourceCatalog.self, from: data)
    }

    private func resourceCatalogURL() throws -> URL {
        if let bundled = Bundle(for: type(of: self)).url(forResource: "grade_draft_content_catalog", withExtension: "json") {
            return bundled
        }
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repoRoot.appendingPathComponent("GradeDraft/Resources/JSON/grade_draft_content_catalog.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "Missing grade_draft_content_catalog.json")
        return sourceURL
    }
}

private struct ResourceCatalog: Decodable {
    var rubricTemplates: [ResourceRubricTemplate]
    var teacherInstructionTemplates: [ResourceTeacherInstructionTemplate]
    var answerKeyTemplates: [ResourceAnswerKeyTemplate]
    var exemplarTemplates: [ResourceExemplarTemplate]
    var formativeFocusTemplates: [ResourceFormativeFocusTemplate]
    var exportWarnings: [ResourceExportWarning]
    var canonicalPromptTemplate: String
    var nonNegotiableRules: [String]
    var safeUILabels: [String]
    var prohibitedUILabels: [String]
    var ocrReviewStates: [String]
    var ocrConfidenceBands: [String]
    var teacherReviewWorkflowCopy: [String]
    var studentFeedbackRules: [String]
    var emptyStateCopy: [String]
    var regionalCurriculumSafeguards: [String]
    var inclusiveSafeguards: [String]
    var formativeModeSchema: [String]
    var futureModeGuardrails: [String]
    var exportFormatRequirements: [String]
    var acceptanceCriteria: [String]
}

private struct ResourceRubricTemplate: Decodable {
    var id: String
    var name: String
    var assignmentType: String
    var assessmentPurpose: String
    var description: String
    var rubricText: String
    var customInstructions: String
}

private struct ResourceTeacherInstructionTemplate: Decodable {
    var id: String
    var name: String
    var description: String
    var text: String
    var scope: String
    var priority: String
    var studentFacing: Bool
    var privateTeacherOnly: Bool
}

private struct ResourceAnswerKeyTemplate: Decodable {
    var id: String
    var name: String
    var assignmentTypes: [String]
    var description: String
    var markdownTemplate: String
}

private typealias ResourceExemplarTemplate = ResourceAnswerKeyTemplate
private typealias ResourceFormativeFocusTemplate = ResourceAnswerKeyTemplate

private struct ResourceExportWarning: Decodable {
    var id: String
    var name: String
    var title: String
    var body: String
    var warningLine: String?
    var securityNote: String?
    var checklist: [String]
    var primaryButton: String
    var secondaryButton: String
    var finalButton: String?
    var optionalCheckbox: String?
    var postPreviewConfirmation: String?
    var escalatedConfirmation: String?
    var defaultChoice: String?
    var acknowledgementText: String
    var requiresAcknowledgement: Bool
    var blocksStudentFacingExportByDefault: Bool
}
