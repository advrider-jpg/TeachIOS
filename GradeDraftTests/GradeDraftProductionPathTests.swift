import XCTest
@testable import GradeDraft

final class GradeDraftProductionPathTests: XCTestCase {
    func testOCRIncompleteStateBlocksDraftAndManualReviewPaths() throws {
        var fixture = try ExportFixtureFactory.baseAssignment(title: "Scanned Work")
        fixture.submission.submission.inputKind = .scanned
        fixture.submission.submission.pastedText = nil
        fixture.submission.ocr = OCRDocument(
            pages: [OCRPage(pageIndex: 0, lines: [
                OCRLine(text: "OCR text pending teacher review.", confidence: 0.61, boundingBox: .zero, origin: .visionOCR)
            ])],
            reviewStatus: .needsReview
        )

        let readiness = AssignmentReadiness(setup: fixture.setup, submission: fixture.submission, aiStatus: .available, aiReport: nil)

        XCTAssertFalse(readiness.canDraft)
        XCTAssertFalse(readiness.canStartFinalReview)
        XCTAssertFalse(readiness.isScannedTextReviewed)
    }

    func testUnavailableLocalAIHasNoCloudFallback() async throws {
        let service = UnavailableLocalGradingService()
        if case .unavailable(let message) = service.localAIStatus {
            XCTAssertTrue(message.localizedCaseInsensitiveContains("cloud model"))
        } else {
            XCTFail("Unavailable local grading service must report an unavailable state.")
        }

        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment(title: "Local AI", student: "Elliot")
        let input = try GradingPacketBuilder.gradingInput(setup: fixture.setup, graph: fixture.submission, className: fixture.className, mappedItems: [])
        do {
            _ = try await service.draftGrade(input: input)
            XCTFail("Unavailable local grading service must throw instead of returning a draft.")
        } catch {
            XCTAssertTrue(error.localizedDescription.localizedCaseInsensitiveContains("cloud model"))
        }
    }

    @MainActor
    func testStructuredRubricImportCreatesTeacherConfirmedStateAndStalesReviews() async throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment(title: "Rubric Import", student: "Drew")
        let database = try AppDatabase.inMemory()
        _ = try await database.restore(fixture.snapshot, resolutions: [:])
        var services = PreviewFixtures.previewServices()
        services.grading = UnavailableLocalGradingService()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RubricImport-\(UUID().uuidString)", isDirectory: true)
        let app = AppModel(openStorage: { AppModel.Storage(database: database, root: root) }, services: services)
        let model = AssignmentSetupModel(assignmentID: fixture.setup.id, app: app)
        let observing = Task { await model.observe() }
        defer { observing.cancel() }
        try await waitUntil { model.hasLoaded }

        model.previewRubric(text: """
        | Criterion | Max | Level | Points |
        |---|---:|---|---:|
        | Claim | 4 | Strong | 4 |
        """)
        await model.confirmRubricPreview(structured: true)

        let storedSetup = try await database.assignmentSetup(id: fixture.setup.id)
        let setup = try XCTUnwrap(storedSetup)
        let storedGraph = try await database.submission(id: fixture.submission.id)
        let graph = try XCTUnwrap(storedGraph)
        XCTAssertEqual(setup.assignment.rubricImportMode, .structuredConfirmed)
        XCTAssertFalse(setup.parsedRubric.criteria.isEmpty)
        XCTAssertTrue(try graph.draftIsStale(setup: setup))
        XCTAssertTrue(try graph.finalReviewIsStale(setup: setup))
    }

    func testStorageDirectoryIsMarkedExcludedFromBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftProtection-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }

        try LocalDataProtection.prepareSensitiveDirectory(root)

        let excluded = try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        XCTAssertEqual(excluded, true)
    }
}

private struct HarnessTimeout: Error {}

@MainActor
private func waitUntil(timeout: Duration = .seconds(5), _ condition: @MainActor () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        guard clock.now < deadline else { throw HarnessTimeout() }
        try await Task.sleep(for: .milliseconds(20))
    }
}
