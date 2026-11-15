import Foundation
import FoundationModels
import Testing
@testable import GradeDraft

/// Runs the real on-device model. These tests run only on a device where Apple's on-device model is available;
/// elsewhere they are reported as skipped, not passed.
struct OnDeviceModelTests {
    @Test(.enabled(if: OnDeviceModel.isUsable))
    func onDeviceModelDraftsEvaluationFixtures() async throws {
        let cases = try TestFixtures.evaluationCases()
        try #require(!cases.isEmpty)
        let runner = AIEvaluationRunner(gradingService: FoundationModelGradingService())

        var results: [AIEvaluationResult] = []
        for evaluationCase in cases {
            results.append(await runner.runModelCase(evaluationCase))
        }

        Attachment.record(AIEvaluationReportBuilder.markdown(results: results), named: "on-device-evaluation.md")
        for result in results {
            for check in result.checks where check.id == "validator" {
                #expect(check.passed, "\(result.caseID): \(check.detail)")
            }
        }
    }

    @Test(.enabled(if: OnDeviceModel.isUsable), arguments: ["rubric_essay", "rubric_lab", "rubric_short_answer"])
    func onDeviceRubricSuggestionFixtures(fixture: String) async throws {
        let text = try TestFixtures.text(named: fixture, extension: "txt")
        let expected = try JSONDecoder().decode(
            RubricSuggestionExpectation.self,
            from: TestFixtures.data(named: "\(fixture).expected", extension: "json")
        )

        let rubric = try await RubricSuggestionService().suggest(fromPlainText: text)

        #expect(rubric.criteria.count == expected.criterionCount)
        #expect(rubric.criteria.reduce(0) { $0 + $1.maxPoints } == expected.totalPoints)
    }
}

private struct RubricSuggestionExpectation: Decodable {
    var criterionCount: Int
    var totalPoints: Double
}

/// Fixture files are copied into the test bundle, so they load on a device as well as in the simulator.
private enum TestFixtures {
    private final class BundleToken {}

    static var bundle: Bundle { Bundle(for: BundleToken.self) }

    static func data(named name: String, extension fileExtension: String) throws -> Data {
        let url = try #require(bundle.url(forResource: name, withExtension: fileExtension), "Missing fixture \(name).\(fileExtension)")
        return try Data(contentsOf: url)
    }

    static func text(named name: String, extension fileExtension: String) throws -> String {
        String(decoding: try data(named: name, extension: fileExtension), as: UTF8.self)
    }

    static func evaluationCases() throws -> [AIEvaluationCase] {
        let urls = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasSuffix("_cases.json") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.flatMap { url in
            try JSONDecoder().decode([AIEvaluationCase].self, from: Data(contentsOf: url))
        }
    }
}

/// These tests measure the real on-device model, so they run only on an Apple Intelligence device.
/// The simulator can report the model as available but cannot load its assets.
private enum OnDeviceModel {
    static var isUsable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return SystemLanguageModel.default.isAvailable
        #endif
    }
}
