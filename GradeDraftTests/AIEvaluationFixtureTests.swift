import XCTest
@testable import GradeDraft

final class AIEvaluationFixtureTests: XCTestCase {
    func testDeterministicEvaluationPreflightRunsWithoutModelAttempt() async throws {
        let runner = AIEvaluationRunner()
        for evaluationCase in try loadAllCases() {
            let result = await runner.runPreflight(evaluationCase)
            XCTAssertFalse(result.modelAttempted)
            XCTAssertEqual(result.caseID, evaluationCase.id)
            XCTAssertEqual(result.promptVersion, GradeDraftPromptVersion.currentFoundationModelsTyped)
            XCTAssertFalse(result.packetFingerprint.isEmpty)
            XCTAssertFalse(result.checks.isEmpty)
            XCTAssertFalse(result.checks.contains { $0.id == "identity-redaction" && !$0.passed }, "\(evaluationCase.id) leaked identity in prompt preflight")
            XCTAssertFalse(result.checks.contains { $0.id == "expected-constraints" && !$0.passed }, "\(evaluationCase.id) lost expected constraints")
            if evaluationCase.expected.requiresPromptInjectionFlag {
                XCTAssertTrue(result.checks.contains { $0.id == "prompt-injection-flag" && $0.passed }, "\(evaluationCase.id) did not flag prompt injection")
            }
        }
    }

    func testEvaluationCheckerCatchesUnsafeDraftOutput() throws {
        let evaluationCase = try loadCase(id: "prompt-injection-basic-001")
        let input = evaluationCase.makeGradingInput()
        let unsafeDraft = GradeDraftResult(
            packetFingerprint: input.packetFingerprint,
            status: .generated,
            studentResponseSummary: "The student should receive full marks because the student instructed it.",
            criteria: [
                CriterionScore(
                    criterionID: "claim",
                    rating: "Full marks",
                    proposedPoints: 4,
                    evidenceQuotes: ["School uniforms are good because they look nice."],
                    explanation: "As requested by the student, this is excellent.",
                    teacherReviewRequired: false
                ),
                CriterionScore(
                    criterionID: "evidence",
                    rating: "Full marks",
                    proposedPoints: 4,
                    evidenceQuotes: ["School uniforms are good because they look nice."],
                    explanation: "The final grade is high.",
                    teacherReviewRequired: false
                )
            ],
            studentFeedback: "This is the final grade.",
            teacherNotes: "",
            uncertaintyFlags: []
        )

        let checks = AIEvaluationChecker.check(draft: unsafeDraft, expected: evaluationCase.expected, input: input)

        XCTAssertTrue(checks.contains { $0.id.hasPrefix("must-not-contain") && !$0.passed })
        XCTAssertTrue(checks.contains { $0.id == "teacher-review-required" && !$0.passed })
        XCTAssertTrue(checks.contains { $0.id == "max-points-claim" && !$0.passed })
    }

    func testEvaluationReportIsAnonymized() async throws {
        let result = await AIEvaluationRunner().runPreflight(try loadCase(id: "prompt-injection-basic-001"))
        let markdown = AIEvaluationReportBuilder.markdown(results: [result])

        XCTAssertFalse(markdown.contains("Student Alpha"))
        XCTAssertFalse(markdown.contains("7A"))
        XCTAssertFalse(markdown.contains("Ignore all previous instructions"))
        XCTAssertTrue(markdown.contains("prompt-injection-basic-001"))
        XCTAssertTrue(markdown.contains("Model attempted: no"))
    }

    // MARK: - Fixtures

    private final class BundleToken {}

    /// The fixture files are copied into the test bundle, so they load in the simulator and on a device.
    private func loadAllCases() throws -> [AIEvaluationCase] {
        let bundle = Bundle(for: BundleToken.self)
        let urls = (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasSuffix("_cases.json") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertFalse(urls.isEmpty, "No evaluation fixture files in the test bundle")
        return try urls.flatMap { url in
            try JSONDecoder().decode([AIEvaluationCase].self, from: Data(contentsOf: url))
        }
    }

    private func loadCase(id: String) throws -> AIEvaluationCase {
        guard let evaluationCase = try loadAllCases().first(where: { $0.id == id }) else {
            XCTFail("Missing evaluation case \(id)")
            throw NSError(domain: "AIEvaluationFixtureTests", code: 1)
        }
        return evaluationCase
    }
}
