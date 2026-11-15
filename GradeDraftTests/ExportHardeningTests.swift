import XCTest
@testable import GradeDraft

final class StudentFacingReportPrivacyTests: XCTestCase {
    private func assertStudentReportRefused(_ fixture: ExportFixture, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(ExportPolicy.allowsStudentReport(setup: fixture.setup, submission: fixture.submission), file: file, line: line)
        XCTAssertThrowsError(
            try ReportBuilder.studentReport(setup: fixture.setup, submission: fixture.submission, generatedAt: Date(timeIntervalSince1970: 0)),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(error as? ReportError, .notApproved, file: file, line: line)
        }
    }

    // The four states of the student-facing gate: no final review, in progress, approved but stale,
    // approved and current. Only the last one produces a student report.

    func testStudentReportWithoutFinalReviewIsRefusedAndHasNoDraftContent() throws {
        assertStudentReportRefused(try ExportFixtureFactory.draftOnlyAssignment())
    }

    func testStudentReportWithInProgressFinalReviewIsRefused() throws {
        assertStudentReportRefused(try ExportFixtureFactory.inProgressFinalReviewAssignment())
    }

    func testStudentReportWithStaleApprovedFinalReviewIsRefused() throws {
        assertStudentReportRefused(try ExportFixtureFactory.staleApprovedAssignment())
    }

    func testStudentReportWithApprovedCurrentFinalReviewContainsFinalFeedback() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment()
        XCTAssertTrue(ExportPolicy.allowsStudentReport(setup: fixture.setup, submission: fixture.submission))
        let report = try fixture.studentReportMarkdown()
        XCTAssertTrue(report.contains("Final student feedback sentinel"))
        XCTAssertTrue(report.contains("Final teacher-approved grade"))
    }

    func testStudentMarkdownExcludesPrivateTeacherNotes() throws {
        XCTAssertFalse(try studentReport().contains(ExportFixtureFactory.privateTeacherNote))
    }

    func testStudentMarkdownExcludesTeacherRationale() throws {
        XCTAssertFalse(try studentReport().contains(ExportFixtureFactory.teacherRationale))
    }

    func testStudentMarkdownExcludesModelTeacherNotes() throws {
        XCTAssertFalse(try studentReport().contains(ExportFixtureFactory.modelTeacherNote))
    }

    func testStudentMarkdownExcludesSourceInputPaths() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment()
        let report = try fixture.studentReportMarkdown()
        XCTAssertFalse(report.contains(try XCTUnwrap(fixture.sourceRelativePath)))
        XCTAssertFalse(report.contains(ExportFixtureFactory.sourceFileName))
    }

    func testStudentMarkdownExcludesEvidenceSourceReferences() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment()
        let lineID = try XCTUnwrap(fixture.ocrLine?.id)
        let report = try fixture.studentReportMarkdown()
        XCTAssertFalse(report.contains(lineID.uuidString))
        XCTAssertFalse(report.contains(String(lineID.uuidString.prefix(8))))
    }

    func testStudentMarkdownExcludesBoundingBoxes() throws {
        let report = try studentReport()
        XCTAssertFalse(report.contains("bbox:"))
        XCTAssertFalse(report.contains("x:0.1000"))
    }

    func testStudentMarkdownExcludesAuditEvents() throws {
        XCTAssertFalse(try studentReport().contains(ExportFixtureFactory.auditEvent))
    }

    func testStudentMarkdownExcludesUncertaintyAndComplianceFlags() throws {
        let report = try studentReport()
        XCTAssertFalse(report.contains(ExportFixtureFactory.uncertaintyFlag))
        XCTAssertFalse(report.contains(ExportFixtureFactory.complianceFlag))
    }

    func testStudentPDFUsesStrictStudentReportContent() throws {
        let approved = try ExportFixtureFactory.sensitiveApprovedAssignment()
        let document = try ReportBuilder.studentReport(setup: approved.setup, submission: approved.submission, generatedAt: Date(timeIntervalSince1970: 0))
        let pdf = try PDFRenderer.render(document)
        XCTAssertTrue(pdf.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(pdf.count, 0)
        // A draft-only submission has no student report to render.
        assertStudentReportRefused(try ExportFixtureFactory.draftOnlyAssignment())
    }

    func testTeacherRecordContainsTeacherOnlySentinels() throws {
        let record = try ExportFixtureFactory.sensitiveApprovedAssignment().teacherRecordMarkdown()
        XCTAssertTrue(record.contains(ExportFixtureFactory.privateTeacherNote))
        XCTAssertTrue(record.contains(ExportFixtureFactory.teacherRationale))
        XCTAssertTrue(record.contains(ExportFixtureFactory.auditEvent))
        XCTAssertTrue(record.contains("bbox:"))
    }

    private func studentReport() throws -> String {
        try ExportFixtureFactory.sensitiveApprovedAssignment().studentReportMarkdown()
    }
}

