import Foundation
import FoundationModels
import Synchronization
import Testing
@testable import GradeDraft

/// Drafting and suggestion behaviour with a scripted on-device model. The model's output is supplied as
/// `GeneratedContent`, the form the framework decodes, so the service's streaming, retry and validation paths
/// run unchanged.
struct DraftingTests {
    @Test
    func contextOverflowRetriesCompactThenPerCriterion() async throws {
        let generator = ScriptedDraftGenerator([
            .failure(.contextTooLarge),
            .failure(.contextTooLarge),
            .output([DraftFixtures.singleCriterion("c1", points: 3, evidence: "Plants need sunlight.")]),
            .output([DraftFixtures.singleCriterion("c2", points: 4, evidence: "Water moves through the stem.")]),
            .output([DraftFixtures.singleCriterion("c3", points: 2.5, evidence: "Leaves make food.")])
        ])
        let service = DraftFixtures.service(generator: generator)

        let draft = try await service.draftGrade(input: DraftFixtures.input, progress: nil)

        let proposal = String(describing: FoundationModelGradeProposalSchema.GradeDraftProposal.self)
        let single = String(describing: FoundationModelGradeProposalSchema.SingleCriterionDraft.self)
        let calls = generator.calls
        #expect(calls.map(\.typeName) == [proposal, proposal, single, single, single])
        #expect(!calls[0].prompt.contains(DraftFixtures.compactMarker))
        #expect(calls[1].prompt.contains(DraftFixtures.compactMarker))
        #expect(draft.criteria.map(\.criterionID) == ["c1", "c2", "c3"])
        #expect(draft.modelAudit?.generationMode == .perCriterion)
    }

    @Test
    func cancellationStoresNoDraft() async throws {
        let generator = ScriptedDraftGenerator([
            .outputThenWait([DraftFixtures.partialProposal])
        ])
        let service = DraftFixtures.service(generator: generator)
        let (partialSeen, signal) = AsyncStream<Void>.makeStream()

        let drafting = Task {
            try await service.draftGrade(input: DraftFixtures.input) { progress in
                if case .partial = progress.stage {
                    signal.yield()
                }
            }
        }
        var waiter = partialSeen.makeAsyncIterator()
        _ = await waiter.next()
        drafting.cancel()

        switch await drafting.result {
        case .success:
            Issue.record("A draft was returned after the teacher cancelled.")
        case .failure(let error):
            #expect(error as? DraftFailure == .cancelled)
        }
    }

    @Test
    func draftTotalsEqualSumOfCriterionPoints() async throws {
        let generator = ScriptedDraftGenerator([
            .output([
                DraftFixtures.partialProposal,
                DraftFixtures.proposal(criteria: [
                    DraftFixtures.criterion("c1", points: 3, evidence: "Plants need sunlight."),
                    DraftFixtures.criterion("c2", points: 4, evidence: "Water moves through the stem."),
                    DraftFixtures.criterion("c3", points: 2.5, evidence: "Leaves make food.")
                ])
            ])
        ])
        let service = DraftFixtures.service(generator: generator)

        let draft = try await service.draftGrade(input: DraftFixtures.input, progress: nil)

        #expect(draft.criteria.map(\.proposedPoints) == [3, 4, 2.5])
        #expect(draft.totalScore == 9.5)
    }

    @Test
    func curriculumSuggestionsOnlyCatalogueCodes() async throws {
        let catalog = CurriculumCatalogService()
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Persuasive"))
        let found = try await catalog.search(setup.assignment.title, limit: 1)
        let realItem = try #require(found.first)
        let generator = ScriptedDraftGenerator([
            .output([GeneratedContent(properties: ["codes": [realItem.code, "INVENTED-999"]])])
        ])

        let itemIDs = try await CurriculumSuggestionService(catalog: catalog, generator: generator).suggest(for: setup)
        let mappings = CurriculumSuggestionService.unconfirmedMappings(itemIDs: itemIDs, assignmentID: setup.assignment.id)

        #expect(mappings.map(\.curriculumItemID) == [realItem.id])
        #expect(mappings.allSatisfy { $0.suggestedByAI && !$0.teacherConfirmed })
    }
}

// MARK: - Fixtures

private enum DraftFixtures {
    static let compactMarker = "Structured criteria above are the active rubric source for compact mode."

