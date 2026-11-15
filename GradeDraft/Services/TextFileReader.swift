import Foundation

/// Reads a teacher-supplied text file. Foundation detects the encoding (UTF-8, UTF-16 and
/// other byte-order-marked files); files it cannot identify are read as Windows-1252, which
/// is what Excel and Windows tools save as "CSV" or "text". A leading byte-order mark is removed.
enum TextFileReader {
    static func read(_ url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        var encoding = String.Encoding.utf8
        let text: String
        if let detected = try? String(contentsOf: url, usedEncoding: &encoding) {
            text = detected
        } else {
            text = try String(contentsOf: url, encoding: .windowsCP1252)
        }
        return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }
}