final class ExportFilenameHardeningTests: XCTestCase {
    /// Writes through the one place export files live, with the name the app would give the file.
    private func writeExport(_ data: Data, kind: ExportKind, assignmentID: UUID, extension ext: String) throws -> URL {
        let name = ExportFilenameBuilder.filename(kind: kind, assignmentID: assignmentID, extension: ext)
        let url = try ExportFileStore.write(data, fileName: name)
        addTeardownBlock { ExportFileStore.remove(url) }
        return url
    }

    func testExportFilenamesDoNotContainAssignmentTitle() {
        let filename = ExportFilenameBuilder.filename(kind: .studentPDF, assignmentID: UUID(uuidString: "11111111-1111-1111-1111-111111111111"), extension: "pdf", date: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(filename.contains("Essay"))
        XCTAssertFalse(filename.contains("Alice"))
    }

    func testExportFilenamesDoNotContainStudentName() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment(title: "Secret Title", student: "Alice Secret")
        let url = try writeExport(Data(try fixture.studentReportMarkdown().utf8), kind: .studentMarkdown, assignmentID: fixture.setup.id, extension: "md")
        XCTAssertFalse(url.lastPathComponent.contains("Alice"))
        XCTAssertFalse(url.lastPathComponent.contains("Secret"))
    }

    func testExportFilenamesContainKindTimestampAndShortID() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let filename = ExportFilenameBuilder.filename(kind: .teacherAuditPDF, assignmentID: id, extension: "pdf", date: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(filename.hasPrefix("MarkForMe-TeacherAuditPDF-19700101-000000-AAAAAAAA"))
        XCTAssertTrue(filename.hasSuffix(".pdf"))
    }

    func testStudentMarkdownFileUsesSafeFilename() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment(title: "=Bad, Title")
        let url = try writeExport(Data(try fixture.studentReportMarkdown().utf8), kind: .studentMarkdown, assignmentID: fixture.setup.id, extension: "md")
        XCTAssertTrue(url.lastPathComponent.contains("StudentReport"))
        XCTAssertFalse(url.lastPathComponent.contains("Bad"))
    }

    func testTeacherRecordMarkdownFileUsesSafeFilename() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment(title: "Teacher Secret")
        let url = try writeExport(Data(fixture.teacherRecordMarkdown().utf8), kind: .teacherAuditMarkdown, assignmentID: fixture.setup.id, extension: "md")
        XCTAssertTrue(url.lastPathComponent.contains("TeacherAudit"))
        XCTAssertFalse(url.lastPathComponent.contains("Teacher Secret"))
    }

    func testStudentPDFFileUsesSafeFilename() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment(title: "PDF Secret")
        let document = try ReportBuilder.studentReport(setup: fixture.setup, submission: fixture.submission, generatedAt: Date(timeIntervalSince1970: 0))
        let url = try writeExport(try PDFRenderer.render(document), kind: .studentPDF, assignmentID: fixture.setup.id, extension: "pdf")
        XCTAssertTrue(url.lastPathComponent.contains("StudentPDF"))
        XCTAssertFalse(url.lastPathComponent.contains("PDF Secret"))
    }

    func testCSVGradebookFileUsesSafeFilename() throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment(title: "CSV Secret")
        let csv = CSVExportService.gradebookCSV(setup: fixture.setup, submissions: [fixture.submission])
        let url = try writeExport(Data(csv.utf8), kind: .csvGradebook, assignmentID: fixture.setup.id, extension: "csv")
        XCTAssertTrue(url.lastPathComponent.contains("GradebookCSV"))
        XCTAssertFalse(url.lastPathComponent.contains("CSV Secret"))
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
    }
}

