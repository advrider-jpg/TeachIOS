import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
extension GradeDraftViewModel {
    func applyScannedImages(_ images: [UIImage]) async {
        await applyImages(images, sourceType: .scan)
    }

    func applyPhotoImages(_ images: [UIImage]) async {
        await applyImages(images, sourceType: .photo)
    }

    func applyImages(_ images: [UIImage], sourceType: SourceType) async {
        guard !images.isEmpty else { return }
        guard let currentAssignment = currentSavedAssignmentForAction("\(sourceType.displayName) import") else { return }
        isWorking = true
        errorMessage = nil
        clearPreparedExport()
        defer { isWorking = false }
        var newlyPersistedSources: [SourceInputRef] = []

        do {
            let sourceRefs = try persistSourceImages(images, sourceType: sourceType, assignmentID: currentAssignment.id)
            newlyPersistedSources = sourceRefs
            var document = try await ocrService.recognizeText(in: images)
            for index in document.pages.indices where index < sourceRefs.count {
                document.pages[index].sourceInputID = sourceRefs[index].id
            }
            document.reviewStatus = .needsReview

            updateAssignment { assignment in
                assignment.sourceInputs = sourceRefs
                assignment.ocrDocument = document
                assignment.ocrReviewStatus = .needsReview
                assignment.ocrReviewedAt = nil
                assignment.reviewedStudentText = document.combinedText
                assignment.latestDraft = nil
                assignment.finalReview = nil
                assignment.appendAuditEvent(.sourceCaptured, detail: "Captured \(images.count) \(sourceType.displayName.lowercased()) page(s) locally.")
                assignment.appendAuditEvent(.ocrCompleted, detail: document.qualitySummary.displaySummary)
            }
            try saveCurrentAssignment()
            statusMessage = "Text recognition complete. Review scanned text before drafting feedback."
        } catch {
            cleanupSourceFiles(newlyPersistedSources)
            errorMessage = error.localizedDescription
        }
    }

