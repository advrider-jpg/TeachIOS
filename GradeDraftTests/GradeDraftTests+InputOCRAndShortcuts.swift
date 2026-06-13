import XCTest
import ZIPFoundation
@testable import GradeDraft

extension GradeDraftTests {
    func testOCRQualitySummaryFlagsLowConfidenceAndUnconfirmedText() {
        let lines = [
            OCRLine(text: "Strong line", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true),
            OCRLine(text: "Weak line", confidence: 0.42, boundingBox: .zero, teacherConfirmed: false)
        ]
        let summary = OCRQualitySummary(lines: lines)
        XCTAssertEqual(summary.lineCount, 2)
        XCTAssertEqual(summary.lowConfidenceLineCount, 1)
        XCTAssertEqual(summary.unconfirmedLineCount, 1)
        XCTAssertTrue(summary.requiresTeacherOCRReview)
    }

    func testScannedInputSetsOCRStatusNeedsReview() {
        // Creating an assignment with needsReview status simulates a scan
        let assignment = AssignmentRecord(
            title: "Scan test",
            reviewedStudentText: "Scanned text",
            ocrReviewStatus: .needsReview
        )
        XCTAssertTrue(assignment.requiresOCRReviewBeforeGrading, "Scan should require scanned text review")
        XCTAssertTrue(assignment.ocrReviewStatus.blocksGrading, "OCR needsReview blocks grading")
    }

