import XCTest
@testable import GradeDraft

final class CurriculumCatalogProductionTests: XCTestCase {
    func testBundledAustralianCurriculumCatalogUsesBoundedIndexAndShards() throws {
        let shellURL = try Self.resourceURL(named: "curriculum_catalog_acara_v9")
        let indexURL = try Self.resourceURL(named: "curriculum_catalog_acara_v9_index")
        XCTAssertLessThan(try Data(contentsOf: shellURL).count, 100_000)

        let shellObject = try JSONSerialization.jsonObject(with: Data(contentsOf: shellURL)) as? [String: Any]
        XCTAssertEqual((shellObject?["items"] as? [Any])?.count, 0)

        let indexObject = try JSONSerialization.jsonObject(with: Data(contentsOf: indexURL)) as? [String: Any]
        let shards = try XCTUnwrap(indexObject?["shards"] as? [[String: Any]])
        let rows = try XCTUnwrap(indexObject?["rows"] as? [[String: Any]])
        XCTAssertGreaterThanOrEqual(shards.count, 18)
        XCTAssertGreaterThanOrEqual(rows.count, 5_000)

        for shard in shards {
            let fileName = try XCTUnwrap(shard["fileName"] as? String)
            let shardURL = try Self.resourceURL(named: fileName.replacingOccurrences(of: ".json", with: ""))
            XCTAssertLessThan(try Data(contentsOf: shardURL).count, 5_000_000)
        }
    }

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

    func testIndexedCatalogSearchMatchesCatalogFilter() throws {
        let catalog = try CurriculumCatalogService.loadBundledCatalog()
        let indexed = CurriculumCatalogService.searchItems(
            in: catalog,
            catalogKind: "learningArea",
            subject: "English",
            learningArea: "English",
            yearLevel: "Year 7",
            searchText: "evidence"
        )
        let direct = catalog.filtered(
            catalogKind: "learningArea",
            subject: "English",
            learningArea: "English",
            yearLevel: "Year 7",
            searchText: "evidence"
        )
        XCTAssertEqual(indexed.map(\.id), direct.map(\.id))
        XCTAssertEqual(
            CurriculumCatalogService.availableCatalogKinds(in: catalog),
            Array(Set(catalog.items.map { $0.catalogKind.isEmpty ? $0.itemType : $0.catalogKind }.filter { !$0.isEmpty }))
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        )
        XCTAssertTrue(CurriculumCatalogService.availableLearningAreas(in: catalog).contains("English"))
        XCTAssertTrue(CurriculumCatalogService.availableSubjects(in: catalog).contains("English"))
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

    private static func resourceURL(named name: String) throws -> URL {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "JSON/CurriculumShards"),
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "CurriculumShards"),
            Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "JSON"),
            Bundle.main.url(forResource: name, withExtension: "json")
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw GradeDraftError.persistenceFailed("Missing bundled test resource \(name).json")
        }
        return url
    }
}