final class GradebookCSVStatusTests: XCTestCase {
    func testCSVExportAllowedWithoutFinalReviewButContainsPendingStatus() throws {
        let fixture = try ExportFixtureFactory.draftOnlyAssignment()
        let csv = CSVExportService.gradebookCSV(setup: fixture.setup, submissions: [fixture.submission])
        let rows = try CSVParser.parseRows(String(csv.dropFirst()))
        XCTAssertEqual(rows[1][2], "pending_final_review")
    }
}

/// The single-student export path as the Student Exports screen runs it: the session prepares the file,
/// records it and keeps the record free of private notes unless the export includes them.
@MainActor
final class SubmissionExportSessionTests: XCTestCase {
    func testStudentMarkdownExportBlockedWithoutFinalReview() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.draftOnlyAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.studentMarkdown)
        XCTAssertNil(harness.session.preparedExport)
        XCTAssertEqual(harness.session.alert?.title, "Export not created")
    }

    func testStudentPDFExportBlockedWithoutFinalReview() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.draftOnlyAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.studentPDF)
        XCTAssertNil(harness.session.preparedExport)
        XCTAssertEqual(harness.session.alert?.title, "Export not created")
    }

    func testStudentMarkdownExportBlockedForStaleFinalReview() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.staleApprovedAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.studentMarkdown)
        XCTAssertNil(harness.session.preparedExport)
        XCTAssertNotNil(harness.session.alert)
    }

    func testStudentPDFExportBlockedForStaleFinalReview() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.staleApprovedAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.studentPDF)
        XCTAssertNil(harness.session.preparedExport)
        XCTAssertNotNil(harness.session.alert)
    }

    func testStudentMarkdownExportSucceedsForApprovedCurrentFinalReview() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.sensitiveApprovedAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.studentMarkdown)
        XCTAssertNil(harness.session.alert)
        XCTAssertEqual(harness.session.preparedExport?.kind, .studentMarkdown)
    }

    func testStudentPDFExportSucceedsForApprovedCurrentFinalReview() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.sensitiveApprovedAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.studentPDF)
        XCTAssertNil(harness.session.alert)
        XCTAssertEqual(harness.session.preparedExport?.kind, .studentPDF)
    }

    func testTeacherRecordMarkdownExportAllowedWithoutFinalReview() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.draftOnlyAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.teacherAuditMarkdown)
        XCTAssertEqual(harness.session.preparedExport?.kind, .teacherAuditMarkdown)
    }

    func testTeacherRecordPDFExportAllowedWithoutFinalReview() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.draftOnlyAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.teacherAuditPDF)
        XCTAssertEqual(harness.session.preparedExport?.kind, .teacherAuditPDF)
    }

    func testSensitiveExportAsksForAuthenticationBeforeWritingAnything() async throws {
        let denied = ExportAuthenticationResult(allowed: false, authenticationPerformed: true, message: "Denied")
        let harness = try await SessionHarness.make(
            try ExportFixtureFactory.sensitiveApprovedAssignment(),
            authentication: ScriptedExportAuthentication(result: denied)
        )
        defer { harness.stop() }
        await harness.session.prepareExport(.teacherAuditMarkdown)
        XCTAssertNil(harness.session.preparedExport)
        XCTAssertEqual(harness.session.alert?.message, "Denied")
        let graph = try await requireAsync(harness.database.submission(id: harness.session.id))
        XCTAssertTrue(graph.exports.isEmpty)
    }

    func testExportRecordDigestMatchesPDFData() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.sensitiveApprovedAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.studentPDF)
        let url = try XCTUnwrap(harness.session.preparedExport?.url)
        let graph = try await requireAsync(harness.database.submission(id: harness.session.id))
        let record = try XCTUnwrap(graph.exports.last)
        XCTAssertEqual(record.contentSHA256, ContentDigest.sha256Hex(try Data(contentsOf: url)))
    }

    func testStudentExportRecordMarksNoPrivateNotesAndNoOriginalSources() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.sensitiveApprovedAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.studentMarkdown)
        let graph = try await requireAsync(harness.database.submission(id: harness.session.id))
        let record = try XCTUnwrap(graph.exports.last)
        XCTAssertFalse(record.includesPrivateTeacherNotes)
        XCTAssertFalse(record.includesOriginalSources)
    }

    func testTeacherRecordExportRecordMarksPrivateNotes() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.sensitiveApprovedAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.teacherAuditMarkdown)
        let graph = try await requireAsync(harness.database.submission(id: harness.session.id))
        let record = try XCTUnwrap(graph.exports.last)
        XCTAssertTrue(record.includesPrivateTeacherNotes)
    }

    func testExportAuditEventDoesNotExposeFilePathOrPrivateNotes() async throws {
        let harness = try await SessionHarness.make(try ExportFixtureFactory.sensitiveApprovedAssignment())
        defer { harness.stop() }
        await harness.session.prepareExport(.teacherAuditMarkdown)
        let graph = try await requireAsync(harness.database.submission(id: harness.session.id))
        let event = try XCTUnwrap(graph.audit.last { $0.eventType == .exportPrepared })
        XCTAssertFalse(event.detail.contains(ExportFixtureFactory.privateTeacherNote))
        XCTAssertFalse(event.detail.contains(FileManager.default.temporaryDirectory.path))
    }

    func testGradebookCSVRecordDigestMatchesFileContent() async throws {
        let fixture = try ExportFixtureFactory.sensitiveApprovedAssignment()
        let harness = try await SessionHarness.make(fixture)
        let model = AssignmentSetupModel(assignmentID: fixture.setup.id, app: harness.app)
        let observing = Task { await model.observe() }
        defer {
            observing.cancel()
            model.finishSharing()
            harness.stop()
        }
        try await waitUntil { model.hasLoaded }

        await model.prepareGradebookCSV()

        let url = try XCTUnwrap(model.preparedExport?.url)
        let snapshot = try await harness.database.backupSnapshot()
        let record = try XCTUnwrap(snapshot.unattachedExports.last { $0.kind == .csvGradebook })
        XCTAssertEqual(record.contentSHA256, ContentDigest.sha256Hex(try Data(contentsOf: url)))
        XCTAssertFalse(record.includesPrivateTeacherNotes)
    }
}

