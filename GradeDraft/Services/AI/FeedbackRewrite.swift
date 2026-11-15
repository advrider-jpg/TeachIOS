import Foundation

enum FeedbackRewriteMode: String, CaseIterable, Codable, Identifiable, Equatable, Sendable {
    case warmer
    case concise
    case specific
    case ageAppropriate
    case strengthsNextStep
    case removeFinalGradeLanguage
    case teacherNotesToStudentSafe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmer:
            return "Make warmer"
        case .concise:
            return "Make concise"
        case .specific:
            return "Make specific"
        case .ageAppropriate:
            return "Age appropriate"
        case .strengthsNextStep:
            return "Strengths + next step"
        case .removeFinalGradeLanguage:
            return "Remove final-grade language"
        case .teacherNotesToStudentSafe:
            return "Student-safe from notes"
        }
    }

    var instruction: String {
        switch self {
        case .warmer:
            return "Make the student-facing feedback warmer while preserving the teacher's meaning."
        case .concise:
            return "Make the student-facing feedback more concise while preserving specific evidence."
        case .specific:
            return "Make the student-facing feedback more specific using only the supplied reviewed evidence and final-review criteria."
        case .ageAppropriate:
            return "Convert the student-facing feedback to age-appropriate language for the supplied grade or year level."
        case .strengthsNextStep:
            return "Format the feedback as strengths plus one practical next step."
        case .removeFinalGradeLanguage:
            return "Remove final-grade or official-grade language while preserving the reviewed teacher meaning."
        case .teacherNotesToStudentSafe:
            return "Rewrite only the teacher-selected private notes into student-safe feedback. Do not include private concerns or hidden rules."
        }
    }
}

/// One final-review criterion as the rewrite request shows it to the model.
struct FeedbackRewriteCriterion: Codable, Equatable, Sendable {
    var title: String
    var finalPoints: Double
    var maxPoints: Double
    var teacherApproved: Bool
    var evidence: [String]
    var explanation: String
}

struct FeedbackRewriteInput: Codable, Equatable, Sendable {
    var mode: FeedbackRewriteMode
    var currentStudentFeedback: String
    var selectedTeacherNotes: String
    var gradeLevel: String
    var criteria: [FeedbackRewriteCriterion]
    var reviewedStudentText: String
    var packetFingerprint: String

    /// Builds the request from the teacher's final review. Criterion titles and maximums come from the rubric,
    /// or from the criterion itself when the assignment has no point-bearing rubric; evidence is the quotes the
    /// teacher attached.
    init(
        setup: AssignmentSetup,
        graph: SubmissionGraph,
        review: FinalGradeReview,
        mode: FeedbackRewriteMode,
        selectedTeacherNotes: String
    ) throws {
        let rubricByID = Dictionary(setup.parsedRubric.criteria.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let quotesByID = Dictionary(graph.evidence.map { ($0.id, $0.quote) }, uniquingKeysWith: { first, _ in first })
        self.mode = mode
        self.currentStudentFeedback = review.studentFeedback
        self.selectedTeacherNotes = selectedTeacherNotes
        self.gradeLevel = setup.assignment.gradeLevel
        self.criteria = review.criteria.map { criterion in
            let rubricCriterion = rubricByID[criterion.criterionID]
            return FeedbackRewriteCriterion(
                title: rubricCriterion?.title ?? criterion.title ?? criterion.criterionID,
                finalPoints: criterion.finalPoints,
                maxPoints: rubricCriterion?.maxPoints ?? criterion.maxPoints ?? 0,
                teacherApproved: criterion.teacherApproved,
                evidence: criterion.evidenceIDs.compactMap { quotesByID[$0] },
                explanation: criterion.explanation
            )
        }
        self.reviewedStudentText = graph.reviewedText
        self.packetFingerprint = try graph.packetFingerprint(setup: setup)
    }
}

struct FeedbackRewriteResult: Codable, Equatable {
    var rewrittenFeedback: String
    var teacherReviewNotes: [String]
}

enum FeedbackRewriteValidator {
    static func validate(_ result: FeedbackRewriteResult, input: FeedbackRewriteInput) throws -> FeedbackRewriteResult {
        _ = input
        let feedback = result.rewrittenFeedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !feedback.isEmpty else {
            throw GradeDraftError.invalidModelGrade("The rewrite assistant returned empty feedback.")
        }
        if containsFinalGradeLanguage(feedback) {
            throw GradeDraftError.invalidModelGrade("The rewrite assistant returned final-grade language.")
        }
        if containsProhibitedInference(feedback) {
            throw GradeDraftError.invalidModelGrade("The rewrite assistant returned prohibited inference language.")
        }
        let notes = Array(Set(result.teacherReviewNotes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        return FeedbackRewriteResult(rewrittenFeedback: feedback, teacherReviewNotes: notes + ["Teacher approval is required before student-facing export."])
    }

    private static let prohibitedInferencePatterns: [String] = [
        #"\beffort\b"#,
        #"\btried hard\b"#,
        #"\bdid not try\b"#,
        #"\bintent\b"#,
        #"\bmotivat(?:ed|ion|ional|e|ed)\b"#,
        #"\bbehavior\b"#,
        #"\battitude\b"#,
        #"\bpersonality\b"#,
        #"\blazy\b"#,
        #"\bcareless(?:ness)?\b"#,
        #"\b(?:low|high) ability\b"#,
        #"\bdisab(?:ility|led)\b"#,
        #"\beal/d\b"#,
        #"\beald\b"#,
        #"\besl\b"#,
        #"\bdemographic\b"#,
        #"\bhome support\b"#,
        #"\bfuture performance\b"#,
        #"\bintelligence\b"#
    ]

    private static let finalGradeLanguagePatterns: [String] = [
        #"\bfinal grade\b"#,
        #"\bofficial grade\b"#,
        #"\bcertified score\b"#,
        #"\bthe student receives\b"#,
        #"\bi have graded\b"#
    ]

    private static func containsProhibitedInference(_ text: String) -> Bool {
        prohibitedInferencePatterns.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func containsFinalGradeLanguage(_ text: String) -> Bool {
        var normalized = text.lowercased()
        normalized = normalized.replacingOccurrences(of: "not a final grade", with: "")
        normalized = normalized.replacingOccurrences(of: "not final grade", with: "")
        normalized = normalized.replacingOccurrences(of: "not the final grade", with: "")
        return finalGradeLanguagePatterns.contains { pattern in
            normalized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }
}
