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

struct FeedbackRewriteInput: Codable, Equatable {
    var assignmentID: UUID
    var mode: FeedbackRewriteMode
    var currentStudentFeedback: String
    var selectedTeacherNotes: String
    var gradeLevel: String
    var criteria: [FinalCriterionScore]
    var reviewedStudentText: String
    var packetFingerprint: String
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
