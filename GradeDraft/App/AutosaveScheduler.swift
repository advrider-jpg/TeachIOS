import Foundation
import Observation

/// The one editing rule (plan 3.5): fields edit the model's local copy; the save runs 0.6 s after the
/// last edit, or at once on `flushNow()` (screen disappears, app goes to the background, or an action
/// that needs the saved value). While edits are pending, the owning model does not let incoming
/// observation values overwrite its local copy.
@Observable @MainActor
final class AutosaveScheduler {
    static let defaultDelay: Duration = .milliseconds(600)

    private(set) var hasPendingChanges = false
    private(set) var isSaving = false

    @ObservationIgnored private let delay: Duration
    @ObservationIgnored private let save: @MainActor () async -> Void
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var inFlight: Task<Void, Never>?

    /// `save` writes the owning model's current local value and handles its own failure.
    init(delay: Duration = AutosaveScheduler.defaultDelay, save: @escaping @MainActor () async -> Void) {
        self.delay = delay
        self.save = save
    }

    /// True while the local copy must not be replaced by an observed value.
    var holdsLocalEdits: Bool { hasPendingChanges || isSaving }

    /// Call after every local edit.
    func schedule() {
        hasPendingChanges = true
        timer?.cancel()
        timer = Task { [weak self, delay] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self else { return }
            // Cleared first so `flushNow` does not cancel the task that is running the save
            // (GRDB's async writes stop on cancellation).
            self.timer = nil
            await self.flushNow()
        }
    }

    /// Saves now if anything is pending.
    /// Saves run one at a time, in order: a flush waits for any save already running, then saves the
    /// latest local value if edits are still pending.
    func flushNow() async {
        timer?.cancel()
        timer = nil
        while let running = inFlight { await running.value }
        guard hasPendingChanges else { return }
        hasPendingChanges = false
        isSaving = true
        let task = Task { @MainActor [save] in await save() }
        inFlight = task
        await task.value
        inFlight = nil
        isSaving = false
    }

    /// Drops pending edits without saving (used after a failed save rolls the local copy back).
    func discardPending() {
        timer?.cancel()
        timer = nil
        hasPendingChanges = false
    }
}
