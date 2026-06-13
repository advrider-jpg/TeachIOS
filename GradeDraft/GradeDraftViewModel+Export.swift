import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
extension GradeDraftViewModel {
    func authenticateForExportIfNeeded(_ exportKind: ExportKind) async -> Bool {
        guard exportKind.contentPolicy.requiresLocalAuthenticationWhenAvailable else {
            lastExportAuthenticationResult = nil
            return true
        }
        let reason = "Authenticate to create \(exportKind.displayName). This export may contain student records or teacher-only review data."
        let result = await exportAuthenticationService.authenticateForSensitiveExport(reason: reason)
        lastExportAuthenticationResult = result
        guard result.allowed else {
            clearPreparedExport()
            errorMessage = result.message ?? "Export canceled because device authentication was not completed."
            return false
        }
        if let message = result.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            statusMessage = message
        }
        return true
    }

    func performConfirmedExport(_ confirmationKind: ExportConfirmationKind) async {
        guard currentSavedAssignmentForAction("\(confirmationKind.title) export") != nil else { return }
        let exportKind = confirmationKind.exportKind
        guard await authenticateForExportIfNeeded(exportKind) else { return }
        switch confirmationKind {
        case .studentReportMarkdown:
            exportStudentReport()
        case .teacherReviewMarkdown:
            exportTeacherAuditReport()
        case .studentReportPDF:
            exportStudentPDF()
        case .teacherReviewPDF:
            exportTeacherAuditPDF()
        case .teacherArchive:
            exportArchiveBundle()
        case .gradebookCSV:
            exportCSVGradebook()
        case .gradebookArchive:
            exportGradebookArchive()
        case .fullBackup:
            exportBackupJSON()
        }
    }

    func exportTeacherAuditReport() {
        guard let currentAssignment = currentSavedAssignmentForAction("Teacher Record Markdown export") else { return }
        do {
            let generatedAt = Date()
            let markdown = MarkdownReportBuilder.teacherAuditMarkdown(for: currentAssignment, generatedAt: generatedAt)
            let url = try MarkdownReportBuilder.writeTemporaryTeacherAuditReport(for: currentAssignment, generatedAt: generatedAt)
            guard recordExport(kind: .teacherAuditMarkdown, content: markdown, includesPrivateNotes: true, includesOriginalSources: false) else { return }
            publishPreparedExport(url, kind: .teacherAuditMarkdown, assignmentID: currentAssignment.id)
            statusMessage = "Teacher Record is ready to share. Treat it as sensitive."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportCSVGradebook() {
        guard let currentAssignment = currentSavedAssignmentForAction("Gradebook CSV export") else { return }
        do {
            let records = gradebookAssignments.isEmpty ? [currentAssignment] : gradebookAssignments
            let csv = CSVExportService.exportedCSV(from: records)
            let destination = temporaryExportURL(kind: .csvGradebook, extension: "csv", assignmentID: currentAssignment.id)
            try csv.write(to: destination, atomically: true, encoding: .utf8)
            ExportFileHardening.applyBestEffortProtection(to: destination)
            guard recordExport(kind: .csvGradebook, content: csv, includesPrivateNotes: false, includesOriginalSources: false) else { return }
            publishPreparedExport(destination, kind: .csvGradebook, assignmentID: nil)
            statusMessage = "Gradebook CSV is ready to share. Treat it as a teacher-only record."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportGradebookArchive() {
        guard let currentAssignment = currentSavedAssignmentForAction("Gradebook archive export") else { return }
        do {
            let records = gradebookAssignments.isEmpty ? [currentAssignment] : gradebookAssignments
            let archiveSourceFiles = try records.flatMap { try sourceFilesForSensitiveArchive(for: $0) }
            let destination = temporaryExportURL(kind: .assignmentGradebookArchive, extension: "zip", assignmentID: currentAssignment.id)
            let url = try BundleExportService.writeAssignmentArchive(assignments: records, sourceFiles: archiveSourceFiles, to: destination)
            guard recordExport(kind: .assignmentGradebookArchive, fileURL: url, includesPrivateNotes: true, includesOriginalSources: !archiveSourceFiles.isEmpty) else { return }
            publishPreparedExport(url, kind: .assignmentGradebookArchive, assignmentID: nil)
            statusMessage = "Gradebook archive ZIP is ready to share. Treat it as sensitive teacher-only student data."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportClassGradebookCSV(for className: String) async {
        guard let currentAssignment = currentSavedAssignmentForAction("Class gradebook CSV export") else { return }
        guard await authenticateForExportIfNeeded(.csvGradebook) else { return }
        let scoped = classAssignments(for: className)
        let records = scoped.isEmpty ? [currentAssignment] : scoped
        do {
            let csv = CSVExportService.exportedCSV(from: records)
            let destination = temporaryExportURL(kind: .csvGradebook, extension: "csv", assignmentID: currentAssignment.id)
            try csv.write(to: destination, atomically: true, encoding: .utf8)
            ExportFileHardening.applyBestEffortProtection(to: destination)
            guard recordExport(kind: .csvGradebook, content: csv, includesPrivateNotes: false, includesOriginalSources: false) else { return }
            publishPreparedExport(destination, kind: .csvGradebook, assignmentID: nil)
            statusMessage = "Class gradebook CSV is ready to share. Treat it as a teacher-only record."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportClassArchive(for className: String) async {
        guard let currentAssignment = currentSavedAssignmentForAction("Class gradebook archive export") else { return }
        guard await authenticateForExportIfNeeded(.assignmentGradebookArchive) else { return }
        let scoped = classAssignments(for: className)
        let records = scoped.isEmpty ? [currentAssignment] : scoped
        do {
            let archiveSourceFiles = try records.flatMap { try sourceFilesForSensitiveArchive(for: $0) }
            let destination = temporaryExportURL(kind: .assignmentGradebookArchive, extension: "zip", assignmentID: currentAssignment.id)
            let url = try BundleExportService.writeAssignmentArchive(assignments: records, sourceFiles: archiveSourceFiles, to: destination)
            guard recordExport(kind: .assignmentGradebookArchive, fileURL: url, includesPrivateNotes: true, includesOriginalSources: !archiveSourceFiles.isEmpty) else { return }
            publishPreparedExport(url, kind: .assignmentGradebookArchive, assignmentID: nil)
            statusMessage = "Class gradebook archive ZIP is ready to share. Treat it as sensitive teacher-only student data."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportArchiveBundle() {
        guard let currentAssignment = currentSavedAssignmentForAction("Teacher archive export") else { return }
        do {
            let sourceFiles = try sourceFilesForSensitiveArchive(for: currentAssignment)
            let destination = try BundleExportService.preflightDestination(for: currentAssignment.id)
            let url = try BundleExportService.writeTeacherAuditArchive(assignment: currentAssignment, sourceFiles: sourceFiles, to: destination)
            guard recordExport(kind: .zipArchive, fileURL: url, includesPrivateNotes: true, includesOriginalSources: !sourceFiles.isEmpty) else { return }
            publishPreparedExport(url, kind: .zipArchive, assignmentID: currentAssignment.id)
            statusMessage = "Teacher archive ZIP is ready to share. Treat it as sensitive."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportBackupJSON() {
        guard let currentAssignment = currentSavedAssignmentForAction("Full backup export") else { return }
        do {
            let destination = temporaryExportURL(kind: .fullBackupArchive, extension: "zip", assignmentID: currentAssignment.id)
            let sourceFilesForBackup = try assignments.flatMap { try sourceFilesForSensitiveArchive(for: $0) }
            let url = try BundleExportService.writeFullBackup(assignments: assignments, sourceFiles: sourceFilesForBackup, to: destination, classGroups: classGroups, students: students, rosterEntries: assignmentRosterEntries)
            guard recordExport(kind: .fullBackupArchive, fileURL: url, includesPrivateNotes: true, includesOriginalSources: !sourceFilesForBackup.isEmpty) else { return }
            publishPreparedExport(url, kind: .fullBackupArchive, assignmentID: nil)
            statusMessage = "Full local backup archive is ready to share. Treat it as sensitive student data."
        } catch {
            handleExportFailure(error)
        }
    }

    func copyPreparedExportTextToClipboard() {
        guard currentSavedAssignmentForAction("Clipboard copy") != nil else { return }
        guard let exportURL, let exportKind else {
            errorMessage = "Create an export before copying text."
            return
        }
        guard clipboardTextExportKinds.contains(exportKind) else {
            errorMessage = "Clipboard copy is available only for text-based exports."
            return
        }
        do {
            let text = try String(contentsOf: exportURL, encoding: .utf8)
            UIPasteboard.general.string = text
            updateAssignment { assignment in
                assignment.appendAuditEvent(.exportPrepared, detail: "Copied \(exportKind.displayName) text to clipboard after the clipboard warning.")
            }
            guard persistOrSurfaceError() else { return }
            statusMessage = "Export text copied to the clipboard. Share only through approved channels."
        } catch {
            errorMessage = GradeDraftError.exportFailed(error.localizedDescription).localizedDescription
        }
    }

    func exportRiskSummary(for exportKind: ExportKind) -> ExportRiskSummary {
        ExportRiskSummary.summary(
            for: exportKind,
            currentAssignment: assignment,
            allAssignments: gradebookAssignments,
            sourceAvailability: { record in
                !self.sourceFiles(for: record).isEmpty
            }
        )
    }

    func recordExport(kind: ExportKind, content: String, includesPrivateNotes: Bool, includesOriginalSources: Bool) -> Bool {
        appendExportRecord(
            kind: kind,
            contentFingerprint: StableFingerprint.fingerprint(Data(content.utf8)),
            includesPrivateNotes: includesPrivateNotes,
            includesOriginalSources: includesOriginalSources
        )
    }

    func recordExport(kind: ExportKind, fileURL: URL, includesPrivateNotes: Bool, includesOriginalSources: Bool) -> Bool {
        do {
            let data = try Data(contentsOf: fileURL)
            return appendExportRecord(
                kind: kind,
                contentFingerprint: StableFingerprint.fingerprint(data),
                includesPrivateNotes: includesPrivateNotes,
                includesOriginalSources: includesOriginalSources
            )
        } catch {
            clearPreparedExport()
            errorMessage = "MarkForMe could not create the export. No file was shared. Could not fingerprint the exported file."
            return false
        }
    }

    func appendExportRecord(kind: ExportKind, contentFingerprint: String, includesPrivateNotes: Bool, includesOriginalSources: Bool) -> Bool {
        guard currentSavedAssignmentForAction("Export audit record") != nil else {
            clearPreparedExport()
            return false
        }
        updateAssignment { assignment in
            assignment.exportRecords.append(
                ExportRecord(
                    exportKind: kind,
                    contentFingerprint: contentFingerprint,
                    includesPrivateTeacherNotes: includesPrivateNotes,
                    includesOriginalSources: includesOriginalSources
                )
            )
            assignment.appendAuditEvent(.exportPrepared, detail: "Prepared \(kind.rawValue). Includes private notes: \(includesPrivateNotes ? "yes" : "no"). Includes original sources: \(includesOriginalSources ? "yes" : "no").")
        }
        guard persistOrSurfaceError() else {
            clearPreparedExport()
            return false
        }
        return true
    }

    func handleExportFailure(_ error: Error) {
        clearPreparedExport()
        let detail = error.localizedDescription.replacingOccurrences(of: fileManager.temporaryDirectory.path, with: "[temporary directory]")
        errorMessage = "MarkForMe could not create the export. No file was shared. \(detail)"
    }

    func temporaryExportURL(kind: ExportKind, extension ext: String, assignmentID: UUID? = nil) -> URL {
        let filename = ExportFilenameBuilder.filename(kind: kind, assignmentID: assignmentID ?? assignment.id, extension: ext)
        return fileManager.temporaryDirectory.appendingPathComponent(filename)
    }
}
