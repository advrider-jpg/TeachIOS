import XCTest
@testable import GradeDraft

// MARK: - ContentDigest tests (fingerprints and file digests are SHA-256)

final class ContentDigestTests: XCTestCase {
    private let emptySHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    func testDigestIsDeterministic() {
        let first = ContentDigest.sha256Hex("hello\u{1F}world")
        let second = ContentDigest.sha256Hex("hello\u{1F}world")
        XCTAssertEqual(first, second, "Same inputs must produce the same digest")
    }

    func testDigestChangesWithInput() {
        let first = ContentDigest.sha256Hex("hello")
        let second = ContentDigest.sha256Hex("world")
        XCTAssertNotEqual(first, second, "Different inputs must produce different digests")
    }

    func testDigestOrderMatters() {
        let forward = ContentDigest.sha256Hex("ab")
        let reversed = ContentDigest.sha256Hex("ba")
        XCTAssertNotEqual(forward, reversed, "Different order must produce different digests")
    }

    func testDigestEmptyString() {
        XCTAssertEqual(ContentDigest.sha256Hex(""), emptySHA256)
    }

    func testDigestEmptyData() {
        XCTAssertEqual(ContentDigest.sha256Hex(Data()), emptySHA256)
    }

    func testDigestDataDeterminism() {
        let data = Data("GradeDraft".utf8)
        let first = ContentDigest.sha256Hex(data)
        let second = ContentDigest.sha256Hex(data)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 64)
        XCTAssertEqual(first, first.lowercased())
    }
}
