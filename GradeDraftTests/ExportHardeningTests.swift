import XCTest
@testable import GradeDraft

final class StudentFacingReportPrivacyTests: XCTestCase {
    func testStudentMarkdownWithoutFinalReviewContainsNoDraftContent() {
        let report = MarkdownReportBuilder.studentMarkdown(for: ExportFixtureFactory.draftOnlyAssignment())
        XCTAssertTrue(report.contains("No final teacher-approved grade is available"))
        XCTAssertFalse(report.contains("DRAFT_FEEDBACK_SENTINEL"))
        XCTAssertFalse(report.contains("Draft grade for teacher review"))
    }

    func testStudentMarkdownWithInProgressFinalReviewContainsNoFinalDetails() {
        let report = MarkdownReportBuilder.studentMarkdown(for: ExportFixtureFactory.inProgressFinalReviewAssignment())
        XCTAssertTrue(report.contains("No final teacher-approved grade is available"))
        XCTAssertFalse(report.contains("Final student feedback sentinel"))
    }

    func testStudentMarkdownWithStaleApprovedFinalReviewContainsNoFinalDetails() {
        let report = MarkdownReportBuilder.studentMarkdown(for: ExportFixtureFactory.staleApprovedAssignment())
        XCTAssertTrue(report.contains("No final teacher-approved grade is available"))
        XCTAssertFalse(report.contains("Final student feedback sentinel"))
    }

    func testStudentMarkdownWithApprovedFreshFinalReviewContainsFinalFeedback() {
        let report = MarkdownReportBuilder.studentMarkdown(for: ExportFixtureFactory.sensitiveApprovedAssignment())
        XCTAssertTrue(report.contains("Final student feedback sentinel"))
        XCTAssertTrue(report.contains("Final teacher-approved grade"))
    }

    func testStudentMarkdownExcludesPrivateTeacherNotes() {
        XCTAssertFalse(studentReport().contains(ExportFixtureFactory.privateTeacherNote))
    }

    func testStudentMarkdownExcludesTeacherRationale() {
        XCTAssertFalse(studentReport().contains(ExportFixtureFactory.teacherRationale))
    }

    func testStudentMarkdownExcludesRawModelResponse() {
        XCTAssertFalse(studentReport().contains(ExportFixtureFactory.rawModelResponse))
    }

    func testStudentMarkdownExcludesModelTeacherNotes() {
        XCTAssertFalse(studentReport().contains(ExportFixtureFactory.modelTeacherNote))
    }

    func testStudentMarkdownExcludesSourceInputPaths() {
        XCTAssertFalse(studentReport().contains(ExportFixtureFactory.sourcePath))
    }

    func testStudentMarkdownExcludesEvidenceSourceRefs() {
        XCTAssertFalse(studentReport().contains(ExportFixtureFactory.evidenceSourceRef))
    }

    func testStudentMarkdownExcludesBoundingBoxes() {
        XCTAssertFalse(studentReport().contains("bbox:"))
        XCTAssertFalse(studentReport().contains("x:0.1000"))
    }

    func testStudentMarkdownExcludesAuditEvents() {
        XCTAssertFalse(studentReport().contains(ExportFixtureFactory.auditEvent))
    }

    func testStudentMarkdownExcludesUncertaintyAndComplianceFlags() {
        let report = studentReport()
        XCTAssertFalse(report.contains(ExportFixtureFactory.uncertaintyFlag))
        XCTAssertFalse(report.contains(ExportFixtureFactory.complianceFlag))
    }

    func testStudentPDFUsesStrictStudentMarkdownContent() throws {
        let root = ExportFixtureFactory.temporaryDirectory("StudentPDF")
        let url = root.appendingPathComponent("student.pdf")
        let written = try PDFExportService.studentReportPDF(for: ExportFixtureFactory.draftOnlyAssignment(), destination: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: written.path))
        XCTAssertGreaterThan((try? Data(contentsOf: written).count) ?? 0, 0)
        XCTAssertTrue(MarkdownReportBuilder.studentMarkdown(for: ExportFixtureFactory.draftOnlyAssignment()).contains("No final teacher-approved grade is available"))
    }

    func testTeacherAuditMarkdownContainsTeacherOnlySentinels() {
        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: ExportFixtureFactory.sensitiveApprovedAssignment())
        XCTAssertTrue(audit.contains(ExportFixtureFactory.privateTeacherNote))
        XCTAssertTrue(audit.contains(ExportFixtureFactory.teacherRationale))
        XCTAssertTrue(audit.contains(ExportFixtureFactory.auditEvent))
        XCTAssertTrue(audit.contains("bbox:"))
    }

    private func studentReport() -> String {
        MarkdownReportBuilder.studentMarkdown(for: ExportFixtureFactory.sensitiveApprovedAssignment())
    }
}

