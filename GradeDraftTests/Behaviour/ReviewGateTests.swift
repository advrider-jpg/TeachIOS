import Foundation
import Testing
@testable import GradeDraft

struct ReviewGateTests {
    // T3
    @Test func lowConfidenceAndTextLayerLinesBlockReviewed() async throws {
        let database = try AppDatabase.inMemory()
        let classGroup = ClassGroup(name: "7B")
        try await database.save(classGroup)
        try await database.save(Student(displayName: "Ada Lovelace", localIdentifier: "A1"), enrolledIn: classGroup.id)
        let assignment = Assignment(classGroupID: classGroup.id, title: "Fraction essay", rubricText: "Ideas: 10 points")
        try await database.createAssignment(assignment)
        let submissionID = try #require(try await database.submissionSummaries(assignmentID: assignment.id).first).id

        let visionLine = OCRLine(
            text: "Fractoins are parts of a whole.", confidence: 0.5,
            boundingBox: NormalizedRect(x: 0.1, y: 0.8, width: 0.8, height: 0.05), origin: .visionOCR
        )
        let textLayerLine = OCRLine(
            text: "A half is bigger than a quarter.", confidence: nil,
            boundingBox: NormalizedRect(x: 0.1, y: 0.7, width: 0.8, height: 0.05), origin: .pdfTextLayer
        )
        let ocr = OCRDocument(pages: [OCRPage(pageIndex: 0, lines: [visionLine, textLayerLine])])
        _ = try await database.replaceInput(submissionID: submissionID, kind: .scanned, pastedText: nil, sources: [], ocr: ocr)

        func loadedOCR() async throws -> OCRDocument {
            try #require(try await database.submission(id: submissionID)?.ocr)
        }
        func line(_ id: UUID) async throws -> OCRLine {
            try #require(try await loadedOCR().allLines.first { $0.id == id })
        }

        func expectReviewedRefused(unresolved: Int) async {
            let error = await #expect(throws: AppDatabaseError.self) {
                try await database.setOCRReviewStatus(.reviewed, submissionID: submissionID)
            }
            guard case .writeFailed(let underlying)? = error else {
                Issue.record("Expected writeFailed, got \(String(describing: error))")
                return
            }
            #expect(underlying as? OCRReviewIncompleteError == OCRReviewIncompleteError(unresolvedLineCount: unresolved))
            #expect((try? await loadedOCR().reviewStatus) != .reviewed)
        }

        // "Confirm all" (as SubmissionSession.confirmAllConfidentLines applies it) confirms neither line.
        let before = try await loadedOCR()
        #expect(before.unresolvedLineCount == 2)
        let confirmed = before.markingAllLinesConfirmed()
        for changed in confirmed.allLines where changed != before.allLines.first(where: { $0.id == changed.id }) {
            try await database.updateOCRLine(changed, submissionID: submissionID)
        }
        #expect(try await line(visionLine.id).teacherConfirmed == false)
        #expect(try await line(textLayerLine.id).teacherConfirmed == false)
        #expect(try await loadedOCR().unresolvedLineCount == 2)

        // Marking reviewed is refused, and the scanned text stays unreviewed.
        await expectReviewedRefused(unresolved: 2)

        // Confirming only the low-confidence line is still not enough.
        var confirmedVision = try await line(visionLine.id)
        confirmedVision.teacherConfirmed = true
        try await database.updateOCRLine(confirmedVision, submissionID: submissionID)
        await expectReviewedRefused(unresolved: 1)

        // Rejecting the text-layer line resolves it; marking reviewed now succeeds.
        var rejectedTextLayer = try await line(textLayerLine.id)
        rejectedTextLayer.isRejected = true
        try await database.updateOCRLine(rejectedTextLayer, submissionID: submissionID)
        try await database.setOCRReviewStatus(.reviewed, submissionID: submissionID)

        let after = try await loadedOCR()
        #expect(after.reviewStatus == .reviewed)
        #expect(after.reviewedAt != nil)
        #expect(after.combinedText == "Fractoins are parts of a whole.")
    }
}
