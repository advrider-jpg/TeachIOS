import XCTest
@testable import GradeDraft

// MARK: - JSON Codable round-trip hardening

final class CodableRoundTripHardeningTests: XCTestCase {
    /// A backup carries every record of an assignment and its submissions through JSON. Every part must
    /// come back equal.
    func testBackupSnapshotFullRoundTrip() throws {
        var fixture = try ExportFixtureFactory.sensitiveApprovedAssignment(title: "Round trip test")
        fixture.setup.assignment.prompt = "What is photosynthesis?"

        let original = fixture.snapshot
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BackupSnapshot.self, from: data)

        XCTAssertEqual(decoded, original)
        let setup = try XCTUnwrap(decoded.assignments.first)
        XCTAssertEqual(setup.assignment.title, "Round trip test")
        XCTAssertEqual(setup.assignment.prompt, "What is photosynthesis?")
        let graph = try XCTUnwrap(decoded.submissions.first)
        XCTAssertEqual(graph.ocr?.reviewStatus, .reviewed)
        XCTAssertEqual(graph.sources.count, 1)
        XCTAssertEqual(graph.audit.count, 1)
        XCTAssertEqual(graph.finalReview?.criteria.count, 1)
    }

    func testGradeDraftResultRoundTrip() throws {
        let original = GradeDraftResult(
            packetFingerprint: "fp-1",
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterionID: "c-1",
                rating: "Good",
                proposedPoints: 3,
                evidenceQuotes: ["Quote"],
                explanation: "Met.",
                teacherReviewRequired: true,
                confidence: "high",
                title: "Claim",
                maxPoints: 4
            )],
            studentFeedback: "Good",
            teacherNotes: "Notes",
            uncertaintyFlags: ["flag1"],
            complianceFlags: ["compliance1"]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GradeDraftResult.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.packetFingerprint, "fp-1")
        XCTAssertEqual(decoded.criteria.count, 1)
        XCTAssertEqual(decoded.criteria[0].confidence, "high")
    }
}