final class ExportFilenameHardeningTests: XCTestCase {
    func testExportFilenamesDoNotContainAssignmentTitle() {
        let filename = ExportFilenameBuilder.filename(kind: .studentPDF, assignmentID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"), extension: "pdf", date: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(filename.contains("Essay"))
        XCTAssertFalse(filename.contains("Alice"))
    }

    func testExportFilenamesDoNotContainStudentName() throws {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment(title: "Secret Title", student: "Alice Secret")
        let url = try MarkdownReportBuilder.writeTemporaryStudentReport(for: assignment)
        XCTAssertFalse(url.lastPathComponent.contains("Alice"))
        XCTAssertFalse(url.lastPathComponent.contains("Secret"))
    }

    func testExportFilenamesContainKindTimestampAndShortID() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let filename = ExportFilenameBuilder.filename(kind: .teacherAuditPDF, assignmentID: id, extension: "pdf", date: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(filename.hasPrefix("GradeDraft-TeacherAuditPDF-19700101-000000-AAAAAAAA"))
        XCTAssertTrue(filename.hasSuffix(".pdf"))
    }

    func testTemporaryStudentMarkdownUsesSafeFilename() throws {
        let url = try MarkdownReportBuilder.writeTemporaryStudentReport(for: ExportFixtureFactory.sensitiveApprovedAssignment(title: "=Bad, Title"))
        XCTAssertTrue(url.lastPathComponent.contains("StudentReport"))
        XCTAssertFalse(url.lastPathComponent.contains("Bad"))
    }

    func testTemporaryTeacherAuditMarkdownUsesSafeFilename() throws {
        let url = try MarkdownReportBuilder.writeTemporaryTeacherAuditReport(for: ExportFixtureFactory.sensitiveApprovedAssignment(title: "Teacher Secret"))
        XCTAssertTrue(url.lastPathComponent.contains("TeacherAudit"))
        XCTAssertFalse(url.lastPathComponent.contains("Teacher Secret"))
    }

    func testTemporaryStudentPDFUsesSafeFilename() throws {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment(title: "PDF Secret")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(ExportFilenameBuilder.filename(kind: .studentPDF, assignmentID: assignment.id, extension: "pdf"))
        let url = try PDFExportService.studentReportPDF(for: assignment, destination: destination)
        XCTAssertTrue(url.lastPathComponent.contains("StudentPDF"))
        XCTAssertFalse(url.lastPathComponent.contains("PDF Secret"))
    }

    @MainActor
    func testCSVGradebookUsesSafeFilename() {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment(title: "CSV Secret")
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportCSVGradebook()
        XCTAssertTrue(viewModel.exportURL?.lastPathComponent.contains("GradebookCSV") == true)
        XCTAssertFalse(viewModel.exportURL?.lastPathComponent.contains("CSV Secret") == true)
    }

    func testFileProtectionHelperDoesNotThrowInTestEnvironment() throws {
        let root = ExportFixtureFactory.temporaryDirectory("Protection")
        let url = root.appendingPathComponent("file.txt")
        try Data("hello".utf8).write(to: url)
        ExportFileHardening.applyBestEffortProtection(to: url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testExportFilenameTokensAreStableForAllExportKinds() {
        XCTAssertEqual(ExportKind.studentMarkdown.safeFilenameToken, "StudentReport")
        XCTAssertEqual(ExportKind.teacherAuditMarkdown.safeFilenameToken, "TeacherAudit")
        XCTAssertEqual(ExportKind.studentPDF.safeFilenameToken, "StudentPDF")
        XCTAssertEqual(ExportKind.teacherAuditPDF.safeFilenameToken, "TeacherAuditPDF")
        XCTAssertEqual(ExportKind.csvGradebook.safeFilenameToken, "GradebookCSV")
        XCTAssertEqual(ExportKind.zipArchive.safeFilenameToken, "TeacherArchive")
        XCTAssertEqual(ExportKind.fullBackupArchive.safeFilenameToken, "FullBackup")
        XCTAssertEqual(ExportKind.backupJSON.safeFilenameToken, "BackupJSON")
        XCTAssertEqual(ExportKind.assignmentGradebookArchive.safeFilenameToken, "GradebookArchive")
    }
}

final class ViewModelExportHardeningTests: XCTestCase {
    @MainActor
    func testStudentMarkdownExportBlockedWithoutFinalReview() {
        let assignment = ExportFixtureFactory.draftOnlyAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportStudentReport()
        XCTAssertNil(viewModel.exportURL)
        XCTAssertTrue(viewModel.errorMessage?.contains("blocked") == true)
    }

    @MainActor
    func testStudentPDFExportBlockedWithoutFinalReview() {
        let assignment = ExportFixtureFactory.draftOnlyAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportStudentPDF()
        XCTAssertNil(viewModel.exportURL)
        XCTAssertTrue(viewModel.errorMessage?.contains("blocked") == true)
    }

    @MainActor
    func testStudentMarkdownExportBlockedForStaleFinalReview() {
        let assignment = ExportFixtureFactory.staleApprovedAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportStudentReport()
        XCTAssertNil(viewModel.exportURL)
    }

    @MainActor
    func testStudentPDFExportBlockedForStaleFinalReview() {
        let assignment = ExportFixtureFactory.staleApprovedAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportStudentPDF()
        XCTAssertNil(viewModel.exportURL)
    }

    @MainActor
    func testStudentMarkdownExportSucceedsForApprovedFreshFinalReview() {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportStudentReport()
        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertEqual(viewModel.exportKind, .studentMarkdown)
    }

    @MainActor
    func testStudentPDFExportSucceedsForApprovedFreshFinalReview() {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportStudentPDF()
        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertEqual(viewModel.exportKind, .studentPDF)
    }

    @MainActor
    func testTeacherAuditMarkdownExportAllowedWithoutFinalReview() {
        let assignment = ExportFixtureFactory.draftOnlyAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportTeacherAuditReport()
        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertEqual(viewModel.exportKind, .teacherAuditMarkdown)
    }

    @MainActor
    func testTeacherAuditPDFExportAllowedWithoutFinalReview() {
        let assignment = ExportFixtureFactory.draftOnlyAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportTeacherAuditPDF()
        XCTAssertNotNil(viewModel.exportURL)
        XCTAssertEqual(viewModel.exportKind, .teacherAuditPDF)
    }

    @MainActor
    func testCSVExportAllowedWithoutFinalReviewButContainsPendingStatus() throws {
        let assignment = ExportFixtureFactory.draftOnlyAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportCSVGradebook()
        let url = try XCTUnwrap(viewModel.exportURL)
        let rows = try CSVParser.parseRows(String(data: try Data(contentsOf: url), encoding: .utf8) ?? "")
        XCTAssertEqual(rows[1][10], "pending_final_review")
    }

    @MainActor
    func testExportRecordFingerprintMatchesCSVContent() throws {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportCSVGradebook()
        let url = try XCTUnwrap(viewModel.exportURL)
        let data = try Data(contentsOf: url)
        let record = try XCTUnwrap(viewModel.assignment.exportRecords.last)
        XCTAssertEqual(record.contentFingerprint, StableFingerprint.fingerprint(data))
        XCTAssertFalse(record.includesPrivateTeacherNotes)
    }

    @MainActor
    func testExportRecordFingerprintMatchesPDFData() throws {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportStudentPDF()
        let url = try XCTUnwrap(viewModel.exportURL)
        let record = try XCTUnwrap(viewModel.assignment.exportRecords.last)
        XCTAssertEqual(record.contentFingerprint, StableFingerprint.fingerprint(try Data(contentsOf: url)))
    }

    @MainActor
    func testStudentExportRecordMarksNoPrivateNotesAndNoOriginalSources() throws {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportStudentReport()
        let record = try XCTUnwrap(viewModel.assignment.exportRecords.last)
        XCTAssertFalse(record.includesPrivateTeacherNotes)
        XCTAssertFalse(record.includesOriginalSources)
    }

    @MainActor
    func testTeacherAuditExportRecordMarksPrivateNotes() throws {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportTeacherAuditReport()
        let record = try XCTUnwrap(viewModel.assignment.exportRecords.last)
        XCTAssertTrue(record.includesPrivateTeacherNotes)
    }

    @MainActor
    func testExportAuditEventDoesNotExposeFilePathOrPrivateNotes() {
        let assignment = ExportFixtureFactory.sensitiveApprovedAssignment()
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: InMemoryAssignmentStore(assignments: [assignment]))
        viewModel.exportTeacherAuditReport()
        let detail = viewModel.assignment.auditEvents.last?.detail ?? ""
        XCTAssertFalse(detail.contains(ExportFixtureFactory.privateTeacherNote))
        XCTAssertFalse(detail.contains(FileManager.default.temporaryDirectory.path))
    }
}
