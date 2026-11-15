import Foundation

import FoundationModels

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
        @Guide(description: "The rubric criterion id supplied by the app. Use it exactly.")
        let criterionId: String

        @Guide(description: "Rubric level, band, or short qualitative label for this criterion.")
        let rating: String

        @Guide(description: "Proposed numeric points for this criterion. The app will clamp and validate this against the rubric maximum.")
        let proposedPoints: Double

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

    /// Used only when the assignment has no point-bearing rubric criteria (answer key, exemplar or criteria
    /// text only): the model names each criterion and its maximum, and the validator applies today's checks.
    @Generable
    struct UnstructuredGradeDraftProposal: Sendable {
        @Guide(description: "One or two factual sentences about what the student wrote. Do not infer effort, intent, personality, ability, disability, demographics, language background, or support needs.")
        let studentResponseSummary: String

        @Guide(description: "One draft score object for each criterion in the teacher-supplied grading materials. Do not add criteria the materials do not contain.")
        let criteria: [UnstructuredCriterionDraft]

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
    struct UnstructuredCriterionDraft: Sendable {
        @Guide(description: "The criterion title from the teacher-supplied grading materials. Use the teacher's wording as closely as possible.")
        let title: String

        @Guide(description: "Maximum points for this criterion, as stated in the teacher-supplied grading materials.")
        let maxPoints: Double

        @Guide(description: "Rubric level, band, or short qualitative label for this criterion.")
        let rating: String

        @Guide(description: "Proposed numeric points for this criterion. The app will clamp and validate this against the maximum.")
        let proposedPoints: Double

        @Guide(description: "Exact quotes from the reviewed student text that support the criterion decision, or exactly 'No supporting evidence found.' when evidence is missing.")
        let evidence: [String]

        @Guide(description: "Source reference tags that match cited quotes when tags such as [p1-l2-abcdef12] are present in reviewed text.")
        let evidenceSourceRefs: [String]

        @Guide(description: "Explanation for the proposed score. Use only reviewed text and grading materials.")
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

    @Generable
    struct FeedbackRewriteDraft: Sendable {
        @Guide(description: "Rewritten student-facing feedback. Preserve teacher meaning, do not change scores, do not add evidence, and do not use final-grade language.")
        let rewrittenFeedback: String

        @Guide(description: "Teacher-facing notes describing any limitation, ambiguity, or reason the teacher must review before export.")
        let teacherReviewNotes: [String]
    }
}

// MARK: - Model output handed to the validator

/// One criterion as the model proposed it, before validation. On the rubric path `title` and `maxPoints` are
/// nil (the validator takes them from the rubric); on the no-rubric path the model supplies them.
struct ModelCriterionProposal: Equatable, Sendable {
    var criterionID: String
    var title: String?
    var maxPoints: Double?
    var rating: String
    var proposedPoints: Double
    var evidence: [String]
    var evidenceSourceRefs: [String]
    var explanation: String
    var nextStep: String
    var confidence: String
    var teacherReviewRequired: Bool
    var uncertaintyFlags: [String]
}

struct ModelDraftProposal: Equatable, Sendable {
    var studentResponseSummary: String
    var criteria: [ModelCriterionProposal]
    var studentFeedback: String
    var teacherNotes: String
    var uncertaintyFlags: [String]
    var complianceFlags: [String]
}

extension FoundationModelGradeProposalSchema.CriterionDraft {
    func proposal(knownCriterionID: String? = nil) -> ModelCriterionProposal {
        ModelCriterionProposal(
            criterionID: (knownCriterionID ?? criterionId).trimmingCharacters(in: .whitespacesAndNewlines),
            title: nil,
            maxPoints: nil,
            rating: rating,
            proposedPoints: proposedPoints,
            evidence: evidence,
            evidenceSourceRefs: evidenceSourceRefs,
            explanation: explanation,
            nextStep: nextStep,
            confidence: confidence.rawValue,
            teacherReviewRequired: teacherReviewRequired,
            uncertaintyFlags: uncertaintyFlags
        )
    }
}

extension FoundationModelGradeProposalSchema.UnstructuredCriterionDraft {
    var proposal: ModelCriterionProposal {
        ModelCriterionProposal(
            criterionID: "",
            title: title,
            maxPoints: maxPoints,
            rating: rating,
            proposedPoints: proposedPoints,
            evidence: evidence,
            evidenceSourceRefs: evidenceSourceRefs,
            explanation: explanation,
            nextStep: nextStep,
            confidence: confidence.rawValue,
            teacherReviewRequired: teacherReviewRequired,
            uncertaintyFlags: uncertaintyFlags
        )
    }
}

extension FoundationModelGradeProposalSchema.GradeDraftProposal {
    var proposal: ModelDraftProposal {
        ModelDraftProposal(
            studentResponseSummary: studentResponseSummary,
            criteria: criteria.map { $0.proposal() },
            studentFeedback: studentFeedback,
            teacherNotes: teacherNotes,
            uncertaintyFlags: uncertaintyFlags,
            complianceFlags: complianceFlags
        )
    }
}

extension FoundationModelGradeProposalSchema.UnstructuredGradeDraftProposal {
    var proposal: ModelDraftProposal {
        ModelDraftProposal(
            studentResponseSummary: studentResponseSummary,
            criteria: criteria.map(\.proposal),
            studentFeedback: studentFeedback,
            teacherNotes: teacherNotes,
            uncertaintyFlags: uncertaintyFlags,
            complianceFlags: complianceFlags
        )
    }
}

// MARK: - Rows shown while the model writes

extension FoundationModelGradeProposalSchema.CriterionDraft.PartiallyGenerated {
    func partialCriterion(knownCriterionID: String? = nil) -> PartialCriterion? {
        let id = (knownCriterionID ?? criterionId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }
        return PartialCriterion(criterionID: id, rating: rating, proposedPoints: proposedPoints, explanation: explanation)
    }
}

extension FoundationModelGradeProposalSchema.GradeDraftProposal.PartiallyGenerated {
    var partialCriteria: [PartialCriterion] {
        (criteria ?? []).compactMap { $0.partialCriterion() }
    }
}

extension FoundationModelGradeProposalSchema.UnstructuredGradeDraftProposal.PartiallyGenerated {
    /// Without rubric IDs, each row is identified by the title the model is writing.
    var partialCriteria: [PartialCriterion] {
        (criteria ?? []).compactMap { criterion in
            let title = (criterion.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return PartialCriterion(criterionID: title, rating: criterion.rating, proposedPoints: criterion.proposedPoints, explanation: criterion.explanation)
        }
    }
}

extension FoundationModelGradeProposalSchema.FeedbackRewriteDraft {
    func asFeedbackRewriteResult() -> FeedbackRewriteResult {
        FeedbackRewriteResult(
            rewrittenFeedback: rewrittenFeedback,
            teacherReviewNotes: teacherReviewNotes
        )
    }
}
