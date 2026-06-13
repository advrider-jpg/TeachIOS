import CoreGraphics
import Foundation

// MARK: - Templates and errors

struct RubricTemplate: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var assignmentType: AssignmentType
    var assessmentPurpose: AssessmentPurpose
    var description: String
    var rubricText: String
    var customInstructions: String
}

enum RubricTemplates {
    static var builtIn: [RubricTemplate] {
        RubricTemplateCatalog.builtIn
    }
}

enum GradeDraftError: LocalizedError, Equatable {
    case missingRubric
    case missingStudentText
    case ocrReviewRequired
    case localModelUnavailable(String)
    case malformedModelResponse(String)
    case invalidModelGrade(String)
    case promptTooLargeForLocalModel(String)
    case localModelGenerationFailed(String)
    case ocrFailed(String)
    case persistenceFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRubric:
            return "Add a rubric, answer key, or exemplar before drafting a feedback suggestion."
        case .missingStudentText:
            return "Add or review the student text before drafting a feedback suggestion."
        case .ocrReviewRequired:
            return "Review scanned text before drafting feedback."
        case .localModelUnavailable(let message):
            return message
        case .malformedModelResponse(let message):
            return "The local model returned a response the app could not parse: \(message)"
        case .invalidModelGrade(let message):
            return "The local model returned an invalid grade draft: \(message)"
        case .promptTooLargeForLocalModel(let message):
            return message
        case .localModelGenerationFailed(let message):
            return message
        case .ocrFailed(let message):
            return "Text recognition failed: \(message)"
        case .persistenceFailed(let message):
            return "Could not save local data: \(message)"
        case .exportFailed(let message):
            return "Could not export the local report: \(message)"
        }
    }
}
