import Foundation

import FoundationModels

/// Why an on-device model request did not produce a result. Each case carries the message the teacher sees.
enum DraftFailure: LocalizedError, Equatable, Sendable {
    case contextTooLarge
    case assetsNotReady
    case rateLimited
    case busy
    case refused
    case guardrail
    case unsupportedLanguage
    case timeout
    case cancelled
    case other(String)

    static let contextTooLargeMessage = "This grading packet is too large for the on-device model. MarkForMe did not truncate the student work or send it to a cloud model. Shorten or split the reviewed text, reduce the grading packet, or use manual final review."

    var errorDescription: String? {
        switch self {
        case .contextTooLarge:
            return Self.contextTooLargeMessage
        case .assetsNotReady:
            return "The on-device model is still downloading. Try again later."
        case .rateLimited, .busy:
            return "The on-device model is busy. Try again in a moment."
        case .refused, .guardrail:
            return "The local model could not produce a safe draft. Continue with manual final review."
        case .unsupportedLanguage:
            return "The on-device model can't read this language. Use manual review."
        case .timeout:
            return "The on-device model took too long to respond. Try again, or use manual review."
        case .cancelled:
            return "The local AI draft was cancelled."
        case .other(let detail):
            return "The local model could not complete the draft: \(detail)"
        }
    }
}

/// Translates the iOS 27 Foundation Models error types into `DraftFailure`.
enum FoundationModelErrorMapper {
    static func map(_ error: any Error) -> DraftFailure {
        if let failure = error as? DraftFailure {
            return failure
        }
        if error is CancellationError {
            return .cancelled
        }
        if let modelError = error as? LanguageModelError {
            switch modelError {
            case .contextSizeExceeded:
                return .contextTooLarge
            case .rateLimited:
                return .rateLimited
            case .refusal:
                return .refused
            case .timeout:
                return .timeout
            case .guardrailViolation:
                return .guardrail
            case .unsupportedLanguageOrLocale:
                return .unsupportedLanguage
            case .unsupportedCapability, .unsupportedTranscriptContent, .unsupportedGenerationGuide:
                return .other(modelError.localizedDescription)
            @unknown default:
                return .other(modelError.localizedDescription)
            }
        }
        if let systemError = error as? SystemLanguageModel.Error {
            switch systemError {
            case .assetsUnavailable:
                return .assetsNotReady
            @unknown default:
                return .other(systemError.localizedDescription)
            }
        }
        if let sessionError = error as? LanguageModelSession.Error {
            switch sessionError {
            case .concurrentRequests:
                return .busy
            case .transcriptMutationWhileResponding:
                return .other(sessionError.localizedDescription)
            @unknown default:
                return .other(sessionError.localizedDescription)
            }
        }
        return .other(error.localizedDescription)
    }
}
