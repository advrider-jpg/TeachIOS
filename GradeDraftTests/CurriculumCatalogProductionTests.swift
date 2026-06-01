import XCTest
@testable import GradeDraft

final class CurriculumCatalogProductionTests: XCTestCase {
    func testBundledAustralianCurriculumCatalogIsNotSeedOnly() throws {
        let catalog = try CurriculumCatalogService.loadBundledCatalog()
        XCTAssertGreaterThanOrEqual(catalog.sources.count, 18)
        XCTAssertGreaterThanOrEqual(catalog.items.count, 5_000)
        XCTAssertFalse(catalog.items.contains { item in
            ["AC-ENG-Y7-RESPOND", "AC-MATH-Y6-REASON", "AC-HASS-Y8-SOURCE"].contains(item.id)
        })
        XCTAssertTrue(catalog.items.allSatisfy { $0.isOfficial && !$0.isEditable })
    }

    func testCatalogHasAttributionWarningsAndProvenance() throws {
        let catalog = try CurriculumCatalogService.loadBundledCatalog()
        XCTAssertTrue(catalog.attributionText.contains("ACARA"))
        XCTAssertTrue(catalog.nonEndorsementWarning.localizedCaseInsensitiveContains("does not claim"))
        XCTAssertTrue(catalog.icipWarning.localizedCaseInsensitiveContains("Indigenous Cultural and Intellectual Property"))
        XCTAssertTrue(catalog.sources.allSatisfy { !$0.sha256.isEmpty && !$0.jsonldURL.isEmpty })
        XCTAssertTrue(catalog.items.prefix(200).allSatisfy { !$0.externalURI.isEmpty && !$0.sourceAttribution.isEmpty })
    }

    @MainActor
    func testOnlyTeacherMappedCurriculumReferencesEnterGradingPacket() {
        let catalog = CurriculumCatalogService.localCatalog
        let item = catalog.items.first { $0.code.isEmpty == false }!
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
