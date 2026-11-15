import XCTest
@testable import GradeDraft

final class CurriculumCatalogProductionTests: XCTestCase {
    func testBundledAustralianCurriculumCatalogIsNotSeedOnly() async throws {
        let items = try await CurriculumCatalogService().search("evidence", limit: 50)
        XCTAssertEqual(items.count, 50)
        XCTAssertFalse(items.contains { item in
            ["AC-ENG-Y7-RESPOND", "AC-MATH-Y6-REASON", "AC-HASS-Y8-SOURCE"].contains(item.id)
        })
        XCTAssertTrue(items.allSatisfy { $0.isOfficial && !$0.isEditable })
    }

    func testSearchFindsKnownCodeAndLoadsItemsByID() async throws {
        let service = CurriculumCatalogService()
        let found = try await service.search("AC9E1LY01", limit: 50)
        let known = try XCTUnwrap(found.first { $0.code == "AC9E1LY01" })
        XCTAssertEqual(known.learningArea, "English")
        let byID = try await service.item(id: known.id)
        XCTAssertEqual(byID, known)
        let byIDs = try await service.items(ids: [known.id, "missing-id"])
        XCTAssertEqual(byIDs, [known])
    }

    func testCatalogHasAttributionWarningsAndProvenance() async throws {
        let items = try await CurriculumCatalogService().search("evidence", limit: 50)
        XCTAssertTrue(CurriculumCatalogService.sourceWarning.localizedCaseInsensitiveContains("does not claim"))
        XCTAssertTrue(CurriculumCatalogService.icipWarning.localizedCaseInsensitiveContains("Indigenous Cultural and Intellectual Property"))
        XCTAssertFalse(items.isEmpty)
        let sources = try await CurriculumCatalogService().sources()
        XCTAssertGreaterThanOrEqual(sources.count, 18)
        XCTAssertTrue(sources.allSatisfy { !$0.sha256.isEmpty && !$0.jsonldURL.isEmpty })
        XCTAssertTrue(items.allSatisfy {
            !$0.externalURI.isEmpty && !$0.licenseName.isEmpty && $0.sourceAttribution.contains("ACARA")
        })
    }

    /// A reference the teacher maps to the assignment must reach the grading packet; nothing else does.
    @MainActor
    func testOnlyTeacherMappedCurriculumReferencesEnterGradingPacket() async throws {
        let found = try await CurriculumCatalogService().search("evidence", limit: 1)
        let item = try XCTUnwrap(found.first)
        var fixture = try ExportFixtureFactory.baseAssignment(title: "Curriculum Packet")
        fixture.setup.assignment.curriculumReference = ""
        let database = try AppDatabase.inMemory()
        _ = try await database.restore(fixture.snapshot, resolutions: [:])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CurriculumPacket-\(UUID().uuidString)", isDirectory: true)
        let app = AppModel(
            openStorage: { AppModel.Storage(database: database, root: root) },
            services: PreviewFixtures.previewServices()
        )
        let model = AssignmentSetupModel(assignmentID: fixture.setup.id, app: app)
        let observing = Task { await model.observe() }
        defer { observing.cancel() }
        try await waitUntil { model.hasLoaded }

        func packetReference() async throws -> GradingPacketCurriculumReference? {
            let storedSetup = try await database.assignmentSetup(id: fixture.setup.id)
            let storedGraph = try await database.submission(id: fixture.submission.id)
            let confirmedIDs = try XCTUnwrap(storedSetup).curriculumMappings.filter(\.teacherConfirmed).map(\.curriculumItemID)
            let input = try GradingPacketBuilder.gradingInput(
                setup: try XCTUnwrap(storedSetup), graph: try XCTUnwrap(storedGraph), className: fixture.className,
                mappedItems: try await CurriculumCatalogService().items(ids: confirmedIDs)
            )
            return GradingPacketBuilder.packet(from: input).curriculumReference
        }

        let before = try await packetReference()
        XCTAssertNil(before)
        await model.addMapping(itemID: item.id)

        let after = try await packetReference()
        XCTAssertNotNil(after)
        XCTAssertTrue(after?.rawText.contains(item.code) == true)
    }

    func testPromptRulesForbidInventedCurriculumAlignment() {
        let instructions = PromptBuilder.gradingInstructionsText()
        XCTAssertTrue(instructions.localizedCaseInsensitiveContains("Do not invent"))
        XCTAssertTrue(instructions.localizedCaseInsensitiveContains("standard codes"))
        XCTAssertTrue(instructions.localizedCaseInsensitiveContains("jurisdiction compliance"))
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
