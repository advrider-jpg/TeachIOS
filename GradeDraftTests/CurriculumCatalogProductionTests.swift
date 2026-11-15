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

    @MainActor
    func testOnlyTeacherMappedCurriculumReferencesEnterGradingPacket() async throws {
        let item = try XCTUnwrap(try await CurriculumCatalogService().search("evidence", limit: 1).first)
        var assignment = AssignmentRecord(
            title: "Curriculum Packet",
            rubricText: "Evidence: 0-4 points",
            reviewedStudentText: "The student uses evidence.",
            ocrReviewStatus: .reviewed
        )
        assignment.curriculumReference = ""
        assignment.curriculumMappings = []
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))

        XCTAssertNil(viewModel.assignment.gradingPacket.curriculumReference)
        viewModel.mapCurriculumItemToCurrentAssignment(item)

        let packetReference = viewModel.assignment.gradingPacket.curriculumReference
        XCTAssertNotNil(packetReference)
        XCTAssertTrue(packetReference?.rawText.contains(item.code) == true)
        XCTAssertTrue(packetReference?.mappings.contains(where: { $0.contains(item.id) }) == true)
    }

    func testPromptRulesForbidInventedCurriculumAlignment() {
        let input = AssignmentRecord(
            title: "Prompt Rules",
            rubricText: "Evidence: 0-4 points",
            reviewedStudentText: "The student uses evidence.",
            ocrReviewStatus: .reviewed
        ).gradingInput
        let instructions = PromptBuilder.gradingInstructionsText(input: input)
        XCTAssertTrue(instructions.localizedCaseInsensitiveContains("Do not invent"))
        XCTAssertTrue(instructions.localizedCaseInsensitiveContains("standard codes"))
        XCTAssertTrue(instructions.localizedCaseInsensitiveContains("jurisdiction compliance"))
    }
}