// MARK: - Harness

/// An app over an in-memory store that holds one fixture, and the session for its submission.
@MainActor
private final class SessionHarness {
    let app: AppModel
    let database: AppDatabase
    let session: SubmissionSession
    private let observing: Task<Void, Never>

    private init(app: AppModel, database: AppDatabase, session: SubmissionSession, observing: Task<Void, Never>) {
        self.app = app
        self.database = database
        self.session = session
        self.observing = observing
    }

    static func make(
        _ fixture: ExportFixture,
        authentication: any ExportAuthenticationServicing = ScriptedExportAuthentication(
            result: ExportAuthenticationResult(allowed: true, authenticationPerformed: false, message: nil)
        )
    ) async throws -> SessionHarness {
        let database = try AppDatabase.inMemory()
        _ = try await database.restore(fixture.snapshot, resolutions: [:])
        var services = PreviewFixtures.previewServices()
        services.exportAuthentication = authentication
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ExportSession-\(UUID().uuidString)", isDirectory: true)
        let app = AppModel(openStorage: { AppModel.Storage(database: database, root: root) }, services: services)
        let session = SubmissionSession(id: fixture.submission.id, app: app)
        let observing = Task { await session.observe() }
        let harness = SessionHarness(app: app, database: database, session: session, observing: observing)
        do {
            try await waitUntil { session.hasLoaded }
        } catch {
            harness.stop()
            throw error
        }
        return harness
    }

    func stop() {
        session.finishSharing()
        observing.cancel()
    }
}

@MainActor
private struct ScriptedExportAuthentication: ExportAuthenticationServicing {
    var result: ExportAuthenticationResult

    func authenticateForSensitiveExport(reason: String) async -> ExportAuthenticationResult { result }
}

private struct HarnessTimeout: Error {}

@MainActor
private func waitUntil(timeout: Duration = .seconds(5), _ condition: @MainActor () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        guard clock.now < deadline else { throw HarnessTimeout() }
        try await Task.sleep(for: .milliseconds(20))
    }
}

private func requireAsync<T>(_ value: @autoclosure () async throws -> T?, file: StaticString = #filePath, line: UInt = #line) async throws -> T {
    let result = try await value()
    return try XCTUnwrap(result, file: file, line: line)
}