    func applyPDFFile(_ url: URL) async {
        guard let currentAssignment = currentSavedAssignmentForAction("PDF import") else { return }
        isWorking = true
        errorMessage = nil
        clearPreparedExport()
        defer { isWorking = false }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        var newlyPersistedSources: [SourceInputRef] = []

        do {
            guard let document = PDFDocument(url: url) else {
                throw GradeDraftError.ocrFailed("The selected PDF could not be opened.")
            }
            guard document.pageCount > 0 else {
                throw GradeDraftError.ocrFailed("The selected PDF did not contain any pages.")
            }

            let appDirectory = try store.applicationSupportDirectory()
            let sourceRoot = appDirectory
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent(currentAssignment.id.uuidString, isDirectory: true)
            let originalFolder = sourceRoot.appendingPathComponent("original", isDirectory: true)
            try fileManager.createDirectory(at: originalFolder, withIntermediateDirectories: true)
            let pdfID = UUID()
            let originalPDFURL = originalFolder.appendingPathComponent("\(pdfID.uuidString).pdf")
            if fileManager.fileExists(atPath: originalPDFURL.path) { try fileManager.removeItem(at: originalPDFURL) }
            try fileManager.copyItem(at: url, to: originalPDFURL)
            let pdfData = try Data(contentsOf: originalPDFURL)
            let originalPDFSource = SourceInputRef(
                id: pdfID,
                sourceType: .pdf,
                pageIndex: nil,
                localRelativePath: "Sources/\(currentAssignment.id.uuidString)/original/\(pdfID.uuidString).pdf",
                fileName: url.lastPathComponent,
                mimeType: "application/pdf",
                contentDigest: StableFingerprint.fingerprint(pdfData),
                digestAlgorithm: "fnv1a64",
                pdfPageCount: document.pageCount,
                teacherIncludedInExport: true
            )
            newlyPersistedSources.append(originalPDFSource)

            let digitalTextByPage = extractDigitalPDFText(document)
            let images = try renderPDFPages(document)
            guard !images.isEmpty else {
                throw GradeDraftError.ocrFailed("The selected PDF did not contain renderable pages.")
            }
            guard images.count == document.pageCount else {
                throw GradeDraftError.ocrFailed("The selected PDF could not render every page. No import was saved.")
            }
            var pageSourceRefs = try persistSourceImages(images, sourceType: .pdf, assignmentID: currentAssignment.id)
            for index in pageSourceRefs.indices {
                pageSourceRefs[index].fileName = "PDF page \(index + 1) render"
                pageSourceRefs[index].mimeType = "image/png"
                pageSourceRefs[index].pdfPageCount = document.pageCount
            }
            newlyPersistedSources.append(contentsOf: pageSourceRefs)

            let pagesNeedingOCR = PDFImportPlanner.pageIndexesNeedingOCR(digitalTextByPage: digitalTextByPage)
            var ocrPagesByIndex: [Int: OCRPage] = [:]
            if !pagesNeedingOCR.isEmpty {
                let imagesNeedingOCR = pagesNeedingOCR.compactMap { images[safe: $0] }
                var recognized = try await ocrService.recognizeText(in: imagesNeedingOCR)
                for recognizedIndex in recognized.pages.indices where recognizedIndex < pagesNeedingOCR.count {
                    let pageIndex = pagesNeedingOCR[recognizedIndex]
                    recognized.pages[recognizedIndex].pageIndex = pageIndex
                    if pageIndex < pageSourceRefs.count {
                        recognized.pages[recognizedIndex].sourceInputID = pageSourceRefs[pageIndex].id
                        recognized.pages[recognizedIndex].imageWidth = pageSourceRefs[pageIndex].imageWidth
                        recognized.pages[recognizedIndex].imageHeight = pageSourceRefs[pageIndex].imageHeight
                    }
                    ocrPagesByIndex[pageIndex] = recognized.pages[recognizedIndex]
                }
            }
            let ocrDocument = PDFImportPlanner.mergedDocument(
                digitalTextByPage: digitalTextByPage,
                sourceRefs: pageSourceRefs,
                recognizedOCRPagesByPageIndex: ocrPagesByIndex,
                pageCount: document.pageCount
            )

            var documentForReview = ocrDocument
            documentForReview.reviewStatus = .needsReview
            updateAssignment { assignment in
                assignment.sourceInputs = [originalPDFSource] + pageSourceRefs
                assignment.ocrDocument = documentForReview
                assignment.ocrReviewStatus = .needsReview
                assignment.ocrReviewedAt = nil
                assignment.reviewedStudentText = documentForReview.combinedText
                assignment.latestDraft = nil
                assignment.finalReview = nil
                assignment.appendAuditEvent(.sourceCaptured, detail: "Imported local PDF with \(document.pageCount) page(s); original PDF and rendered pages stored locally.")
                assignment.appendAuditEvent(.ocrCompleted, detail: documentForReview.qualitySummary.displaySummary)
            }
            try saveCurrentAssignment()
            statusMessage = "PDF imported. Review scanned text before drafting feedback."
        } catch {
            cleanupSourceFiles(newlyPersistedSources)
            errorMessage = error.localizedDescription
        }
    }

