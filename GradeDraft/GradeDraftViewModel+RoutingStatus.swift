import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
extension GradeDraftViewModel {
    func refreshDeviceBackupPolicyStatus() {
        do {
            let directory = try store.applicationSupportDirectory()
            if let excluded = try LocalDataProtection.isExcludedFromBackup(directory) {
                deviceBackupPolicyStatus = excluded ? .excluded : .included
            } else {
                deviceBackupPolicyStatus = .unknown("The platform did not report an exclusion value for the local storage directory.")
            }
        } catch {
            deviceBackupPolicyStatus = .unknown(error.localizedDescription)
        }
    }

    func includeLocalDataInDeviceBackupAfterWarning() {
        do {
            try setApplicationSupportExcludedFromDeviceBackup(false, surfaceStatus: true)
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func keepLocalDataExcludedFromDeviceBackup() {
        do {
            try setApplicationSupportExcludedFromDeviceBackup(true, surfaceStatus: true)
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func setApplicationSupportExcludedFromDeviceBackup(_ excluded: Bool, surfaceStatus: Bool) throws {
        let directory = try store.applicationSupportDirectory()
        try LocalDataProtection.setExcludedFromBackup(excluded, for: directory)
        deviceBackupPolicyStatus = excluded ? .excluded : .included
        if surfaceStatus {
            statusMessage = excluded
                ? "Local student records remain excluded from device backup where supported."
                : "Local student records may now be included in device backup according to device settings."
        }
    }

    func assignmentRosterStatus(for record: AssignmentRecord) -> AssignmentRosterStatus {
        if record.finalReviewIsStale || record.latestDraftIsStale { return .needsRecheck }
        if record.finalReview?.status == .approved,
           record.exportRecords.contains(where: { $0.exportKind == .studentPDF || $0.exportKind == .studentMarkdown }) {
            return .exported
        }
        if record.finalReview?.status == .approved { return .approved }
        if record.finalReview != nil { return .finalReviewInProgress }
        if record.latestDraft != nil && !record.latestDraftIsStale { return .draftGenerated }
        if record.ocrReviewStatus.blocksGrading { return .ocrReviewNeeded }
        if record.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return record.sourceInputs.isEmpty ? .sourceNeeded : .ocrReviewNeeded }
        if record.hasGradingStandard { return .readyForGrading }
        return .notStarted
    }

    func refreshCapabilityStatus() {
        switch gradingService.localAIStatus {
        case .available:
            statusMessage = "Local AI is available on this device. Student work stays on device."
            (gradingService as? FoundationModelGradingService)?.prewarmIfAvailable()
        case .unavailable(let message):
            statusMessage = message
        }
        refreshAIReadiness()
    }

    @discardableResult
    func selectAssignment(_ id: UUID) -> Bool {
        guard assignments.contains(where: { $0.id == id }) else {
            clearPreparedExport()
            selectedAssignmentID = nil
            errorMessage = "Assignment could not be opened because it is not saved on this device."
            return false
        }
        selectedAssignmentID = id
        clearPreparedExport()
        refreshCapabilityStatus()
        return true
    }

    func currentSavedAssignmentForAction(_ actionName: String) -> AssignmentRecord? {
        guard let selectedAssignmentID,
              let record = assignments.first(where: { $0.id == selectedAssignmentID }) else {
            clearPreparedExport()
            errorMessage = "\(actionName) is unavailable because no saved assignment is selected."
            return nil
        }
        return record
    }

    func publishPreparedExport(_ url: URL, kind: ExportKind, assignmentID: UUID?) {
        exportURL = url
        exportKind = kind
        preparedExportArtifact = PreparedExportArtifact(
            assignmentID: assignmentID,
            kind: kind,
            url: url,
            createdAt: Date()
        )
    }

    func clearPreparedExport() {
        exportURL = nil
        exportKind = nil
        preparedExportArtifact = nil
    }

    func handleLaunchRequest(_ request: AppLaunchRequest) {
        if let assignmentID = request.assignmentID {
            guard assignments.contains(where: { $0.id == assignmentID }) else {
                errorMessage = "Shortcut could not open that assignment because it is not saved on this device."
                return
            }
            selectAssignment(assignmentID)
        }
        switch request.action {
        case .createAssignmentShell:
            newAssignment()
            statusMessage = "Assignment shell created locally from Shortcut. Add student work and grading materials before drafting."
        case .preparePacketPreview:
            buildAIPacketPreview()
        case .startManualFinalReview:
            startManualFinalReview()
        case .applyRecommendedAIConstraints:
            applyRecommendedAIConstraintTemplates()
            buildAIPacketPreview()
        case .applyPastedStudentText:
            guard request.assignmentID != nil else {
                errorMessage = "Shortcut must choose an assignment before saving pasted student work."
                return
            }
            let text = request.payloadText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else {
                errorMessage = "Shortcut did not include student work text to save."
                return
            }
            if applyPastedStudentText(text) {
                statusMessage = "Pasted student work was saved locally from Shortcut. Review setup before drafting feedback."
            }
        case .none:
            if let assignmentID = request.assignmentID, assignments.contains(where: { $0.id == assignmentID }) {
                statusMessage = "Opened assignment locally. Student work stays on this device."
            }
        }
    }
}
