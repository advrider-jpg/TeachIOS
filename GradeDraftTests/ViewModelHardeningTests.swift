import XCTest
@testable import GradeDraft

// MARK: - ViewModel hardening tests

final class ViewModelHardeningTests: XCTestCase {
    @MainActor
    func testDuplicateCurrentAssignment() {
        let assignment = AssignmentRecord(
            title: "Original",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.duplicateCurrentAssignment()
        XCTAssertEqual(viewModel.assignments.count, 2)
        let duplicate = viewModel.assignments.first { $0.id != assignment.id }
        XCTAssertNotNil(duplicate)
        XCTAssertTrue(duplicate?.title.contains("Copy of") ?? false)
        XCTAssertNil(duplicate?.latestDraft)
        XCTAssertNil(duplicate?.finalReview)
    }

    @MainActor
    func testCreateAssignmentsFromRosterCSV() {
        let assignment = AssignmentRecord(
            title: "Template",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: ""
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.createAssignmentsFromRosterCSV("Alice\nBob\nCharlie")
        XCTAssertEqual(viewModel.assignments.count, 4, "Should have original + 3 roster assignments")
    }

    @MainActor
    func testCreateAssignmentsFromRosterCSVEmpty() {
        let assignment = AssignmentRecord(title: "Template")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.createAssignmentsFromRosterCSV("")
        XCTAssertNotNil(viewModel.errorMessage, "Empty roster should show error")
    }

    @MainActor
    func testUpdateOCRLineChangesReviewStatus() {
        var assignment = AssignmentRecord(
            title: "OCR test",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Extracted text",
            ocrReviewStatus: .reviewed
        )
        let page = OCRPage(pageIndex: 0, lines: [
            OCRLine(text: "Extracted text", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true)
        ])
        assignment.ocrDocument = OCRDocument(pages: [page], reviewStatus: .reviewed)
        let pageID = page.id
        let lineID = page.lines[0].id

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.updateOCRLine(pageID: pageID, lineID: lineID, correctedText: "Corrected text")
        XCTAssertEqual(viewModel.assignment.ocrReviewStatus, .needsReview, "Editing OCR should reset to needsReview")
    }

    @MainActor
    func testConfirmOCRLineSetsConfirmed() {
        var assignment = AssignmentRecord(
            title: "OCR confirm",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "text",
            ocrReviewStatus: .needsReview
        )
        let page = OCRPage(pageIndex: 0, lines: [
            OCRLine(text: "line", confidence: 0.95, boundingBox: .zero, teacherConfirmed: false)
        ])
        assignment.ocrDocument = OCRDocument(pages: [page])
        let pageID = page.id
        let lineID = page.lines[0].id

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.confirmOCRLine(pageID: pageID, lineID: lineID)
        XCTAssertEqual(viewModel.assignment.ocrReviewStatus, .reviewed, "Confirming the only line should set status to reviewed")
    }

    @MainActor
    func testRejectOCRLineRemovesLine() {
        var assignment = AssignmentRecord(
            title: "OCR reject",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "text",
            ocrReviewStatus: .needsReview
        )
        let page = OCRPage(pageIndex: 0, lines: [
            OCRLine(text: "line1", confidence: 0.95, boundingBox: .zero, teacherConfirmed: false),
            OCRLine(text: "line2", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true)
        ])
        assignment.ocrDocument = OCRDocument(pages: [page])
        let pageID = page.id
        let lineID = page.lines[0].id

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.rejectOCRLine(pageID: pageID, lineID: lineID)
        XCTAssertEqual(viewModel.assignment.ocrDocument?.pages[0].lines.count, 2, "Rejected line metadata should be preserved for traceability")
        XCTAssertTrue(viewModel.assignment.ocrDocument?.pages[0].lines[0].isRejected ?? false)
        XCTAssertFalse(viewModel.assignment.reviewedStudentText.contains("line1"), "Rejected line text should be excluded from reviewed text")
    }

    @MainActor
    func testApplyTemplateResetsGradingState() {
        var assignment = AssignmentRecord(
            title: "Template test",
            rubricText: "Old rubric: 0-2 points",
            reviewedStudentText: "text"
        )
        assignment.latestDraft = GradeDraftResult(
            studentResponseSummary: "Summary", criteria: [], totalScore: 0, maxScore: 0,
            studentFeedback: "", teacherNotes: "", uncertaintyFlags: []
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        let template = RubricTemplates.builtIn[0]
        viewModel.applyTemplate(template)
        XCTAssertNil(viewModel.assignment.latestDraft, "Applying template should clear draft")
        XCTAssertNil(viewModel.assignment.finalReview, "Applying template should clear final review")
        XCTAssertEqual(viewModel.assignment.rubricText, template.rubricText)
    }

    @MainActor
    func testApplyPastedStudentTextResetsOCRState() {
        var assignment = AssignmentRecord(
            title: "Paste test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Scanned text",
            ocrReviewStatus: .reviewed
        )
        assignment.ocrDocument = OCRDocument(pages: [
            OCRPage(pageIndex: 0, lines: [OCRLine(text: "OCR", confidence: 0.9, boundingBox: .zero)])
        ])

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.applyPastedStudentText("New pasted text")
        XCTAssertEqual(viewModel.assignment.reviewedStudentText, "New pasted text")
        XCTAssertNil(viewModel.assignment.ocrDocument, "Pasted text should clear OCR document")
        XCTAssertEqual(viewModel.assignment.ocrReviewStatus, .notNeeded)
    }

    @MainActor
    func testCannotApproveFinalReviewWithOutOfRangeScore() {
        var assignment = AssignmentRecord(
            title: "Out of range",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 5,
                maxPoints: 4,
                evidence: [],
                explanation: "",
                teacherApproved: true
            )],
            totalScore: 5,
            maxScore: 4,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: true
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canApproveFinalReview, "Out-of-range scores should block approval")
    }

    @MainActor
    func testCannotApproveFinalReviewWithEmptyCriteria() {
        var assignment = AssignmentRecord(
            title: "Empty criteria",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: false
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canApproveFinalReview, "Empty criteria should block approval")
    }

    @MainActor
    func testUpdateAssignmentMarksDraftStaleOnInputChange() {
        var assignment = AssignmentRecord(
            title: "Stale test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            studentResponseSummary: "", criteria: [], totalScore: 0, maxScore: 0,
            studentFeedback: "", teacherNotes: "", uncertaintyFlags: []
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.updateAssignment { record in
            record.rubricText = "Evidence: 0-2 points"
        }
        XCTAssertEqual(viewModel.assignment.latestDraft?.status, .stale, "Draft should be marked stale on input change")
    }

    @MainActor
    func testReadinessIssuesIncludesLocalAIUnavailable() {
        let assignment = AssignmentRecord(
            title: "Test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )
        XCTAssertTrue(viewModel.readinessIssues.contains { $0.lowercased().contains("unavailable") })
    }

    @MainActor
    func testExportStudentReportBlockedWhenNoFinalReview() {
        let assignment = AssignmentRecord(
            title: "Test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.exportStudentReport()
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.exportURL)
    }

    @MainActor
    func testStartFinalReviewFromLatestDraft() {
        var assignment = AssignmentRecord(
            title: "Draft review",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "text"
        )
        let draft = GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterionID: "c-1",
                criterion: "Claim",
                rating: "Good",
                proposedPoints: 3,
                maxPoints: 4,
                evidence: ["Quote"],
                explanation: "Met.",
                teacherReviewRequired: false
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good",
            teacherNotes: "Notes",
            uncertaintyFlags: []
        )
        assignment.latestDraft = draft

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.startFinalReviewFromLatestDraft()
        XCTAssertNotNil(viewModel.assignment.finalReview)
        XCTAssertEqual(viewModel.assignment.finalReview?.status, .inProgress)
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria.count, 1)
        XCTAssertFalse(viewModel.assignment.finalReview?.criteria[0].teacherApproved ?? true)
    }

    @MainActor
    func testNewAssignmentFromTemplate() {
        let store = InMemoryAssignmentStore()
        let viewModel = GradeDraftViewModel(assignments: [AssignmentRecord()], store: store)

        let template = RubricTemplates.builtIn[0]
        viewModel.newAssignment(from: template)
        XCTAssertTrue(viewModel.assignments.contains { $0.rubricText == template.rubricText })
    }

    @MainActor
    func testNewAssignmentWithoutTemplate() {
        let store = InMemoryAssignmentStore()
        let viewModel = GradeDraftViewModel(assignments: [AssignmentRecord()], store: store)

        let countBefore = viewModel.assignments.count
        viewModel.newAssignment()
        XCTAssertEqual(viewModel.assignments.count, countBefore + 1)
    }

    @MainActor
    func testExportCSVGradebook() {
        var assignment = AssignmentRecord(title: "CSV test", rubricText: "Claim: 0-4 points", reviewedStudentText: "text")
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 3,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 3, maxScore: 4, studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.exportCSVGradebook()
        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertEqual(viewModel.exportKind, .csvGradebook)
    }

    @MainActor
    func testSelectAssignment() {
        let assignmentA = AssignmentRecord(title: "A")
        let assignmentB = AssignmentRecord(title: "B")
        let store = InMemoryAssignmentStore(assignments: [assignmentA, assignmentB])
        let viewModel = GradeDraftViewModel(assignments: [assignmentA, assignmentB], store: store)

        XCTAssertTrue(viewModel.selectAssignment(assignmentB.id))
        XCTAssertEqual(viewModel.selectedAssignmentID, assignmentB.id)
        XCTAssertEqual(viewModel.assignment.title, "B")
    }

    @MainActor
    func testSelectAssignmentRejectsMissingIDWithoutFallingBackToWrongRecord() {
        let assignmentA = AssignmentRecord(title: "A")
        let assignmentB = AssignmentRecord(title: "B")
        let store = InMemoryAssignmentStore(assignments: [assignmentA, assignmentB])
        let viewModel = GradeDraftViewModel(assignments: [assignmentA, assignmentB], store: store)

        XCTAssertTrue(viewModel.selectAssignment(assignmentB.id))
        XCTAssertFalse(viewModel.selectAssignment(UUID()))
        viewModel.updateAssignment { $0.title = "Wrongly mutated" }

        XCTAssertNil(viewModel.selectedAssignmentID)
        XCTAssertEqual(viewModel.assignments.first(where: { $0.id == assignmentA.id })?.title, "A")
        XCTAssertEqual(viewModel.assignments.first(where: { $0.id == assignmentB.id })?.title, "B")
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func testInvalidSelectionBlocksCurrentAssignmentPreviewAndCleanupHelpers() {
        var assignment = AssignmentRecord(
            title: "Keep Me",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Reviewed text"
        )
        assignment.sourceInputs = [
            SourceInputRef(
                sourceType: .pastedText,
                localRelativePath: "Sources/\(assignment.id.uuidString)/page-1.png",
                teacherIncludedInExport: false
            )
        ]
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.selectAssignment(UUID()))
        let rubricPreview = viewModel.previewMarkdownRubric("Claim: 0-4 points")
        let rosterPreview = viewModel.previewRosterCSV("Alice\nBob")
        viewModel.clearCurrentStudentWork()

        XCTAssertFalse(rubricPreview.rawMarkdown.isEmpty)
        XCTAssertEqual(rosterPreview.students.count, 2)
        XCTAssertNil(viewModel.latestRubricPreview)
        XCTAssertNil(viewModel.rubricPreview(for: assignment.id))
        XCTAssertNil(viewModel.latestRosterPreview)
        XCTAssertTrue(viewModel.sourceFilesForCurrentAssignment().isEmpty)
        XCTAssertEqual(viewModel.assignments.first?.reviewedStudentText, "Reviewed text")
        XCTAssertEqual(viewModel.assignments.first?.sourceInputs.count, 1)
        XCTAssertNil(viewModel.selectedAssignmentID)
        XCTAssertTrue(viewModel.errorMessage?.contains("no saved assignment is selected") == true)
    }

    @MainActor
    func testInvalidSelectionClearsAIReadinessAndBlocksPacketPreview() {
        let assignment = AssignmentRecord(
            title: "AI packet",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Reviewed text",
            ocrReviewStatus: .notNeeded
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )
        viewModel.buildAIPacketPreview()
        XCTAssertNotNil(viewModel.aiReadinessReport)

        XCTAssertFalse(viewModel.selectAssignment(UUID()))
        viewModel.buildAIPacketPreview()

        XCTAssertNil(viewModel.aiReadinessReport)
        XCTAssertNil(viewModel.aiPacketPreview)
        XCTAssertNil(viewModel.draftGenerationTask)
        XCTAssertTrue(viewModel.errorMessage?.contains("no saved assignment is selected") == true)
    }

    @MainActor
    func testInvalidSelectionBlocksOCRAndFinalReviewActions() {
        var assignment = AssignmentRecord(
            title: "Review target",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Original OCR text",
            ocrReviewStatus: .needsReview
        )
        let line = OCRLine(text: "Original OCR text", confidence: 0.95, boundingBox: .zero)
        let page = OCRPage(pageIndex: 0, lines: [line])
        assignment.ocrDocument = OCRDocument(pages: [page])
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingSourceFingerprint,
            status: .inProgress,
            criteria: [
                FinalCriterionScore(
                    criterion: "Claim",
                    rating: "",
                    proposedPoints: 0,
                    finalPoints: 0,
                    maxPoints: 4,
                    evidence: [],
                    explanation: "",
                    teacherApproved: false
                )
            ],
            totalScore: 0,
            maxScore: 4,
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: false
        )
        let criterionID = assignment.finalReview?.criteria.first?.id
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.selectAssignment(UUID()))
        XCTAssertFalse(viewModel.updateOCRLine(pageID: page.id, lineID: line.id, correctedText: "Wrong mutation"))
        viewModel.confirmOCRLine(pageID: page.id, lineID: line.id)
        viewModel.markOCRReviewed()
        XCTAssertNil(viewModel.nextUnreviewedLine())
        viewModel.addManualEvidenceToFinalReview(criterionID: criterionID, quote: "Wrong evidence")
        if let criterionID {
            viewModel.acceptFinalReviewCriterion(id: criterionID)
            viewModel.clearEvidenceFromFinalReview(criterionID: criterionID)
        }
        viewModel.approveFinalReview()

