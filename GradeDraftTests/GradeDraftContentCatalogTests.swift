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
        let original = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Example", rubricText: "Criterion: 0-1 point"))
        let student = Student(displayName: "Student")
        let graph = SubmissionGraph(
            submission: Submission(assignmentID: original.id, studentID: student.id, inputKind: .pasted, pastedText: "Student answer"),
            student: student
        )
        let initialFingerprint = try original.setupFingerprint

        let instruction = try XCTUnwrap(TeacherInstructionTemplateCatalog.template(id: "general-evidence-first"))
        let withInstruction = GradeDraftTemplateApplication.appendingInstructionTemplate(instruction, to: original)
        XCTAssertTrue(withInstruction.assignment.customInstructions.contains(instruction.text))
        XCTAssertTrue(withInstruction.assignment.customInstructions.contains("GradeDraftTemplate:teacherInstruction:general-evidence-first"))
        let packet = GradingPacketBuilder.packet(from: try GradingPacketBuilder.gradingInput(setup: withInstruction, graph: graph, className: "6A", mappedItems: []))
        XCTAssertTrue(packet.teacherInstructions.first?.text.contains("GradeDraftTemplate") == false)
        XCTAssertEqual(withInstruction.appliedTemplates.last?.templateID, instruction.id)
        XCTAssertNotEqual(try withInstruction.setupFingerprint, initialFingerprint)

        let duplicateInstruction = GradeDraftTemplateApplication.appendingInstructionTemplate(instruction, to: withInstruction)
        XCTAssertEqual(duplicateInstruction.assignment.customInstructions, withInstruction.assignment.customInstructions)
        XCTAssertEqual(duplicateInstruction.appliedTemplates.count, withInstruction.appliedTemplates.count)

        let answerKey = try XCTUnwrap(AnswerKeyTemplateCatalog.template(id: "short-answer-answer-key"))
        let withAnswerKey = GradeDraftTemplateApplication.insertingAnswerKeyTemplate(answerKey, to: withInstruction)
        XCTAssertTrue(withAnswerKey.assignment.answerKeyText.contains("Full-credit answer"))
        XCTAssertEqual(withAnswerKey.appliedTemplates.last?.templateKind, .answerKey)
        XCTAssertNotEqual(try withAnswerKey.setupFingerprint, try withInstruction.setupFingerprint)

        let exemplar = try XCTUnwrap(ExemplarTemplateCatalog.template(id: "paragraph-essay-exemplar"))
        let withExemplar = GradeDraftTemplateApplication.insertingExemplarTemplate(exemplar, to: withAnswerKey)
        XCTAssertTrue(withExemplar.assignment.exemplarText.contains(exemplar.markdownTemplate))
        XCTAssertEqual(withExemplar.appliedTemplates.last?.templateKind, .exemplar)
        XCTAssertNotEqual(try withExemplar.setupFingerprint, try withAnswerKey.setupFingerprint)

        let formative = try XCTUnwrap(FormativeFocusTemplateCatalog.template(id: "formative-focus"))
        let withFormative = GradeDraftTemplateApplication.insertingFormativeFocusTemplate(formative, to: withExemplar)
        XCTAssertTrue(withFormative.assignment.formativeFocusText.contains(formative.markdownTemplate))
        XCTAssertFalse(withFormative.assignment.customInstructions.contains(formative.markdownTemplate))
        XCTAssertEqual(withFormative.assignment.assessmentPurpose, .formative)
        XCTAssertEqual(withFormative.appliedTemplates.last?.templateKind, .formativeFocus)
        XCTAssertNotEqual(try withFormative.setupFingerprint, try withExemplar.setupFingerprint)
    }

    func testTemplateApplicationMarksExistingDraftAndFinalReviewStaleAndAuditsBoth() async throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment()
        let database = try AppDatabase.inMemory()
        _ = try await database.restore(fixture.snapshot, resolutions: [:])
        let startingFingerprint = try fixture.currentFingerprint()
        let template = try XCTUnwrap(TeacherInstructionTemplateCatalog.template(id: "general-evidence-first"))

        let stored = try await database.assignmentSetup(id: fixture.setup.id)
        let setup = try XCTUnwrap(stored)
        try await database.saveSetup(GradeDraftTemplateApplication.appendingInstructionTemplate(template, to: setup))

        let updatedStored = try await database.assignmentSetup(id: fixture.setup.id)
        let updatedSetup = try XCTUnwrap(updatedStored)
        let graphStored = try await database.submission(id: fixture.submission.id)
        let graph = try XCTUnwrap(graphStored)
        XCTAssertTrue(try graph.draftIsStale(setup: updatedSetup))
        XCTAssertTrue(try graph.finalReviewIsStale(setup: updatedSetup))
        XCTAssertTrue(graph.audit.contains { $0.eventType == .draftMarkedStale })
        XCTAssertTrue(graph.audit.contains { $0.eventType == .finalReviewMarkedStale })
        XCTAssertNotEqual(try graph.packetFingerprint(setup: updatedSetup), startingFingerprint)
    }

    func testRubricTemplateApplicationPreservesExistingPublicAPI() throws {
        let template = try XCTUnwrap(RubricTemplateCatalog.template(id: "formative-exit-ticket-8pt"))
        var assignment = Assignment(classGroupID: UUID(), title: "Exit ticket", assessmentPurpose: .summative)
        assignment.rubricImportMode = .structuredConfirmed
        assignment.confirmedRubric = ParsedRubric(criteria: [], issues: [], groups: [])
        let updated = GradeDraftTemplateApplication.applyingRubricTemplate(template, to: AssignmentSetup(assignment: assignment)).assignment
        XCTAssertEqual(updated.assignmentType, .shortAnswer)
        XCTAssertEqual(updated.assessmentPurpose, .formative)
        XCTAssertTrue(updated.rubricText.contains("Shows current understanding"))
        XCTAssertEqual(updated.rubricImportMode, .automatic)
        XCTAssertNil(updated.confirmedRubric)
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
        XCTAssertEqual(ExportWarningCatalog.primaryWarning(for: .fullBackupArchive)?.id, "zip-archive-warning")

        let teacherPDFWarnings = ExportWarningCatalog.warnings(for: .teacherAuditPDF)
        XCTAssertEqual(teacherPDFWarnings.map(\.id), ["teacher-only-record-warning", "pdf-warning"])
        XCTAssertNotNil(teacherPDFWarnings.first { $0.id == "pdf-warning" }?.postPreviewConfirmation)
        XCTAssertEqual(ExportWarningCatalog.warnings(for: .fullBackupArchive).map(\.id), ["zip-archive-warning", "json-backup-warning"])
        XCTAssertNotNil(ExportWarningCatalog.warning(id: "delete-local-data-warning")?.escalatedConfirmation)
        XCTAssertEqual(ExportWarningCatalog.clearStudentWorkWarning.id, "clear-student-work-warning")

        for warning in ExportWarningCatalog.all {
            XCTAssertFalse(warning.primaryButton.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(warning.secondaryButton.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(warning.requiresAcknowledgement)
        }
    }

    func testReportsKeepStudentTeacherSeparationAndTeacherContext() throws {
        var fixture = try ExportFixtureFactory.baseAssignment(title: "Report")
        fixture.setup.assignment.rubricText = "Criterion: 0-1 point"
        fixture.setup.assignment.customInstructions = "Teacher-only instruction."
        fixture.setup.assignment.formativeFocusText = "Teacher-only formative focus."
        fixture.setup.assignment.answerKeyText = "Teacher-only answer key."
        fixture.setup.assignment.exemplarText = "Teacher-only exemplar."
        fixture.setup.appliedTemplates = [AppliedTemplateRecord(
            assignmentID: fixture.setup.id, templateID: "general-evidence-first", templateName: "Evidence first",
            templateKind: .teacherInstruction, insertionMode: .append
        )]
        let fingerprint = try fixture.currentFingerprint()
        fixture.submission.finalReview = FinalGradeReview(
            finalizedAt: Date(timeIntervalSince1970: 1_700_000_000),
            packetFingerprint: fingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterionID: fixture.criterionID, rating: "", proposedPoints: 1, finalPoints: 1,
                explanation: "", teacherApproved: true
            )],
            studentFeedback: "Student-facing feedback.",
            privateTeacherNotes: "Private teacher note.",
            teacherEdited: true
        )
        fixture.submission.exports = [ExportRecord(
            assignmentID: fixture.setup.id, submissionID: fixture.submission.submission.id, kind: .teacherAuditMarkdown,
            contentSHA256: "export-fingerprint", includesPrivateTeacherNotes: true, includesOriginalSources: false
        )]
        fixture.submission.audit = [AuditEvent(
            assignmentID: fixture.setup.id, submissionID: fixture.submission.submission.id,
            eventType: .inputChanged, detail: "Review history detail."
        )]

        let student = try fixture.studentReportMarkdown()
        XCTAssertTrue(student.contains("Student-facing feedback."))
        XCTAssertFalse(student.contains("Teacher-only instruction."))
        XCTAssertFalse(student.contains("Teacher-only formative focus."))
        XCTAssertFalse(student.contains("Teacher-only answer key."))
        XCTAssertFalse(student.contains("Teacher-only exemplar."))
        XCTAssertFalse(student.contains("Private teacher note."))
        XCTAssertFalse(student.contains("export-fingerprint"))
        XCTAssertFalse(student.contains("Review history detail."))

        var draftOnly = try ExportFixtureFactory.baseAssignment(title: "Draft-only")
        draftOnly.submission.draft = GradeDraftResult(
            packetFingerprint: try draftOnly.currentFingerprint(),
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterionID: draftOnly.criterionID, rating: "Good", proposedPoints: 1,
                evidenceQuotes: ["Student answer"], explanation: "Met.", teacherReviewRequired: false
            )],
            studentFeedback: "Draft-only feedback.",
            teacherNotes: "Private draft teacher note.",
            uncertaintyFlags: []
        )
        XCTAssertThrowsError(
            try ReportBuilder.studentReport(setup: draftOnly.setup, submission: draftOnly.submission, generatedAt: Date(timeIntervalSince1970: 0))
        ) { error in
            XCTAssertEqual(error as? ReportError, .notApproved)
        }
        XCTAssertTrue(draftOnly.teacherRecordMarkdown().contains("Draft-only feedback."))

        let teacher = fixture.teacherRecordMarkdown()
        XCTAssertTrue(teacher.contains("Teacher-only instruction."))
        XCTAssertTrue(teacher.contains("Teacher-only formative focus."))
        XCTAssertTrue(teacher.contains("Teacher-only answer key."))
        XCTAssertTrue(teacher.contains("Teacher-only exemplar."))
        XCTAssertTrue(teacher.contains("Applied templates"))
        XCTAssertTrue(teacher.contains("general-evidence-first"))
        XCTAssertTrue(teacher.contains("Private teacher note."))
        XCTAssertTrue(teacher.contains("export-fingerprint"))
        XCTAssertTrue(teacher.contains("Review history detail."))
        XCTAssertTrue(teacher.contains(fingerprint))
        XCTAssertTrue(teacher.contains("Report generated"))
    }

    func testProhibitedLabelsAreNotInUserFacingCatalogCopy() throws {
        var visibleCopy: [String] = GradeDraftCopyCatalog.Labels.safe
        visibleCopy += RubricTemplateCatalog.builtIn.flatMap { [$0.name, $0.description, $0.rubricText, $0.customInstructions] }
        visibleCopy += TeacherInstructionTemplateCatalog.all.flatMap { [$0.name, $0.description, $0.text] }
        visibleCopy += AnswerKeyTemplateCatalog.all.flatMap { [$0.name, $0.description, $0.markdownTemplate] }
        visibleCopy += ExemplarTemplateCatalog.all.flatMap { [$0.name, $0.description, $0.markdownTemplate] }
        visibleCopy += FormativeFocusTemplateCatalog.all.flatMap { [$0.name, $0.description, $0.markdownTemplate] }
        visibleCopy += ExportWarningCatalog.all.flatMap { warning in
            [warning.name, warning.title, warning.body, warning.warningLine ?? "", warning.securityNote ?? "", warning.primaryButton, warning.secondaryButton, warning.finalButton ?? "", warning.acknowledgementText] + warning.checklist
        }

        try GradeDraftContentValidator.assertNoProhibitedLabels(in: visibleCopy)
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
