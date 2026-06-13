import XCTest
@testable import GradeDraft

// MARK: - BundleExportService hardening

final class BundleExportHardeningTests: XCTestCase {
    func testArchiveContainsAllExpectedFiles() throws {
        var assignment = AssignmentRecord(title: "Full archive test", reviewedStudentText: "Text")
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim", rating: "", proposedPoints: 0, finalPoints: 1,
                maxPoints: 1, evidence: [], explanation: "", teacherApproved: true
            )],
            totalScore: 1, maxScore: 1, studentFeedback: "Good.",
            privateTeacherNotes: "Private", teacherEdited: true
        )
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("archive-hardening-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        let written = try BundleExportService.writeTeacherAuditArchive(assignment: assignment, sourceFiles: [], to: destination)
        guard let archive = Archive(url: written, accessMode: .read) else {
            return XCTFail("Archive should open")
        }
        XCTAssertNotNil(archive["manifest.json"])
        XCTAssertNotNil(archive["student_report.md"])
        XCTAssertNotNil(archive["teacher_audit_report.md"])
        XCTAssertNotNil(archive["assignment.json"])
        XCTAssertNotNil(archive["source_metadata.json"])
        XCTAssertNotNil(archive["grade_summary.csv"])
        XCTAssertNotNil(archive["student_report.pdf"])
        XCTAssertNotNil(archive["teacher_audit_report.pdf"])
    }

    func testFullBackupContainsManifestAndData() throws {
        let assignmentA = AssignmentRecord(title: "A", reviewedStudentText: "Text A")
        let assignmentB = AssignmentRecord(title: "B", reviewedStudentText: "Text B")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("backup-hardening-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        let written = try BundleExportService.writeFullBackup(assignments: [assignmentA, assignmentB], sourceFiles: [], to: destination)
        let restored = try BundleExportService.readBackupAssignments(from: written)
        XCTAssertEqual(restored.count, 2)
        XCTAssertTrue(restored.contains { $0.title == "A" })
        XCTAssertTrue(restored.contains { $0.title == "B" })
    }

    func testGradebookArchiveContainsExpectedFiles() throws {
        let gradebookAssignment = AssignmentRecord(title: "Gradebook A", reviewedStudentText: "Text")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("gradebook-hardening-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        let written = try BundleExportService.writeAssignmentArchive(assignments: [gradebookAssignment], sourceFiles: [], to: destination)
        guard let archive = Archive(url: written, accessMode: .read) else {
            return XCTFail("Archive should open")
        }
        XCTAssertNotNil(archive["manifest.json"])
        XCTAssertNotNil(archive["gradebook.csv"])
        XCTAssertNotNil(archive["assignments.json"])
    }
}