    func sourceImage(for source: SourceInputRef) -> UIImage? {
        guard let appDir = try? store.applicationSupportDirectory(),
              let url = SourcePathSafety.resolvedLocalSourceURL(source.localRelativePath, applicationSupportDirectory: appDir),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func sourceFiles(for assignment: AssignmentRecord) -> [URL] {
        guard let appDir = try? store.applicationSupportDirectory() else { return [] }
        return assignment.sourceInputs.compactMap { source in
            guard let url = SourcePathSafety.resolvedLocalSourceURL(source.localRelativePath, applicationSupportDirectory: appDir) else { return nil }
            return fileManager.fileExists(atPath: url.path) ? url : nil
        }
    }

    func sourceFilesForSensitiveArchive(for assignment: AssignmentRecord) throws -> [URL] {
        let appDir = try store.applicationSupportDirectory()
        var urls: [URL] = []
        for source in assignment.sourceInputs where source.teacherIncludedInExport {
            guard let relativePath = source.localRelativePath, !relativePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guard let url = SourcePathSafety.resolvedLocalSourceURL(relativePath, applicationSupportDirectory: appDir) else {
                throw GradeDraftError.persistenceFailed("Original source file reference for \(assignment.title) is unsafe and was not exported: \(relativePath).")
            }
            guard fileManager.fileExists(atPath: url.path) else {
                throw GradeDraftError.persistenceFailed("Original source file for \(assignment.title) is missing and the sensitive archive was not created: \(relativePath).")
            }
            urls.append(url)
        }
        return urls
    }

    func sourceFilesForCurrentAssignment() -> [URL] {
        guard let currentAssignment = currentSavedAssignmentForAction("Source file lookup") else { return [] }
        return sourceFiles(for: currentAssignment)
    }

    func exportTeacherAuditPDF() {
        guard let currentAssignment = currentSavedAssignmentForAction("Teacher Record PDF export") else { return }
        do {
            let destination = temporaryExportURL(kind: .teacherAuditPDF, extension: "pdf", assignmentID: currentAssignment.id)
            let url = try PDFExportService.teacherAuditPDF(for: currentAssignment, destination: destination)
            guard recordExport(kind: .teacherAuditPDF, fileURL: url, includesPrivateNotes: true, includesOriginalSources: false) else { return }
            publishPreparedExport(url, kind: .teacherAuditPDF, assignmentID: currentAssignment.id)
            statusMessage = "Teacher Record PDF is ready to share. Treat it as sensitive."
        } catch {
            handleExportFailure(error)
        }
    }

    func sanitizedLegacyRestoredAssignments(_ records: [AssignmentRecord]) -> [AssignmentRecord] {
        records.map { record in
            var copy = record
            copy.sourceInputs = copy.sourceInputs.map { source in
                var sourceCopy = source
                sourceCopy.localRelativePath = SourcePathSafety.sanitizedLocalSourcePath(source.localRelativePath)
                return sourceCopy
            }
            return copy
        }
    }

    func persistSourceImages(_ images: [UIImage], sourceType: SourceType, assignmentID: UUID) throws -> [SourceInputRef] {
        let appDirectory = try store.applicationSupportDirectory()
        let sourceDirectory = appDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(assignmentID.uuidString, isDirectory: true)
        try LocalDataProtection.prepareSensitiveDirectory(sourceDirectory, fileManager: fileManager)

        return try images.enumerated().map { index, image in
            guard let data = image.pngData() else {
                throw GradeDraftError.persistenceFailed("Could not serialize captured page \(index + 1).")
            }
            let filename = "page-\(index + 1)-\(UUID().uuidString).png"
            let url = sourceDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic])
            LocalDataProtection.protectSensitiveFile(url, fileManager: fileManager)
            let relativePath = "Sources/\(assignmentID.uuidString)/\(filename)"
            return SourceInputRef(
                sourceType: sourceType,
                pageIndex: index,
                localRelativePath: relativePath,
                contentDigest: StableFingerprint.fingerprint(data),
                digestAlgorithm: "fnv1a64",
                imageWidth: Double(image.size.width),
                imageHeight: Double(image.size.height),
                teacherIncludedInExport: false
            )
        }
    }

    func renderPDFPages(_ document: PDFDocument) throws -> [UIImage] {
        var images: [UIImage] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0
            let size = CGSize(width: max(bounds.width, 1) * scale, height: max(bounds.height, 1) * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                context.cgContext.saveGState()
                context.cgContext.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()
            }
            images.append(image)
        }
        return images
    }

    func extractDigitalPDFText(_ document: PDFDocument) -> [String] {
        (0..<document.pageCount).map { index in
            document.page(at: index)?.string ?? ""
        }
    }

    func readTextFile(_ url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .utf16) {
            return text
        }
        throw GradeDraftError.persistenceFailed("Could not read imported file as text.")
    }

    func evidenceSourceReference(page: OCRPage, line: OCRLine, evidenceID: UUID? = nil) -> String {
        let sourceID = page.sourceInputID?.uuidString ?? "unknown-source"
        let box = line.boundingBox
        let evidencePart = evidenceID.map { "evidence:\($0.uuidString):" } ?? ""
        return "\(evidencePart)source:\(sourceID):page:\(page.pageIndex):ocrLine:\(line.id.uuidString):bbox:\(box.x),\(box.y),\(box.width),\(box.height)"
    }

    func cleanupRestoredSourceFiles(_ relativePaths: [String]) {
        guard !relativePaths.isEmpty, let appDir = try? store.applicationSupportDirectory() else { return }
        for relativePath in relativePaths {
            guard let url = SourcePathSafety.resolvedLocalSourceURL(relativePath, applicationSupportDirectory: appDir) else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    func cleanupSourceFiles(_ sources: [SourceInputRef]) {
        guard !sources.isEmpty, let appDir = try? store.applicationSupportDirectory() else { return }
        for source in sources {
            guard let url = SourcePathSafety.resolvedLocalSourceURL(source.localRelativePath, applicationSupportDirectory: appDir) else { continue }
            try? fileManager.removeItem(at: url)
        }
    }
}
