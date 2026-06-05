import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoundationModelErrorMapper {
    static func isContextWindowError(_ error: Error) -> Bool {
        let combined = "\(String(describing: error)) \(error.localizedDescription)".lowercased()
        return combined.contains("exceededcontextwindowsize")
            || combined.contains("context window")
            || combined.contains("too many tokens")
    }

    static func map(_ error: Error) -> GradeDraftError {
        if let gradeDraftError = error as? GradeDraftError {
            return gradeDraftError
        }
        if Task.isCancelled || error is CancellationError {
            return .localModelGenerationFailed("The local AI draft was cancelled.")
        }

        let description = String(describing: error)
        let localized = error.localizedDescription
        let combined = "\(description) \(localized)".lowercased()

        if isContextWindowError(error) {
            return .promptTooLargeForLocalModel("This grading packet is too large for the on-device model. Mark My Work did not truncate the student work or send it to a cloud model. Shorten or split the reviewed text, reduce the grading packet, or use manual final review.")
        }

        if combined.contains("safety") || combined.contains("guardrail") || combined.contains("refus") {
            return .invalidModelGrade("The local model could not produce a safe draft. Continue with manual final review.")
        }

        return .localModelGenerationFailed("The local model could not complete the draft: \(localized)")
    }
}