    static let input: GradingInput = {
        let criteria = [
            RubricCriterion(id: "c1", title: "Light", maxPoints: 5, descriptor: "Explains the role of light.", sortOrder: 0),
            RubricCriterion(id: "c2", title: "Water", maxPoints: 5, descriptor: "Explains how water moves.", sortOrder: 1),
            RubricCriterion(id: "c3", title: "Food", maxPoints: 5, descriptor: "Explains how leaves make food.", sortOrder: 2)
        ]
        let reviewedText = "Plants need sunlight. Water moves through the stem. Leaves make food."
        return GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "How plants grow",
            prompt: "Explain what a plant needs to grow.",
            subject: "Science",
            gradeLevel: "Year 5",
            className: "5B",
            studentDisplayName: "Sample Student",
            assignmentType: .shortAnswer,
            rubricText: "Light: 0-5 points\nWater: 0-5 points\nFood: 0-5 points",
            parsedRubric: ParsedRubric(criteria: criteria),
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            assessmentPurpose: .formative,
            curriculumReference: "",
            reviewedStudentText: reviewedText,
            reviewedTextWithSourceRefs: reviewedText,
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .reviewed,
            sourceInputCount: 0,
            packetFingerprint: "drafting-tests",
            hasGradingStandard: true
        )
    }()

    static func service(generator: ScriptedDraftGenerator) -> FoundationModelGradingService {
        FoundationModelGradingService(generator: generator, budgeter: StepDownBudgeter(), availability: { .available })
    }

    static func criterion(_ id: String, points: Double, evidence: String) -> GeneratedContent {
        GeneratedContent(properties: [
            "criterionId": id,
            "rating": "Meets the standard",
            "proposedPoints": points,
            "evidence": [evidence],
            "evidenceSourceRefs": [String](),
            "explanation": "The reviewed text states this directly.",
            "nextStep": "Add one more example.",
            "confidence": "high",
            "teacherReviewRequired": false,
            "uncertaintyFlags": [String]()
        ])
    }

    static func singleCriterion(_ id: String, points: Double, evidence: String) -> GeneratedContent {
        GeneratedContent(properties: ["criterion": criterion(id, points: points, evidence: evidence)])
    }

    static func proposal(criteria: [GeneratedContent]) -> GeneratedContent {
        GeneratedContent(properties: [
            "studentResponseSummary": "The response names light, water and food making.",
            "criteria": criteria,
            "studentFeedback": "You named three things a plant needs. Add an example for each.",
            "teacherNotes": "Short response; each point is stated once.",
            "uncertaintyFlags": [String](),
            "complianceFlags": [String]()
        ])
    }

    static let partialProposal = GeneratedContent(properties: [
        "studentResponseSummary": "The response names",
        "criteria": [GeneratedContent(properties: ["criterionId": "c1", "rating": "Meets"])]
    ])
}

/// Plans the full packet first, then the next smaller mode each time the model rejects one for context size.
private struct StepDownBudgeter: GradingPromptBudgeting {
    func plan(input: GradingInput, after failedMode: LocalModelGenerationMode?) async throws -> PromptBudgetPlan {
        let mode: LocalModelGenerationMode
        switch failedMode {
        case nil: mode = .fullPacket
        case .fullPacket: mode = .compactFullPacket
        case .compactFullPacket: mode = .perCriterion
        case .perCriterion, .unavailable: throw DraftFailure.contextTooLarge
        }
        return PromptBudgetPlan(
            mode: mode,
            report: PromptBudgetReport(
                contextSizeTokens: 0,
                fullPacketTokens: nil,
                compactPacketTokens: nil,
                perCriterionTokenCounts: [:],
                selectedMode: mode,
                reservedOutputTokens: 0,
                promptFingerprint: "drafting-tests",
                warnings: []
            )
        )
    }

    func summaryFits(input: GradingInput, criteria: [ModelCriterionProposal]) async throws -> Bool {
        false
    }
}

/// Returns scripted model output, one step per request, and records each request.
private final class ScriptedDraftGenerator: DraftGenerating {
    enum Step: Sendable {
        /// Each value is passed to `onPartial` in order; the last is the complete output of the request.
        case output([GeneratedContent])
        /// Passes the values to `onPartial`, then waits until the request is cancelled.
        case outputThenWait([GeneratedContent])
        case failure(DraftFailure)
    }

    struct Call: Sendable {
        var typeName: String
        var prompt: String
    }

    private let state: Mutex<(steps: [Step], calls: [Call])>

    init(_ steps: [Step]) {
        state = Mutex((steps, []))
    }

    var calls: [Call] {
        state.withLock { $0.calls }
    }

    func draft<T: Generable>(_ type: T.Type, instructions: String, prompt: String, options: GenerationOptions, onPartial: @escaping @Sendable (T.PartiallyGenerated) -> Void) async throws -> T {
        switch nextStep(typeName: String(describing: T.self), prompt: prompt) {
        case .failure(let failure):
            throw failure
        case .output(let values):
            for value in values {
                onPartial(try T.PartiallyGenerated(value))
            }
            return try T(try complete(values))
        case .outputThenWait(let values):
            for value in values {
                onPartial(try T.PartiallyGenerated(value))
            }
            try await Task.sleep(for: .seconds(3600))
            throw DraftFailure.other("The scripted wait ended without cancellation.")
        }
    }

    func respond<T: Generable>(_ type: T.Type, instructions: String, prompt: String, options: GenerationOptions) async throws -> T {
        try T(try await scriptedContent(typeName: String(describing: T.self), prompt: prompt))
    }

    func respond(schema: GenerationSchema, instructions: String, prompt: String, options: GenerationOptions) async throws -> GeneratedContent {
        try await scriptedContent(typeName: "GenerationSchema", prompt: prompt)
    }

    private func scriptedContent(typeName: String, prompt: String) async throws -> GeneratedContent {
        switch nextStep(typeName: typeName, prompt: prompt) {
        case .failure(let failure):
            throw failure
        case .output(let values), .outputThenWait(let values):
            return try complete(values)
        }
    }

    private func complete(_ values: [GeneratedContent]) throws -> GeneratedContent {
        guard let last = values.last else { throw DraftFailure.other("The script had no output.") }
        return last
    }

    private func nextStep(typeName: String, prompt: String) -> Step {
        state.withLock { state in
            state.calls.append(Call(typeName: typeName, prompt: prompt))
            guard !state.steps.isEmpty else { return .failure(.other("The script has no more steps.")) }
            return state.steps.removeFirst()
        }
    }
}
