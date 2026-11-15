import XCTest
import ZIPFoundation
@testable import GradeDraft

extension GradeDraftTests {
    /// An in-memory submission (no store) with an approved, current final review.
    fileprivate func approvedGraph(
        setup: AssignmentSetup,
        student: Student = Student(displayName: "Kai"),
        finalPoints: Double = 4,
        privateNotes: String = "Private instructor comment."
    ) throws -> SubmissionGraph {
        var graph = SubmissionGraph(
            submission: Submission(assignmentID: setup.id, studentID: student.id, inputKind: .pasted, pastedText: "Student text"),
            student: student
        )
        graph.finalReview = FinalGradeReview(
            packetFingerprint: try graph.packetFingerprint(setup: setup),
            status: .approved,
            criteria: [FinalCriterionScore(
                criterionID: setup.parsedRubric.criteria[0].id, rating: "Proficient", proposedPoints: 3, finalPoints: finalPoints,
                explanation: "Strong claim.", teacherApproved: true
            )],
            studentFeedback: "Good.",
            privateTeacherNotes: privateNotes,
            teacherEdited: true
        )
        return graph
    }

    /// Saves an approved, current final review for the submission in the store.
    fileprivate func saveApprovedReview(_ app: AppModel, _ seeded: SeededSubmission) async throws {
        let database = try app.requireDatabase()
        let savedSetup = try await database.assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(savedSetup)
        try await database.saveFinalReview(
            FinalGradeReview(
                packetFingerprint: try await TestApp.fingerprint(app, seeded),
                status: .approved,
                criteria: [FinalCriterionScore(
                    criterionID: setup.parsedRubric.criteria[0].id, rating: "Proficient", proposedPoints: 3, finalPoints: 4,
                    explanation: "Strong claim.", teacherApproved: true
                )],
                studentFeedback: "Good.",
                privateTeacherNotes: "Private note.",
                teacherEdited: true
            ),
            submissionID: seeded.submissionID
        )
    }

    private static let denied = StubExportAuthenticationService(
        result: ExportAuthenticationResult(allowed: false, authenticationPerformed: true, message: "Denied")
    )

