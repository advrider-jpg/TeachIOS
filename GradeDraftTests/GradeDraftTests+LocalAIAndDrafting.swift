import XCTest
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

    // MARK: - AI draft screen and drafting

    func testPreparingTheAIDraftScreenBuildsPreviewWithoutDrafting() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student wrote a claim.")
        let session = try await openSession(app, seeded.submissionID)

        await session.prepareAIDraft()

        XCTAssertEqual(session.aiReadiness?.assignmentID, seeded.assignmentID)
        XCTAssertEqual(session.packetPreview?.assignmentID, seeded.assignmentID)
        let graph = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertNil(graph?.draft)
        XCTAssertNil(graph?.finalReview)
    }

    func testCancellingLocalDraftDoesNotSaveDraft() async throws {
        let app = try TestApp.make(grading: SlowCancellableGradingService())
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text")
        let session = try await openSession(app, seeded.submissionID)
        await session.prepareAIDraft()

        session.startDraft()
        try await waitForCondition { session.generationProgress.stage == .requestingModel }
        XCTAssertEqual(session.runningWork, .draft)
        XCTAssertTrue(session.generationProgress.canCancel)

        session.cancelDraft()
        await app.backgroundWork.waitUntilFinished(submissionID: seeded.submissionID)

        let graph = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertNil(graph?.draft)
        XCTAssertNil(session.runningWork)
        XCTAssertNil(session.workFailure, "A cancelled draft is not a failure")
    }

    /// Changed expectation: the session no longer sets a "completed" progress stage or a status message; a
    /// finished draft is shown by the saved draft itself (and its audit event), which is what this checks.
    func testCompletedLocalDraftIsSavedAndRecorded() async throws {
        let app = try TestApp.make(grading: ImmediateProgressGradingService())
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text")
        let session = try await openSession(app, seeded.submissionID)
        await session.prepareAIDraft()

        session.startDraft()
        await app.backgroundWork.waitUntilFinished(submissionID: seeded.submissionID)

        let graphSaved = try await app.requireDatabase().submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        XCTAssertNotNil(graph.draft)
        let fingerprint = try await TestApp.fingerprint(app, seeded)
        XCTAssertEqual(graph.draft?.packetFingerprint, fingerprint)
        XCTAssertNil(session.runningWork)
        XCTAssertNil(session.workFailure)
        XCTAssertEqual(graph.audit.last?.eventType, .draftGenerated)
    }

    func testLocalAIUnavailableDisablesDraftButton() async throws {
        let app = try TestApp.make(grading: UnavailableLocalGradingService())
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text.")
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canDraft, false, "AI draft button should be disabled when local AI unavailable")
    }
}
