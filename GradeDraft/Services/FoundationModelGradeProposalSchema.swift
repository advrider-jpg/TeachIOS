import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
enum FoundationModelGradeProposalSchema {
    @Generable
    struct GradeDraftProposal: Sendable {
        @Guide(description: "One or two factual sentences about what the student wrote. Do not infer effort, intent, personality, ability, disability, demographics, language background, or support needs.")
        let studentResponseSummary: String

        @Guide(description: "One draft score object for each rubric criterion requested by the app. Do not add extra criteria.")
        let criteria: [CriterionDraft]

        @Guide(description: "Student-facing feedback that is specific, constructive, concise, and based only on reviewed text and grading materials.")
        let studentFeedback: String

        @Guide(description: "Private teacher-facing notes about ambiguity, OCR concerns, evidence concerns, conservative scoring calls, or rubric interpretation.")
        let teacherNotes: String

        @Guide(description: "Issues the teacher should review before finalizing this draft.")
        let uncertaintyFlags: [String]

        @Guide(description: "Short statements describing how the draft was constrained to the rubric, reviewed text, and teacher-provided grading materials.")
        let complianceFlags: [String]
    }

    @Generable
    struct CriterionDraft: Sendable {
        @Guide(description: "The rubric criterion id supplied by the app. Use it exactly. If no id exists, use an empty string.")
        let criterionId: String

        @Guide(description: "The rubric criterion title supplied by the app. Use the app wording as closely as possible.")
        let criterion: String

        @Guide(description: "Rubric level, band, or short qualitative label for this criterion.")
        let rating: String

        @Guide(description: "Proposed numeric points for this criterion. The app will clamp and validate this against the rubric maximum.")
        let proposedPoints: Double

        @Guide(description: "Rubric maximum points for this criterion. Use the maximum supplied by the app.")
        let maxPoints: Double

        @Guide(description: "Exact quotes from the reviewed student text that support the criterion decision, or exactly 'No supporting evidence found.' when evidence is missing.")
        let evidence: [String]

        @Guide(description: "Source reference tags that match cited quotes when tags such as [p1-l2-abcdef12] are present in reviewed text.")
        let evidenceSourceRefs: [String]

        @Guide(description: "Rubric-based explanation for the proposed score. Use only reviewed text and grading materials.")
        let explanation: String

        @Guide(description: "A specific improvement suggestion or next step when appropriate.")
        let nextStep: String

        @Guide(description: "Confidence in the criterion suggestion based on evidence clarity, rubric clarity, and OCR reliability.")
        let confidence: DraftConfidence

        @Guide(description: "True when evidence is missing, OCR is uncertain, rubric interpretation is ambiguous, source references are unsupported, or the criterion involves content the app cannot reliably assess.")
        let teacherReviewRequired: Bool

        @Guide(description: "Criterion-specific issues requiring teacher attention.")
        let uncertaintyFlags: [String]
    }

    @Generable
    enum DraftConfidence: String, CaseIterable, Sendable {
        case high
        case medium
        case low
    }

    @Generable
    struct SingleCriterionDraft: Sendable {
        @Guide(description: "The draft scoring suggestion for the single criterion requested by the app.")
        let criterion: CriterionDraft
    }

    @Generable
    struct DraftSummaryFeedback: Sendable {
        @Guide(description: "One or two factual sentences about what the student wrote. Do not infer effort, intent, personality, ability, disability, demographics, language background, or support needs.")
        let studentResponseSummary: String

        @Guide(description: "Student-facing feedback synthesizing the criterion-level suggestions. It must be concise, constructive, and based only on reviewed text and teacher-provided grading materials.")
        let studentFeedback: String

        @Guide(description: "Private teacher-facing notes about draft limitations, ambiguity, OCR concerns, or evidence concerns.")
        let teacherNotes: String

        @Guide(description: "Issues the teacher should review before finalizing this draft.")
        let uncertaintyFlags: [String]

        @Guide(description: "Short statements describing how the summary was constrained to rubric, reviewed text, and teacher-provided materials.")
        let complianceFlags: [String]
    }
}

@available(iOS 26.0, *)
extension FoundationModelGradeProposalSchema.CriterionDraft {
    func asCriterionScore() -> CriterionScore {
        let trimmedID = criterionId.trimmingCharacters(in: .whitespacesAndNewlines)
        return CriterionScore(
            criterionID: trimmedID.isEmpty ? nil : trimmedID,
            criterion: criterion,
            rating: rating,
            proposedPoints: proposedPoints,
            maxPoints: maxPoints,
            evidence: evidence,
            evidenceSourceRefs: evidenceSourceRefs,
            explanation: explanation,
            teacherReviewRequired: teacherReviewRequired,
            nextStep: nextStep,
            confidence: confidence.rawValue,
            criterionUncertaintyFlags: uncertaintyFlags
        )
    }
}

@available(iOS 26.0, *)
extension FoundationModelGradeProposalSchema.GradeDraftProposal {
    func asGradeDraftResult(input: GradingInput, audit: LocalModelDraftAudit) -> GradeDraftResult {
        let scores = criteria.map { $0.asCriterionScore() }
        return GradeDraftResult(
            packetFingerprint: input.packetFingerprint,
            status: scores.contains { $0.teacherReviewRequired } ? .teacherReviewRequired : .generated,
            studentResponseSummary: studentResponseSummary,
            criteria: scores,
            totalScore: scores.reduce(0) { $0 + $1.proposedPoints },
            maxScore: scores.reduce(0) { $0 + $1.maxPoints },
            studentFeedback: studentFeedback,
            teacherNotes: teacherNotes,
            uncertaintyFlags: uncertaintyFlags,
            complianceFlags: complianceFlags,
            rawModelResponse: nil,
            localModelAudit: audit
        )
    }
}

#endif
