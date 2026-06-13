import XCTest
import ZIPFoundation
@testable import GradeDraft

extension GradeDraftTests {
    func testLocalAIUnavailableMessageContainsNoCloudFallback() {
        let service = UnavailableLocalGradingService()
        if case .unavailable(let message) = service.localAIStatus {
            XCTAssertTrue(message.lowercased().contains("cloud") || message.lowercased().contains("not"),
                          "Unavailable message should clarify no cloud fallback: \(message)")
            let prohibitedPhrases = ["will upload", "try again later with cloud", "cloud backup grading"]
            for phrase in prohibitedPhrases {
                XCTAssertFalse(message.lowercased().contains(phrase),
                               "Unavailable message must not imply cloud fallback: '\(phrase)' found in: \(message)")
            }
        } else {
            XCTFail("UnavailableLocalGradingService must report unavailable status")
        }
    }

    // MARK: - Manual final review tests

    @MainActor
    func testAIReadinessLaunchRequestPreparesPreviewWithoutDrafting() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student wrote a claim.",
            ocrReviewStatus: .notNeeded
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.handleLaunchRequest(AppLaunchRequest(
            destination: .aiReadiness,
            assignmentID: assignment.id,
            action: .preparePacketPreview
        ))

        XCTAssertEqual(viewModel.aiReadinessReport?.assignmentID, assignment.id)
        XCTAssertEqual(viewModel.aiPacketPreview?.assignmentID, assignment.id)
        XCTAssertNil(viewModel.assignment.latestDraft)
        XCTAssertNil(viewModel.assignment.finalReview)
    }

    @MainActor
    func testCancellingLocalDraftDoesNotSaveDraft() async throws {
        let assignment = AssignmentRecord(
            title: "Cancelable draft",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: SlowCancellableGradingService(),
            store: store
        )

        viewModel.confirmAndDraftGrade()
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(viewModel.canCancelDraftGeneration)
        XCTAssertEqual(viewModel.aiGenerationProgress.stage, .requestingModel)

        viewModel.cancelDraftGeneration()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.aiGenerationProgress.stage, .cancelled)
        XCTAssertNil(viewModel.assignment.latestDraft)
        XCTAssertFalse(viewModel.isWorking)
        XCTAssertEqual(viewModel.statusMessage, "Local draft cancelled. No draft was saved.")
    }

    @MainActor
    func testCompletedLocalDraftProgressRequiresSavedDraft() async throws {
        let assignment = AssignmentRecord(
            title: "Fast draft",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text"
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: ImmediateProgressGradingService(),
            store: store
        )

        viewModel.confirmAndDraftGrade()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.aiGenerationProgress.stage, .completed)
        XCTAssertNotNil(viewModel.assignment.latestDraft)
        XCTAssertFalse(viewModel.isWorking)
        XCTAssertEqual(viewModel.assignment.auditEvents.last?.eventType, .draftGenerated)
    }

    @MainActor
    func testLocalAIUnavailableDisablesDraftButton() {
        let assignment = AssignmentRecord(
            title: "Short answer",
            rubricText: "Claim: 0-2 points",
            reviewedStudentText: "Student text."
        )
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            gradingService: UnavailableLocalGradingService(),
            store: store
        )
        XCTAssertFalse(viewModel.canDraftGrade, "AI draft button should be disabled when local AI unavailable")
    }

}
