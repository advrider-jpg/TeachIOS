import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

final class FoundationModelGradingService: GradingServicing, CapabilityChecking {
    var localAIStatus: LocalAIStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                return .unavailable(Self.message(for: reason))
            @unknown default:
                return .unavailable("The on-device language model is unavailable for an unknown reason.")
            }
        } else {
            return .unavailable("Foundation Models requires a newer operating system.")
        }
        #else
        return .unavailable("This build was compiled without the Foundation Models framework.")
        #endif
    }

    func draftGrade(input: GradingInput) async throws -> GradeDraftResult {
        try LocalOnlyGradingValidator.validate(input)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard localAIStatus == .available else {
                if case .unavailable(let message) = localAIStatus {
                    throw GradeDraftError.localModelUnavailable(message)
                }
                throw GradeDraftError.localModelUnavailable("The on-device language model is unavailable.")
            }

            let session = LanguageModelSession()
            let response = try await session.respond(to: PromptBuilder.gradingPrompt(input: input))
            let raw = response.content
            let parsed = try ModelGradeDraftResponse.parse(rawModelResponse: raw)
            return try GradeDraftValidator.normalizeAndValidate(parsed)
        } else {
            throw GradeDraftError.localModelUnavailable("Foundation Models requires a newer operating system.")
        }
        #else
        throw GradeDraftError.localModelUnavailable("This build was compiled without the Foundation Models framework.")
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is not enabled. Enable it in Settings to use local AI grading."
        case .deviceNotEligible:
            return "This device does not support the on-device language model required for local AI grading."
        case .modelNotReady:
            return "The on-device language model is not ready yet. Try again after the system finishes preparing it."
        @unknown default:
            return "The on-device language model is unavailable for an unknown reason."
        }
    }
    #endif
}

private struct ModelGradeDraftResponse: Decodable {
    var studentResponseSummary: String
    var criteria: [ModelCriterionScore]
    var studentFeedback: String
    var teacherNotes: String
    var uncertaintyFlags: [String]
    var complianceFlags: [String]?

    enum CodingKeys: String, CodingKey {
        case studentResponseSummary
        case studentResponseSummarySnake = "student_response_summary"
        case criteria
        case studentFeedback
        case studentFeedbackSnake = "student_feedback"
        case teacherNotes
        case teacherNotesSnake = "teacher_notes"
        case uncertaintyFlags
        case uncertaintyFlagsSnake = "uncertainty_flags"
        case complianceFlags
        case complianceFlagsSnake = "compliance_flags"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        studentResponseSummary = try container.decodeFlexibleString(forKeys: [.studentResponseSummary, .studentResponseSummarySnake], defaultValue: "")
        criteria = try container.decode([ModelCriterionScore].self, forKey: .criteria)
        studentFeedback = try container.decodeFlexibleString(forKeys: [.studentFeedback, .studentFeedbackSnake], defaultValue: "")
        teacherNotes = try container.decodeFlexibleString(forKeys: [.teacherNotes, .teacherNotesSnake], defaultValue: "")
        uncertaintyFlags = try container.decodeFlexibleStringArray(forKeys: [.uncertaintyFlags, .uncertaintyFlagsSnake], defaultValue: [])
        complianceFlags = try container.decodeFlexibleStringArray(forKeys: [.complianceFlags, .complianceFlagsSnake], defaultValue: [])
    }

