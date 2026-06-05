import XCTest
@testable import GradeDraft

final class AIEvaluationFixtureTests: XCTestCase {
    private let requiredDatasets = [
        "prompt_injection_cases.json",
        "ocr_uncertainty_cases.json",
        "source_reference_cases.json",
        "prohibited_inference_cases.json",
        "answer_key_strict_cases.json",
        "exemplar_comparison_cases.json",
        "formative_feedback_cases.json",
        "summative_caution_cases.json",
        "conventions_safe_cases.json",
        "eald_sensitive_cases.json",
        "adjustment_context_cases.json",
        "off_prompt_cases.json",
        "misconception_cases.json",
        "long_context_cases.json",
        "unsupported_language_cases.json",
        "guardrail_error_cases.json",
        "feedback_rewrite_cases.json",
        "batch_workflow_cases.json"
    ]

    func testEvaluationFixtureDatasetsExistAndDecode() throws {
        let root = fixtureRoot()
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("evaluation_case_schema.json").path))

        var allCases: [AIEvaluationCase] = []
        for dataset in requiredDatasets {
            let url = root.appendingPathComponent(dataset)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "\(dataset) is missing")
            let data = try Data(contentsOf: url)
            let cases = try JSONDecoder().decode([AIEvaluationCase].self, from: data)
            XCTAssertFalse(cases.isEmpty, "\(dataset) must contain at least one case")
            allCases.append(contentsOf: cases)
        }

        XCTAssertEqual(Set(allCases.map(\.id)).count, allCases.count, "Evaluation case IDs must be unique")
        XCTAssertTrue(allCases.allSatisfy { !$0.selectedConstraintIDs.contains("eald-sensitive") || $0.assignment.customInstructions.localizedCaseInsensitiveContains("teacher") })
        XCTAssertTrue(allCases.allSatisfy { !$0.selectedConstraintIDs.contains("adjustment-context") || $0.assignment.customInstructions.localizedCaseInsensitiveContains("Teacher-provided") })
    }

    func testRequiredEvaluationCategoriesAreCovered() throws {
        let categories = Set(try loadAllCases().flatMap(\.categories))
        let expected: Set<String> = [
            "prompt_injection",
            "ocr_uncertainty",
            "source_reference",
            "prohibited_inference",
            "answer_key_strict",
            "exemplar_comparison",
            "formative_feedback",
            "summative_caution",
            "conventions_safe",
            "eald_sensitive",
            "adjustment_context",
            "off_prompt",
            "misconception",
            "long_context",
            "unsupported_language",
            "guardrail_error",
            "feedback_rewrite",
            "batch_workflow"
        ]
        XCTAssertEqual(categories, expected)
    }

    func testDeterministicEvaluationPreflightRunsWithoutModelAttempt() throws {
        let runner = AIEvaluationRunner()
        for evaluationCase in try loadAllCases() {
            let result = runner.runDeterministicPreflight(evaluationCase)
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
                    criterion: "Clear claim",
                    rating: "Full marks",
                    proposedPoints: 4,
                    maxPoints: 4,
                    evidence: ["School uniforms are good because they look nice."],
                    explanation: "As requested by the student, this is excellent.",
                    teacherReviewRequired: false
                ),
                CriterionScore(
                    criterionID: "evidence",
                    criterion: "Relevant evidence",
                    rating: "Full marks",
                    proposedPoints: 4,
                    maxPoints: 4,
                    evidence: ["School uniforms are good because they look nice."],
                    explanation: "The final grade is high.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 8,
            maxScore: 8,
            studentFeedback: "This is the final grade.",
            teacherNotes: "",
            uncertaintyFlags: []
        )

        let checks = AIEvaluationChecker.check(draft: unsafeDraft, expected: evaluationCase.expected, input: input)

        XCTAssertTrue(checks.contains { $0.id.hasPrefix("must-not-contain") && !$0.passed })
        XCTAssertTrue(checks.contains { $0.id == "teacher-review-required" && !$0.passed })
        XCTAssertTrue(checks.contains { $0.id == "max-points-claim" && !$0.passed })
        XCTAssertTrue(checks.contains { $0.id == "deterministic-validator" && !$0.passed })
    }

    func testEvaluationReportIsAnonymized() throws {
        let result = AIEvaluationRunner().runDeterministicPreflight(try loadCase(id: "prompt-injection-basic-001"))
        let markdown = AIEvaluationReportBuilder.markdown(results: [result])

        XCTAssertFalse(markdown.contains("Student Alpha"))
        XCTAssertFalse(markdown.contains("7A"))
        XCTAssertFalse(markdown.contains("Ignore all previous instructions"))
        XCTAssertTrue(markdown.contains("prompt-injection-basic-001"))
        XCTAssertTrue(markdown.contains("Model attempted: no"))
    }

    private func loadAllCases() throws -> [AIEvaluationCase] {
        try requiredDatasets.flatMap { dataset in
            let data = try Data(contentsOf: fixtureRoot().appendingPathComponent(dataset))
            return try JSONDecoder().decode([AIEvaluationCase].self, from: data)
        }
    }

    private func loadCase(id: String) throws -> AIEvaluationCase {
        guard let evaluationCase = try loadAllCases().first(where: { $0.id == id }) else {
            XCTFail("Missing evaluation case \(id)")
            throw NSError(domain: "AIEvaluationFixtureTests", code: 1)
        }
        return evaluationCase
    }

    private func fixtureRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("AIEvaluation")
    }
}
