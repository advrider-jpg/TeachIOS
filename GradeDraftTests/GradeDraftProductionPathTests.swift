import XCTest
import ZIPFoundation
@testable import GradeDraft

final class GradeDraftProductionPathTests: XCTestCase {
    @MainActor
    func testSensitiveGradebookArchiveAuthenticatesBeforeWritingZip() async {
        let denied = StubExportAuthenticationService(
            result: ExportAuthenticationResult(allowed: false, authenticationPerformed: true, message: "Denied")
        )
        let assignment = approvedAssignment(title: "Sensitive Archive", student: "Alex")
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            store: InMemoryAssignmentStore(assignments: [assignment]),
            exportAuthenticationService: denied
        )

        await viewModel.performConfirmedExport(.gradebookArchive)

        XCTAssertNil(viewModel.exportURL)
        XCTAssertNil(viewModel.exportKind)
        XCTAssertEqual(viewModel.errorMessage, "Denied")
    }

    @MainActor
    func testGradebookArchiveProductionPathWritesZipWithInventoryAndCSV() throws {
        let first = approvedAssignment(title: "Argument Essay", student: "Alex")
        let second = approvedAssignment(title: "Argument Essay", student: "Bailey")
        let viewModel = GradeDraftViewModel(
            assignments: [first, second],
            store: InMemoryAssignmentStore(assignments: [first, second])
        )

        viewModel.exportGradebookArchive()

        let url = try XCTUnwrap(viewModel.exportURL)
        XCTAssertEqual(url.pathExtension, "zip")
        XCTAssertEqual(viewModel.exportKind, .assignmentGradebookArchive)

        let archive = try openZip(url)
        XCTAssertNotNil(archive["gradebook.csv"])
        XCTAssertNotNil(archive["archive_inventory.json"])
        XCTAssertNotNil(archive["assignments.json"])
    }

    @MainActor
    func testBackupRestoreSelectionCreatesPreviewBeforeMutation() throws {
        let local = AssignmentRecord(title: "Local")
        let incoming = AssignmentRecord(title: "Incoming")
        let viewModel = GradeDraftViewModel(
            assignments: [local],
            store: InMemoryAssignmentStore(assignments: [local])
        )
        let backupURL = try writeLegacyBackup([incoming], name: "preview")

        viewModel.previewBackupRestore(from: backupURL)

        XCTAssertEqual(viewModel.assignments.map(\.title), ["Local"])
        XCTAssertNotNil(viewModel.pendingRestorePreview)
        XCTAssertNotNil(viewModel.pendingRestoreFileURL)
    }

    @MainActor
    func testStudentExportRemainsBlockedWhenFinalReviewIsStale() {
        var assignment = approvedAssignment(title: "Stale Review", student: "Casey")
        assignment.finalReview?.packetFingerprint = "old-fingerprint"
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            store: InMemoryAssignmentStore(assignments: [assignment])
        )

        viewModel.exportStudentReport()

        XCTAssertTrue(viewModel.assignment.finalReviewIsStale)
        XCTAssertNil(viewModel.exportURL)
        XCTAssertEqual(viewModel.exportKind, nil)
    }

    @MainActor
    func testOCRIncompleteStateBlocksDraftAndManualReviewPaths() {
        var assignment = AssignmentRecord(
            title: "Scanned Work",
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "OCR text pending teacher review.",
            ocrReviewStatus: .needsReview
        )
        assignment.ocrDocument = OCRDocument(pages: [
            OCRPage(pageIndex: 0, lines: [
                OCRLine(text: "OCR text pending teacher review.", confidence: 0.61, boundingBox: .zero)
            ])
        ])
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            store: InMemoryAssignmentStore(assignments: [assignment])
        )

        XCTAssertFalse(viewModel.canDraftGrade)
        XCTAssertFalse(viewModel.canStartManualFinalReview)
        XCTAssertTrue(viewModel.assignment.requiresOCRReviewBeforeGrading)
    }

    func testUnavailableLocalAIHasNoCloudFallback() async {
        let service = UnavailableLocalGradingService()
        if case .unavailable(let message) = service.localAIStatus {
            XCTAssertTrue(message.localizedCaseInsensitiveContains("cloud model"))
        } else {
            XCTFail("Unavailable local grading service must report an unavailable state.")
        }

        do {
            _ = try await service.draftGrade(input: gradingInput())
            XCTFail("Unavailable local grading service must throw instead of returning a draft.")
        } catch {
            XCTAssertTrue(error.localizedDescription.localizedCaseInsensitiveContains("cloud model"))
        }
    }

    @MainActor
    func testStructuredRubricImportCreatesTeacherConfirmedStateAndStalesReviews() {
        var assignment = approvedAssignment(title: "Rubric Import", student: "Drew")
        assignment.latestDraft = GradeDraftResult(
            packetFingerprint: assignment.gradingPacketFingerprint,
            studentResponseSummary: "Summary",
            criteria: [],
            totalScore: 0,
            maxScore: 0,
            studentFeedback: "Draft",
            teacherNotes: "Private",
            uncertaintyFlags: []
        )
        let viewModel = GradeDraftViewModel(
            assignments: [assignment],
            store: InMemoryAssignmentStore(assignments: [assignment])
        )
        let preview = viewModel.previewMarkdownRubric("""
        | Criterion | Max | Level | Points |
        |---|---:|---|---:|
        | Claim | 4 | Strong | 4 |
        """)

        viewModel.confirmMarkdownRubricImport(preview, useStructuredImport: true)

        XCTAssertEqual(viewModel.assignment.rubricImportMode, .structuredConfirmed)
        XCTAssertFalse(viewModel.assignment.parsedRubric.criteria.isEmpty)
        XCTAssertTrue(viewModel.assignment.latestDraftIsStale)
        XCTAssertTrue(viewModel.assignment.finalReviewIsStale)
    }


    func testGRDBBootstrapMarksApplicationSupportExcludedFromBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftProtection-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = try GRDBAssignmentStore(applicationSupportURL: root)
        let directory = try store.applicationSupportDirectory()
        let excluded = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        XCTAssertEqual(excluded, true)
    }

    func testFallbackJSONStoreMarksApplicationSupportExcludedFromBackup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftJSONProtection-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = LocalJSONStore(fileManager: .default, applicationSupportURL: root)
        let directory = try store.applicationSupportDirectory()
        let excluded = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup
        XCTAssertEqual(excluded, true)
    }

    private func approvedAssignment(title: String, student: String) -> AssignmentRecord {
        var assignment = AssignmentRecord(
            title: title,
            studentDisplayName: student,
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "The student states a clear claim and supports it.",
            ocrReviewStatus: .reviewed
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [
                FinalCriterionScore(
                    criterionID: "claim",
                    criterion: "Claim",
                    rating: "Strong",
                    proposedPoints: 4,
                    finalPoints: 4,
                    maxPoints: 4,
                    evidence: ["clear claim"],
                    explanation: "The teacher approved the criterion.",
                    teacherApproved: true
                )
            ],
            totalScore: 4,
            maxScore: 4,
            studentFeedback: "Clear claim and evidence.",
            privateTeacherNotes: "Teacher-only note.",
            teacherEdited: true
        )
        return assignment
    }

    private func gradingInput() -> GradingInput {
        approvedAssignment(title: "Local AI", student: "Elliot").gradingInput
    }

    private func writeLegacyBackup(_ assignments: [AssignmentRecord], name: String) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraft-\(name)-\(UUID()).json")
        try encoder.encode(assignments).write(to: url)
        return url
    }

    private func openZip(_ url: URL) throws -> Archive {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw NSError(domain: "GradeDraftProductionPathTests", code: 1)
        }
        return archive
    }
}