    static func parse(rawModelResponse raw: String) throws -> GradeDraftResult {
        let jsonText = JSONExtractor.extractFirstJSONObject(from: raw)
        guard let data = jsonText.data(using: .utf8) else {
            throw GradeDraftError.malformedModelResponse("The response was not valid UTF-8 text.")
        }

        do {
            let decoded = try JSONDecoder().decode(ModelGradeDraftResponse.self, from: data)
            let criteria = decoded.criteria.map {
                CriterionScore(
                    criterion: $0.criterion,
                    rating: $0.rating,
                    proposedPoints: $0.proposedPoints,
                    maxPoints: $0.maxPoints,
                    evidence: $0.evidence,
                    explanation: $0.explanation,
                    teacherReviewRequired: $0.teacherReviewRequired
                )
            }

            return GradeDraftResult(
                studentResponseSummary: decoded.studentResponseSummary,
                criteria: criteria,
                totalScore: 0,
                maxScore: 0,
                studentFeedback: decoded.studentFeedback,
                teacherNotes: decoded.teacherNotes,
                uncertaintyFlags: decoded.uncertaintyFlags,
                complianceFlags: decoded.complianceFlags ?? [],
                rawModelResponse: raw
            )
        } catch {
            throw GradeDraftError.malformedModelResponse(error.localizedDescription)
        }
    }
}

private struct ModelCriterionScore: Decodable {
    var criterion: String
    var rating: String
    var proposedPoints: Double
    var maxPoints: Double
    var evidence: [String]
    var explanation: String
    var teacherReviewRequired: Bool

    enum CodingKeys: String, CodingKey {
        case criterion
        case rating
        case proposedPoints
        case proposedPointsSnake = "proposed_points"
        case maxPoints
        case maxPointsSnake = "max_points"
        case evidence
        case explanation
        case teacherReviewRequired
        case teacherReviewRequiredSnake = "teacher_review_required"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        criterion = try container.decodeFlexibleString(forKeys: [.criterion], defaultValue: "")
        rating = try container.decodeFlexibleString(forKeys: [.rating], defaultValue: "")
        proposedPoints = try container.decodeFlexibleDouble(forKeys: [.proposedPoints, .proposedPointsSnake], defaultValue: 0)
        maxPoints = try container.decodeFlexibleDouble(forKeys: [.maxPoints, .maxPointsSnake], defaultValue: 0)
        evidence = try container.decodeFlexibleStringArray(forKeys: [.evidence], defaultValue: [])
        explanation = try container.decodeFlexibleString(forKeys: [.explanation], defaultValue: "")
        teacherReviewRequired = try container.decodeFlexibleBool(forKeys: [.teacherReviewRequired, .teacherReviewRequiredSnake], defaultValue: true)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKeys keys: [Key], defaultValue: String) throws -> String {
        for key in keys where contains(key) {
            if let value = try? decode(String.self, forKey: key) {
                return value
            }
        }
        return defaultValue
    }

    func decodeFlexibleStringArray(forKeys keys: [Key], defaultValue: [String]) throws -> [String] {
        for key in keys where contains(key) {
            if let value = try? decode([String].self, forKey: key) {
                return value
            }
            if let value = try? decode(String.self, forKey: key) {
                return [value]
            }
        }
        return defaultValue
    }

    func decodeFlexibleDouble(forKeys keys: [Key], defaultValue: Double) throws -> Double {
        for key in keys where contains(key) {
            if let value = try? decode(Double.self, forKey: key) {
                return value
            }
            if let value = try? decode(Int.self, forKey: key) {
                return Double(value)
            }
            if let value = try? decode(String.self, forKey: key), let parsed = Double(value) {
                return parsed
            }
        }
        return defaultValue
    }

    func decodeFlexibleBool(forKeys keys: [Key], defaultValue: Bool) throws -> Bool {
        for key in keys where contains(key) {
            if let value = try? decode(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decode(String.self, forKey: key) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "true", "yes", "1":
                    return true
                case "false", "no", "0":
                    return false
                default:
                    break
                }
            }
        }
        return defaultValue
    }
}

enum JSONExtractor {
    static func extractFirstJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{") else {
            return trimmed
        }

        var depth = 0
        var isInsideString = false
        var isEscaped = false
        var index = start

        while index < trimmed.endIndex {
            let character = trimmed[index]

            if isEscaped {
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                isInsideString.toggle()
            } else if !isInsideString {
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(trimmed[start...index])
                    }
                }
            }

            index = trimmed.index(after: index)
        }

        return trimmed
    }
}
