import XCTest
@testable import GradeDraft

// MARK: - JSON Codable round-trip hardening

final class CodableRoundTripHardeningTests: XCTestCase {
    func testAssignmentRecordFullRoundTrip() throws {
        var original = AssignmentRecord(
            title: "Round trip test",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "Student text"
        )
        original.prompt = "What is photosynthesis?"
        original.ocrReviewStatus = .reviewed
        original.sourceInputs = [SourceInputRef(sourceType: .scan, contentDigest: "digest")]
        original.appendAuditEvent(.assignmentCreated, detail: "Created.")
        original.finalReview = FinalGradeReview(
            packetFingerprint: original.gradingPacketFingerprint,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 3,
                maxPoints: 4, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 3, maxScore: 4, studentFeedback: "Good.",
            privateTeacherNotes: "Private", teacherEdited: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AssignmentRecord.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.prompt, "What is photosynthesis?")
        XCTAssertEqual(decoded.ocrReviewStatus, .reviewed)
        XCTAssertEqual(decoded.sourceInputs.count, 1)
        XCTAssertEqual(decoded.auditEvents.count, 1)
        XCTAssertEqual(decoded.finalReview?.criteria.count, 1)
    }

    func testGradeDraftResultRoundTrip() throws {
        let original = GradeDraftResult(
            packetFingerprint: "fp-1",
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterionID: "c-1",
                criterion: "Claim",
                rating: "Good",
                proposedPoints: 3,
                maxPoints: 4,
                evidence: ["Quote"],
                explanation: "Met.",
                teacherReviewRequired: true,
                confidence: "high"
            )],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good",
            teacherNotes: "Notes",
            uncertaintyFlags: ["flag1"],
            complianceFlags: ["compliance1"],
            rawModelResponse: "raw response"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GradeDraftResult.self, from: data)

        XCTAssertEqual(decoded.packetFingerprint, "fp-1")
        XCTAssertEqual(decoded.criteria.count, 1)
        XCTAssertEqual(decoded.criteria[0].confidence, "high")
        XCTAssertEqual(decoded.rawModelResponse, "raw response")
    }
}
