import CommonCrypto
import CryptoKit
import Foundation
import Security

/// Turns the teacher's backup password into the 256-bit key that encrypts the full backup
/// (PBKDF2-HMAC-SHA256, random 16-byte salt, 600,000 rounds).
enum BackupKeyDerivation {
    static let saltLength = 16
    static let rounds: UInt32 = 600_000

    static func randomSalt() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: saltLength)
        guard SecRandomCopyBytes(kSecRandomDefault, saltLength, &bytes) == errSecSuccess else {
            throw BackupArchiveError.archiveFailed("The backup could not be encrypted (no random data available).")
        }
        return Data(bytes)
    }

    static func key(password: String, salt: Data) throws -> SymmetricKey {
        let passwordBytes = Array(password.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        let status = passwordBytes.withUnsafeBufferPointer { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBuffer.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) },
                    passwordBytes.count,
                    saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    rounds,
                    &derived,
                    derived.count
                )
            }
        }
        guard status == kCCSuccess else {
            throw BackupArchiveError.archiveFailed("The backup key could not be derived from the password.")
        }
        return SymmetricKey(data: derived)
    }
}
