import XCTest
@testable import GradeDraft

// MARK: - StableFingerprint tests

final class StableFingerprintTests: XCTestCase {
    func testFingerprintIsDeterministic() {
        let first = StableFingerprint.fingerprint(["hello", "world"])
        let second = StableFingerprint.fingerprint(["hello", "world"])
        XCTAssertEqual(first, second, "Same inputs must produce the same fingerprint")
    }

    func testFingerprintChangesWithInput() {
        let first = StableFingerprint.fingerprint(["hello"])
        let second = StableFingerprint.fingerprint(["world"])
        XCTAssertNotEqual(first, second, "Different inputs must produce different fingerprints")
    }

    func testFingerprintOrderMatters() {
        let forward = StableFingerprint.fingerprint(["a", "b"])
        let reversed = StableFingerprint.fingerprint(["b", "a"])
        XCTAssertNotEqual(forward, reversed, "Different order must produce different fingerprints")
    }

    func testFingerprintEmptyArray() {
        let result = StableFingerprint.fingerprint([])
        XCTAssertTrue(result.hasPrefix("fnv1a64-"))
    }

    func testFingerprintEmptyString() {
        let result = StableFingerprint.fingerprint([""])
        XCTAssertTrue(result.hasPrefix("fnv1a64-"))
    }

    func testFingerprintEmptyData() {
        let result = StableFingerprint.fingerprint(Data())
        XCTAssertTrue(result.hasPrefix("fnv1a64-"))
    }

    func testFingerprintDataDeterminism() {
        let data = Data("GradeDraft".utf8)
        let first = StableFingerprint.fingerprint(data)
        let second = StableFingerprint.fingerprint(data)
        XCTAssertEqual(first, second)
    }

    func testFingerprintDistinguishesEmptyComponents() {
        let leadingEmpty = StableFingerprint.fingerprint(["", "hello"])
        let trailingEmpty = StableFingerprint.fingerprint(["hello", ""])
        XCTAssertNotEqual(leadingEmpty, trailingEmpty)
    }
}
