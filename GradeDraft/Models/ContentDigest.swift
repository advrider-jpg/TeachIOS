import CryptoKit
import Foundation

/// SHA-256 digests, written as lower-case hex. Used for grading-packet fingerprints,
/// source-file digests, backup manifests and export records.
enum ContentDigest {
    private static let fileChunkSize = 1_048_576

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).hexString
    }

    /// Digest of the string's UTF-8 bytes.
    static func sha256Hex(_ string: String) -> String {
        sha256Hex(Data(string.utf8))
    }

    /// Digest of a file, read in 1 MB chunks so large scans and PDFs are never loaded whole.
    static func sha256Hex(fileAt url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: fileChunkSize), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().hexString
    }
}

private extension SHA256.Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