    func testCSVSanitizationEscapesFormulaLikePrefixes() throws {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("=1+1"), "'=1+1")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("+1-2"), "'+1-2")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-SUM(A1:A2)"), "'-SUM(A1:A2)")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("@hidden"), "'@hidden")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell(" =1+1"), "' =1+1")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("   @bad"), "'   @bad")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-"), "'-")
    }

    func testCSVSanitizationPreservesRealNumericValues() throws {
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("42"), "42")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("42.5"), "42.5")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-12"), "-12")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("-12.5"), "-12.5")
        XCTAssertEqual(SpreadsheetSafety.sanitizedCell("  -3"), "  -3")
    }

    func testGradebookCSVUsesFormulaSafeguardsAndOmitsPrivateNotes() throws {
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "=Exploit prompt", rubricText: "Claim: 0-4 points"))
        var graph = try approvedGraph(
            setup: setup, student: Student(displayName: "-Jane", localIdentifier: "=ID1"), finalPoints: 4,
            privateNotes: "Private instructor comment."
        )
        graph.draft = GradeDraftResult(
            packetFingerprint: "draft-packet",
            studentResponseSummary: "Draft summary",
            criteria: [CriterionScore(
                criterionID: setup.parsedRubric.criteria[0].id, rating: "Proficient", proposedPoints: 3,
                evidenceQuotes: ["Student text"], explanation: "Evidence supports claim.", teacherReviewRequired: false
            )],
            studentFeedback: "Good effort.",
            teacherNotes: "Private grading note.",
            uncertaintyFlags: []
        )

        let csv = CSVExportService.gradebookCSV(setup: setup, submissions: [graph])

        XCTAssertTrue(csv.hasPrefix("\u{FEFF}\"student\""))
        let rows = try CSVParser.parseRows(csv.replacingOccurrences(of: "\u{FEFF}", with: ""))
        XCTAssertEqual(rows.first, ["student", "local_id", "status", "total_score", "max_score", "ai_draft_suggestion"])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1], ["'-Jane", "'=ID1", "approved", "4", "4", "3"])
        XCTAssertFalse(csv.contains("Private grading note."))
        XCTAssertFalse(csv.contains("Private instructor comment."))
    }

    func testTeacherRecordIncludesPrivateNotesScannedTextStatusAndFingerprint() throws {
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Audit test", subject: "Science", rubricText: "Claim: 0-4 points"))
        var graph = try approvedGraph(setup: setup, privateNotes: "Private audit note here.")
        graph.submission.inputKind = .scanned
        graph.submission.pastedText = nil
        let line = OCRLine(text: "Student text", confidence: 0.95, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        graph.ocr = OCRDocument(pages: [OCRPage(pageIndex: 0, lines: [line])], reviewStatus: .reviewed)
        let currentFingerprint = try graph.packetFingerprint(setup: setup)
        graph.finalReview?.packetFingerprint = currentFingerprint

        let record = MarkdownRenderer.render(ReportBuilder.teacherRecord(setup: setup, submission: graph, generatedAt: Date()))

        XCTAssertTrue(record.contains("Private audit note here."), "Teacher record should include private notes")
        XCTAssertTrue(record.contains("Scanned text review status: Ready for teacher review"), "Teacher record should include scanned-text status")
        XCTAssertTrue(record.contains(try graph.packetFingerprint(setup: setup)), "Teacher record should include packet fingerprint")
    }

    func testTeacherArchiveFailsVisiblyWhenReferencedSourceFileIsMissing() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: nil)
        let database = try app.requireDatabase()
        let source = SourceInputRef(
            submissionID: seeded.submissionID, sourceType: .scan, localRelativePath: "Sources/\(seeded.submissionID.uuidString)/missing.png",
            fileName: "missing.png", includedInTeacherArchive: true
        )
        let line = OCRLine(text: "Text", confidence: 0.95, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [source],
            ocr: OCRDocument(pages: [OCRPage(sourceInputID: source.id, pageIndex: 0, lines: [line])], reviewStatus: .reviewed)
        )
        let session = try await openSession(app, seeded.submissionID)

        await session.prepareExport(.zipArchive)

        XCTAssertNil(session.preparedExport)
        XCTAssertTrue(session.alert?.message.contains("missing") == true)
        let graph = try await database.submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.exports.count, 0, "A failed export must not be recorded")
    }

    func testClipboardCopyBlocksBackupArchiveAndPDFArtifactsByDefault() {
        XCTAssertTrue(ExportKind.studentMarkdown.canCopyAsText)
        XCTAssertTrue(ExportKind.teacherAuditMarkdown.canCopyAsText)
        XCTAssertTrue(ExportKind.csvGradebook.canCopyAsText)

        for blockedKind in [ExportKind.studentPDF, .teacherAuditPDF, .zipArchive, .fullBackupArchive] {
            XCTAssertFalse(
                blockedKind.canCopyAsText,
                "\(blockedKind.displayName) must not be copied to the clipboard; create and share the file artifact instead."
            )
        }
    }

    func testPDFRendererWritesNonEmptyFiles() throws {
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "PDF", rubricText: "Claim: 0-1 points"))
        let graph = try approvedGraph(setup: setup, finalPoints: 1, privateNotes: "Private")

        let student = try PDFRenderer.render(ReportBuilder.studentReport(setup: setup, submission: graph, generatedAt: Date()))
        let audit = try PDFRenderer.render(ReportBuilder.teacherRecord(setup: setup, submission: graph, generatedAt: Date()))

        XCTAssertGreaterThan(student.count, 100)
        XCTAssertGreaterThan(audit.count, 100)
        XCTAssertEqual(String(decoding: student.prefix(4), as: UTF8.self), "%PDF")
        XCTAssertEqual(String(decoding: audit.prefix(4), as: UTF8.self), "%PDF")
    }

    func testTeacherArchiveContainsSnapshotAndTeacherRecordFiles() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Text")
        let session = try await openSession(app, seeded.submissionID)

        await session.prepareExport(.zipArchive)

        XCTAssertNil(session.alert)
        let export = try XCTUnwrap(session.preparedExport)
        let archive = try Archive(url: export.url, accessMode: .read)
        XCTAssertNotNil(archive["snapshot.json"])
        XCTAssertTrue(archive.contains { $0.path.hasSuffix(".md") }, "The archive holds the Teacher Record in Markdown")
        XCTAssertTrue(archive.contains { $0.path.hasSuffix(".pdf") }, "The archive holds the Teacher Record in PDF")
        session.finishSharing()
    }

    // MARK: - Export authentication gate

    func testTeacherRecordExportBlockedWhenAuthFails() async throws {
        let app = try TestApp.make(exportAuthentication: Self.denied)
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student text")
        let session = try await openSession(app, seeded.submissionID)

        await session.prepareExport(.teacherAuditMarkdown)

        XCTAssertNil(session.preparedExport, "Teacher-only export must be blocked when auth fails")
        XCTAssertEqual(session.alert?.message, "Denied")
        let graph = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.exports.count, 0)
    }

    func testGradebookCSVBlockedWhenAuthFails() async throws {
        let app = try TestApp.make(exportAuthentication: Self.denied)
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student text")
        let model = try await openSetupModel(app, seeded.assignmentID)

        await model.prepareGradebookCSV()

        XCTAssertNil(model.preparedExport, "Gradebook CSV must not be created when auth fails")
        XCTAssertNotNil(model.alert)
    }

    func testFullBackupBlockedWhenAuthFails() async throws {
        let app = try TestApp.make(exportAuthentication: Self.denied)
        _ = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student text")

        await app.backupRestore.createFullBackup(password: "pw")

        XCTAssertNil(app.backupRestore.preparedExport, "Full backup must not be created when auth fails")
        XCTAssertNotNil(app.backupRestore.alert)
    }

    func testAuthUnavailableAllowsExport() async throws {
        let unavailable = StubExportAuthenticationService(
            result: ExportAuthenticationResult(allowed: true, authenticationPerformed: false, message: "Device authentication is unavailable on this platform.")
        )
        let app = try TestApp.make(exportAuthentication: unavailable)
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student text")
        let session = try await openSession(app, seeded.submissionID)

        await session.prepareExport(.teacherAuditMarkdown)

        XCTAssertNil(session.alert, "Export should proceed when auth is unavailable but policy allows it")
        XCTAssertNotNil(session.preparedExport)
        session.finishSharing()
    }

    func testStudentReportDoesNotRequireAuthentication() async throws {
        let app = try TestApp.make(exportAuthentication: Self.denied)
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student text")
        try await saveApprovedReview(app, seeded)
        let session = try await openSession(app, seeded.submissionID)

        await session.prepareExport(.studentMarkdown)

        XCTAssertNil(session.alert, "Student-facing exports must not require authentication")
        XCTAssertEqual(session.preparedExport?.kind, .studentMarkdown)
        session.finishSharing()
    }

    // MARK: - Gradebook CSV

    func testGradebookCSVExportsEveryStudentOfTheAssignment() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: nil)
        try await app.requireDatabase().save(Student(displayName: "Bob"), enrolledIn: seeded.classGroupID)
        let model = try await openSetupModel(app, seeded.assignmentID)

        await model.prepareGradebookCSV()

        XCTAssertNil(model.alert)
        let export = try XCTUnwrap(model.preparedExport)
        XCTAssertEqual(export.kind, .csvGradebook)
        let content = try String(contentsOf: export.url, encoding: .utf8)
        XCTAssertTrue(content.contains("Kai"), "CSV must include the first student")
        XCTAssertTrue(content.contains("Bob"), "CSV must include the second student")
        model.finishSharing()
    }
}
