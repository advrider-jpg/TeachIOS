import CoreGraphics
import Foundation
import UIKit

/// A failure or result a model shows in its own alert. There is no app-wide error slot.
struct AlertMessage: Identifiable, Equatable, Sendable {
    let id = UUID()
    var title: String
    var message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    init(title: String, error: any Error) {
        self.init(title: title, message: error.localizedDescription)
    }
}

/// An export file waiting in `tmp/Exports/` to be previewed and shared. The model that prepared it
/// deletes the file when sharing finishes or another export is prepared.
struct PreparedExport: Identifiable, Equatable, Sendable {
    let id = UUID()
    var kind: ExportKind
    var url: URL
    /// What the share sheet and confirmation header name, for example "Student Report — Ava Chen, Persuasive essay".
    var title: String
}

/// The import work a submission's student-work actions need. `SourceImportService` is the production
/// implementation; tests supply a double.
protocol SourceImporting: Sendable {
    func importScannedImages(_ images: [CGImage], submissionID: UUID) async throws -> ImportedInput
    func importPhotos(_ imageData: [Data], submissionID: UUID) async throws -> ImportedInput
    func importPDF(at url: URL, submissionID: UUID) async throws -> ImportedInput
}

extension SourceImportService: SourceImporting {}

/// The services the app's models call. `live()` is the device configuration; tests and previews pass doubles.
struct AppServices {
    var grading: any GradingServicing & CapabilityChecking
    var budgeter: any GradingPromptBudgeting
    var rubricSuggestions: RubricSuggestionService
    var curriculumCatalog: CurriculumCatalogService
    var curriculumSuggestions: CurriculumSuggestionService
    var exportAuthentication: any ExportAuthenticationServicing
    /// Builds the importer once storage is open; the argument is `AppDatabase.storageDirectory`.
    var makeImporter: @Sendable (URL) -> any SourceImporting

    @MainActor
    static func live() -> AppServices {
        let generator = SystemModelDraftGenerator()
        let catalog = CurriculumCatalogService()
        return AppServices(
            grading: FoundationModelGradingService(generator: generator),
            budgeter: GradingPromptBudgeter(),
            rubricSuggestions: RubricSuggestionService(generator: generator),
            curriculumCatalog: catalog,
            curriculumSuggestions: CurriculumSuggestionService(catalog: catalog, generator: generator),
            exportAuthentication: LocalExportAuthenticationService(),
            makeImporter: { root in SourceImportService(sourcesRoot: root.appendingPathComponent("Sources", isDirectory: true)) }
        )
    }

    /// Asks for device authentication when the export kind's policy requires it. Returns the failure
    /// message to show, or nil when the export may continue.
    @MainActor
    func authenticateIfRequired(for kind: ExportKind) async -> String? {
        guard kind.contentPolicy.requiresLocalAuthenticationWhenAvailable else { return nil }
        let result = await exportAuthentication.authenticateForSensitiveExport(
            reason: "Authenticate to create \(kind.displayName). This export may contain student records or teacher-only review data."
        )
        return result.allowed ? nil : (result.message ?? "Export canceled because device authentication was not completed.")
    }
}

/// Deletes source files that a store write handed back (replaced or deleted submissions). A file that
/// cannot be deleted is reported, not ignored.
enum SourceFileCleanup {
    /// Returns the paths that could not be deleted.
    static func delete(_ relativePaths: [String], storageRoot: URL, fileManager: FileManager = .default) -> [String] {
        var failed: [String] = []
        for path in relativePaths {
            guard let url = SourcePathSafety.resolvedLocalSourceURL(path, applicationSupportDirectory: storageRoot) else {
                failed.append(path)
                continue
            }
            guard fileManager.fileExists(atPath: url.path) else { continue }
            do {
                try fileManager.removeItem(at: url)
            } catch {
                failed.append(path)
            }
        }
        return failed
    }

    static func failureMessage(_ failed: [String]) -> String {
        "The change was saved, but \(failed.count) old file(s) could not be deleted from this device: \(failed.joined(separator: ", "))"
    }
}

extension ExportKind {
    /// Text exports the teacher can copy to the clipboard; PDFs and archives cannot be.
    var canCopyAsText: Bool {
        self == .studentMarkdown || self == .teacherAuditMarkdown || self == .csvGradebook
    }
}

/// Copies a prepared text export to the clipboard. The screen has already shown the clipboard warning.
enum ExportClipboard {
    @MainActor
    static func copyText(of export: PreparedExport) throws {
        guard export.kind.canCopyAsText else {
            throw GradeDraftError.exportFailed("Clipboard copy is available only for text-based exports.")
        }
        let text = try String(contentsOf: export.url, encoding: .utf8)
        UIPasteboard.general.string = text
    }
}
