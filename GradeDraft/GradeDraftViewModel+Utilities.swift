import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
extension GradeDraftViewModel {
    func rubricPreview(for assignmentID: UUID) -> RubricImportPreview? {
        rubricPreviewsByAssignmentID[assignmentID]
    }

    static func importableText(from url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        if url.pathExtension.lowercased() == "xlsx" {
            return try xlsxSharedText(from: url)
        }
        throw GradeDraftError.persistenceFailed("Could not read imported curriculum/reference file as text.")
    }

    static func xlsxSharedText(from url: URL) throws -> String {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw GradeDraftError.persistenceFailed("Could not open local curriculum workbook as a ZIP-based XLSX file.")
        }
        var collected: [String] = []
        for entry in archive where entry.path.hasSuffix(".xml") {
            var data = Data()
            _ = try archive.extract(entry) { chunk in data.append(chunk) }
            guard let xml = String(data: data, encoding: .utf8) else { continue }
            let cleaned = xml
                .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
            collected.append(cleaned)
        }
        return collected.joined(separator: "\n")
    }

    static func summary(from text: String, sourceName: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let codePattern = #"\b[A-Z]{2,}[A-Z0-9]{3,}\b"#
        let codes = lines.flatMap { line -> [String] in
            guard let regex = try? NSRegularExpression(pattern: codePattern) else { return [] }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            return regex.matches(in: line, range: range).compactMap { match in
                Range(match.range, in: line).map { String(line[$0]) }
            }
        }
        let excerpts = lines.prefix(20).joined(separator: "\n")
        return """
        Source: \(sourceName)
        Import status: Teacher-provided local curriculum/reference material. Confirm against the official jurisdiction source before reporting.
        Detected codes: \(Array(Set(codes)).sorted().joined(separator: ", "))

        Excerpts:
        \(excerpts)
        """
    }
}