        let saved = viewModel.assignments.first
        XCTAssertNil(viewModel.selectedAssignmentID)
        XCTAssertEqual(saved?.reviewedStudentText, "Original OCR text")
        XCTAssertEqual(saved?.ocrReviewStatus, .needsReview)
        XCTAssertFalse(saved?.ocrDocument?.pages.first?.lines.first?.teacherConfirmed ?? true)
        XCTAssertEqual(saved?.finalReview?.status, .inProgress)
        XCTAssertEqual(saved?.finalReview?.criteria.first?.evidence, [])
        XCTAssertFalse(saved?.finalReview?.criteria.first?.teacherApproved ?? true)
        XCTAssertTrue(viewModel.errorMessage?.contains("no saved assignment is selected") == true)
    }

    @MainActor
    func testInvalidSelectionBlocksTemplateRubricPasteAndCurriculumActions() {
        let assignment = AssignmentRecord(
            title: "Template target",
            rubricText: "Original rubric: 0-4 points",
            reviewedStudentText: "Original reviewed text"
        )
        let curriculumItem = CurriculumItem(
            id: "acara-test-item",
            source: "Australian Curriculum",
            version: "v9.0",
            learningArea: "English",
            subject: "English",
            yearLevel: "Year 7",
            itemType: "content description",
            code: "AC9E7LY01",
            title: "Test curriculum item",
            shortDescription: "A test item used for invalid-selection hardening.",
            sourceURL: "local-acara-test-source",
            isOfficial: true,
            isEditable: false
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.selectAssignment(UUID()))
        viewModel.applyTemplate(RubricTemplates.builtIn[0])
        viewModel.toggleAIConstraintTemplate(GradingConstraintTemplates.builtIn[0].id)
        viewModel.applyRecommendedAIConstraintTemplates()
        viewModel.clearAIConstraintTemplates()
        XCTAssertFalse(viewModel.applyPastedStudentText("Wrong pasted text"))
        viewModel.updateRubricText("Wrong rubric: 0-1 points")
        viewModel.mapCurriculumItemToCurrentAssignment(curriculumItem)
        viewModel.unmapCurriculumItemFromCurrentAssignment(curriculumItem)
        XCTAssertFalse(
            viewModel.appendExportRecord(
                kind: .studentMarkdown,
                contentFingerprint: "not-a-real-export",
                includesPrivateNotes: false,
                includesOriginalSources: false
            )
        )

        let saved = viewModel.assignments.first
        XCTAssertNil(viewModel.selectedAssignmentID)
        XCTAssertEqual(saved?.rubricText, "Original rubric: 0-4 points")
        XCTAssertEqual(saved?.reviewedStudentText, "Original reviewed text")
        XCTAssertEqual(saved?.selectedInstructionTemplateIDs, GradingConstraintTemplates.defaultSelectedIDs)
        XCTAssertEqual(saved?.curriculumMappings, [])
        XCTAssertEqual(saved?.curriculumReference, "")
        XCTAssertEqual(saved?.exportRecords.count, 0)
        XCTAssertTrue(viewModel.errorMessage?.contains("no saved assignment is selected") == true)
    }
}
