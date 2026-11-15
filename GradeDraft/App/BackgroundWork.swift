import Foundation
import Observation

enum WorkKind: String, Sendable {
    case scan
    case photoImport
    case pdfImport
    case draft
    case feedbackRewrite

    var displayName: String {
        switch self {
        case .scan: return "Reading scanned pages"
        case .photoImport: return "Reading photos"
        case .pdfImport: return "Importing PDF"
        case .draft: return "Drafting feedback locally"
        case .feedbackRewrite: return "Rewriting feedback locally"
        }
    }
}

/// Slow per-submission jobs. A job keeps running when the teacher leaves the screen that started it and
/// writes through `AppDatabase` by the submission ID it was started with. One job per submission at a time.
@Observable @MainActor
final class BackgroundWork {
    private(set) var running: [UUID: WorkKind] = [:]
    /// The last job failure per submission, shown by that submission's screens until dismissed.
    private(set) var failures: [UUID: AlertMessage] = [:]

    @ObservationIgnored private var tasks: [UUID: Task<Void, Never>] = [:]

    /// Starts the job unless one is already running for the submission. Returns whether it started.
    /// A cancelled job records no failure.
    @discardableResult
    func start(_ kind: WorkKind, submissionID: UUID, operation: @escaping @Sendable () async throws -> Void) -> Bool {
        guard running[submissionID] == nil else { return false }
        running[submissionID] = kind
        failures[submissionID] = nil
        tasks[submissionID] = Task { [weak self] in
            do {
                try await operation()
            } catch is CancellationError {
            } catch DraftFailure.cancelled {
            } catch {
                self?.failures[submissionID] = AlertMessage(title: "\(kind.displayName) failed", error: error)
            }
            self?.running[submissionID] = nil
            self?.tasks[submissionID] = nil
        }
        return true
    }

    func kind(for submissionID: UUID) -> WorkKind? {
        running[submissionID]
    }

    func cancel(submissionID: UUID) {
        tasks[submissionID]?.cancel()
    }

    func clearFailure(submissionID: UUID) {
        failures[submissionID] = nil
    }

    /// Waits until the submission's current job (if any) has finished.
    func waitUntilFinished(submissionID: UUID) async {
        await tasks[submissionID]?.value
    }
}