    @MainActor
    func testMarkingOCRReviewedSetsStatusReviewed() {
        var assignment = AssignmentRecord(
            title: "scanned text review test",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Extracted text",
            ocrReviewStatus: .needsReview
        )
        // Simulate an OCR document being present
        assignment.ocrDocument = OCRDocument(
            pages: [OCRPage(
                pageIndex: 0,
                lines: [OCRLine(text: "Extracted text", confidence: 0.95, boundingBox: .zero, teacherConfirmed: true)]
            )]
        )

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canStartManualFinalReview, "Cannot start manual review before scanned text is reviewed")
        viewModel.markOCRReviewed()
        XCTAssertEqual(viewModel.assignment.ocrReviewStatus, .reviewed, "After marking reviewed, status should be reviewed")
        XCTAssertTrue(viewModel.canStartManualFinalReview, "Manual review should be available after scanned text is reviewed")
    }

    @MainActor
    func testDraftBlockedBeforeOCRReview() {
        let assignment = AssignmentRecord(
            title: "OCR blocked",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Text",
            ocrReviewStatus: .needsReview
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertFalse(viewModel.canDraftGrade, "Draft should be blocked before scanned text review")
    }

    // MARK: - Advanced feature completion regression tests

    func testConfirmStructuredImportSetsMode() {
        var assignment = AssignmentRecord(title: "Test", rubricText: "Old rubric")
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: "old-packet",
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Draft",
            teacherNotes: "Note",
            uncertaintyFlags: []
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: "old-packet",
            status: .approved,
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Final",
            privateTeacherNotes: "Note",
            teacherEdited: true
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        let preview = vm.previewMarkdownRubric("| Criterion | Max | Level | Points |\n|---|---|---|---|\n| Claim | 4 | Good | 4 |")
        vm.confirmMarkdownRubricImport(preview, useStructuredImport: true)
        XCTAssertEqual(vm.assignment.rubricImportMode, .structuredConfirmed)
        XCTAssertNotNil(vm.assignment.confirmedParsedRubric)
        XCTAssertNotNil(vm.assignment.latestDraft)
        XCTAssertNotNil(vm.assignment.finalReview)
        XCTAssertTrue(vm.assignment.latestDraftIsStale)
        XCTAssertTrue(vm.assignment.finalReviewIsStale)
    }

    @MainActor
    func testConfirmRawTextImportSetsRawMode() {
        let assignment = AssignmentRecord(title: "Test")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        let preview = vm.previewMarkdownRubric("Some rubric text without table")
        vm.confirmMarkdownRubricImport(preview, useStructuredImport: false)
        XCTAssertEqual(vm.assignment.rubricImportMode, .rawTextOnly)
        XCTAssertNil(vm.assignment.confirmedParsedRubric)
    }

    @MainActor
    func testRawTextImportDoesNotUseParsedCriteria() {
        let assignment = AssignmentRecord(title: "Test")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        let preview = vm.previewMarkdownRubric("| Criterion | Max | Level | Points |\n|---|---|---|---|\n| Claim | 4 | Good | 4 |")
        vm.confirmMarkdownRubricImport(preview, useStructuredImport: false)
        XCTAssertTrue(vm.assignment.parsedRubric.criteria.isEmpty, "Raw-text mode must produce empty parsed criteria")
    }

    @MainActor
    func testRejectLastOCRLineSetsDocumentAndAssignmentReviewed() {
        let line = OCRLine(text: "hello", confidence: 0.9, boundingBox: .zero, teacherConfirmed: false)
        let page = OCRPage(pageIndex: 0, lines: [line])
        var doc = OCRDocument(pages: [page])
        var assignment = AssignmentRecord(title: "OCR Test", ocrReviewStatus: .needsReview)
        assignment.ocrDocument = doc

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)

        vm.rejectOCRLine(pageID: page.id, lineID: line.id)

        XCTAssertEqual(vm.assignment.ocrReviewStatus, .reviewed, "Assignment scanned text status must be reviewed after last line resolved")
        XCTAssertEqual(vm.assignment.ocrDocument?.reviewStatus, .reviewed, "Document reviewStatus must match assignment")
        XCTAssertNotNil(vm.assignment.ocrDocument?.reviewedAt, "Document reviewedAt must be set")
        XCTAssertNotNil(vm.assignment.ocrReviewedAt, "Assignment ocrReviewedAt must be set")
    }

    @MainActor
    func testMarkOCRReviewedBlocksUnresolvedLowConfidenceLines() {
        let line = OCRLine(text: "maybe", confidence: OCRQualitySummary.lowConfidenceThreshold - 0.01, boundingBox: .zero, teacherConfirmed: false)
        let page = OCRPage(pageIndex: 0, lines: [line])
        var assignment = AssignmentRecord(title: "Low confidence", ocrReviewStatus: .needsReview)
        assignment.ocrDocument = OCRDocument(pages: [page])
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)

        vm.markOCRReviewed()

        XCTAssertEqual(vm.assignment.ocrReviewStatus, .needsReview)
        XCTAssertEqual(vm.assignment.ocrDocument?.reviewStatus, .needsReview)
        XCTAssertFalse(vm.assignment.ocrDocument?.pages.first?.lines.first?.teacherConfirmed ?? true)
        XCTAssertTrue(vm.errorMessage?.contains("Confirm, correct, or reject every scanned text line") == true)
    }

    @MainActor
    func testMarkOCRPageReviewedDoesNotBulkConfirmLowConfidenceLines() {
        let lowConfidence = OCRLine(text: "maybe", confidence: OCRQualitySummary.lowConfidenceThreshold - 0.01, boundingBox: .zero, teacherConfirmed: false)
        let highConfidence = OCRLine(text: "clear", confidence: 0.99, boundingBox: .zero, teacherConfirmed: false)
        let page = OCRPage(pageIndex: 0, lines: [lowConfidence, highConfidence])
        var assignment = AssignmentRecord(title: "Page review", ocrReviewStatus: .needsReview)
        assignment.ocrDocument = OCRDocument(pages: [page])
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)

        vm.markOCRPageReviewed(pageID: page.id)

        XCTAssertEqual(vm.assignment.ocrReviewStatus, .needsReview)
        XCTAssertFalse(vm.assignment.ocrDocument?.pages.first?.lines[0].teacherConfirmed ?? true)
        XCTAssertFalse(vm.assignment.ocrDocument?.pages.first?.lines[1].teacherConfirmed ?? true)
        XCTAssertTrue(vm.errorMessage?.contains("low-confidence OCR line") == true)
    }

    @MainActor
    func testEditOCRLineAfterReviewResetsToNeedsReview() {
        let line = OCRLine(text: "hello", confidence: 0.9, boundingBox: .zero, teacherConfirmed: true)
        let page = OCRPage(pageIndex: 0, lines: [line])
        var doc = OCRDocument(pages: [page])
        doc.reviewStatus = .reviewed
        doc.reviewedAt = Date()
        var assignment = AssignmentRecord(title: "OCR Edit", ocrReviewStatus: .reviewed)
        assignment.ocrDocument = doc
        assignment.ocrReviewedAt = Date()

        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)

        vm.updateOCRLine(pageID: page.id, lineID: line.id, correctedText: "world")

        XCTAssertEqual(vm.assignment.ocrReviewStatus, .needsReview, "Editing line must reset assignment to needsReview")
        XCTAssertEqual(vm.assignment.ocrDocument?.reviewStatus, .needsReview, "Editing line must reset document to needsReview")
        XCTAssertNil(vm.assignment.ocrDocument?.reviewedAt, "Document reviewedAt must be cleared after edit")
        XCTAssertNil(vm.assignment.ocrReviewedAt, "Assignment ocrReviewedAt must be cleared after edit")
    }

    @MainActor
    func testSanitizedLocalSourcePathAcceptsValidPath() {
        XCTAssertEqual(SourcePathSafety.sanitizedLocalSourcePath("Sources/abc123/page.png"), "Sources/abc123/page.png")
    }

    @MainActor
    func testSourceImageRejectsUnsafeRelativePath() {
        let assignment = AssignmentRecord(title: "Image Safety")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        let source = SourceInputRef(
            sourceType: .photo,
            localRelativePath: "Sources/assignment/../secret.png",
            fileName: "secret.png"
        )

        XCTAssertNil(vm.sourceImage(for: source))
    }

    func testSanitizedLocalSourcePathRejectsAbsolutePath() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("/absolute/path.png"))
    }

    func testSanitizedLocalSourcePathRejectsDotDot() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources/../escape.png"))
    }

    func testSanitizedLocalSourcePathRejectsDotDotAfterPrefix() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources/abc/../escape.png"))
    }

    func testSanitizedLocalSourcePathRejectsBackslash() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Sources\\bad.png"))
    }

    func testSanitizedLocalSourcePathRejectsNil() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath(nil))
    }

    func testSanitizedLocalSourcePathRejectsNonSourcesPrefix() {
        XCTAssertNil(SourcePathSafety.sanitizedLocalSourcePath("Documents/file.png"))
    }

}
