import GRDB
import XCTest
@testable import GradeDraft

private enum ImportTestError: Error {
    case injectedOCRFailure
}

private func regularFilesUnder(_ root: URL) -> [URL] {
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }
    return enumerator.compactMap { item in
        guard let url = item as? URL else { return nil }
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true ? url : nil
    }
}

extension GradeDraftTests {
    /// The store refuses a change to a record that is not there.
    fileprivate func assertNotFound(_ operation: () async throws -> Void, file: StaticString = #file, line: UInt = #line) async {
        do {
            try await operation()
            XCTFail("Expected the change to be refused.", file: file, line: line)
        } catch AppDatabaseError.notFound {
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    fileprivate func firstRubricCriterionID(_ app: AppModel, _ seeded: SeededSubmission) async throws -> String {
        let saved = try await app.requireDatabase().assignmentSetup(id: seeded.assignmentID)
        return try XCTUnwrap(try XCTUnwrap(saved).parsedRubric.criteria.first).id
    }

    /// A backup file of everything in the app's store.
    fileprivate func writeBackup(from app: AppModel, password: String = "pw") async throws -> URL {
        let snapshot = try await app.requireDatabase().backupSnapshot()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(UUID().uuidString).markformebackup")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return try BackupArchiveService.writeFullBackup(
            snapshot: snapshot, storageRoot: try app.requireStorageRoot(), password: password, appVersion: "1.0", to: url
        )
    }

    /// An in-memory approved review (no store) with the given fingerprint, or the current one.
    fileprivate func approvedGraph(setup: AssignmentSetup, fingerprint: String? = nil, privateNotes: String = "Sensitive private note.") throws -> SubmissionGraph {
        var graph = SubmissionGraph(
            submission: Submission(assignmentID: setup.id, studentID: UUID(), inputKind: .pasted, pastedText: "Student text"),
            student: Student(displayName: "Kai")
        )
        graph.finalReview = FinalGradeReview(
            packetFingerprint: try fingerprint ?? graph.packetFingerprint(setup: setup),
            status: .approved,
            criteria: [FinalCriterionScore(
                criterionID: setup.parsedRubric.criteria[0].id, rating: "Proficient", proposedPoints: 3, finalPoints: 4,
                explanation: "Clear claim.", teacherApproved: true
            )],
            studentFeedback: "Good claim.",
            privateTeacherNotes: privateNotes,
            teacherEdited: true
        )
        return graph
    }

    // MARK: - Approval and storage

    func testCanApproveAndPersistFinalReviewWhenAllCriteriaApproved() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student response")
        let criterion = FinalCriterionScore(
            criterionID: try await firstRubricCriterionID(app, seeded), rating: "Proficient", proposedPoints: 3, finalPoints: 3,
            explanation: "Strong claim.", teacherApproved: true
        )
        try await app.requireDatabase().saveFinalReview(
            FinalGradeReview(
                packetFingerprint: try await TestApp.fingerprint(app, seeded), criteria: [criterion],
                studentFeedback: "Good.", privateTeacherNotes: "Hidden", teacherEdited: true
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canApproveFinalReview, true)
        await session.approveFinalReview()

        XCTAssertNil(session.alert)
        let graph = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.finalReview?.status, .approved)
        XCTAssertNotNil(graph?.finalReview?.finalizedAt)
    }

    func testStoreRoundTripsDraftsAndDeletesAssignments() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Reviewed text")
        let database = try app.requireDatabase()
        let draft = GradeDraftResult(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            packetFingerprint: try await TestApp.fingerprint(app, seeded),
            studentResponseSummary: "Summary",
            criteria: [CriterionScore(
                criterionID: "claim", rating: "Proficient", proposedPoints: 2, evidenceQuotes: ["Evidence"],
                explanation: "Good", teacherReviewRequired: false
            )],
            studentFeedback: "Nice",
            teacherNotes: "",
            uncertaintyFlags: []
        )
        try await database.replaceDraft(draft, submissionID: seeded.submissionID)
        let other = Assignment(classGroupID: seeded.classGroupID, title: "Response", rubricText: "Claim: 0-2 points")
        try await database.createAssignment(other)

        let loaded = try await database.submission(id: seeded.submissionID)
        XCTAssertEqual(loaded?.draft, draft)
        let before = try await database.assignmentSummaries(inClass: nil)
        XCTAssertEqual(Set(before.map(\.id)), [seeded.assignmentID, other.id])

        await app.deleteAssignment(id: seeded.assignmentID)

        let after = try await database.assignmentSummaries(inClass: nil)
        XCTAssertEqual(after.map(\.id), [other.id])
    }

    func testDeletingAnAssignmentRemovesItsSubmissionsOnly() async throws {
        let app = try TestApp.make()
        let removed = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Removed work")
        let database = try app.requireDatabase()
        let kept = Assignment(classGroupID: removed.classGroupID, title: "Kept", rubricText: "Claim: 0-4 points")
        try await database.createAssignment(kept)
        let keptSubmissions = try await database.submissionSummaries(assignmentID: kept.id)
        XCTAssertEqual(keptSubmissions.count, 1)

        await app.deleteAssignment(id: removed.assignmentID)

        let removedAfter = try await database.submission(id: removed.submissionID)
        XCTAssertNil(removedAfter)
        let keptAfter = try await database.submissionSummaries(assignmentID: kept.id)
        XCTAssertEqual(keptAfter.map(\.id), keptSubmissions.map(\.id))
    }

    func testDeletingAStudentRemovesTheirSubmissionsOnly() async throws {
        let app = try TestApp.make()
        let first = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Alex's work")
        let database = try app.requireDatabase()
        let bri = Student(displayName: "Bri")
        try await database.save(bri, enrolledIn: first.classGroupID)
        let both = try await database.submissionSummaries(assignmentID: first.assignmentID)
        XCTAssertEqual(both.count, 2)

        _ = try await database.deleteStudent(id: first.studentID)

        let remaining = try await database.submissionSummaries(assignmentID: first.assignmentID)
        XCTAssertEqual(remaining.map(\.studentID), [bri.id])
        let deleted = try await database.submission(id: first.submissionID)
        XCTAssertNil(deleted)
    }

    func testSavingAnAssignmentKeepsItsSubmissions() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Work")
        let database = try app.requireDatabase()
        let before = try await database.submissionSummaries(assignmentID: seeded.assignmentID)
        let model = try await openSetupModel(app, seeded.assignmentID)

        model.edit { $0.assignment.title = "Draft updated" }
        await model.flushPendingEdits()

        let after = try await database.submissionSummaries(assignmentID: seeded.assignmentID)
        XCTAssertEqual(after.map(\.id), before.map(\.id))
        XCTAssertEqual(after.first?.assignmentTitle, "Draft updated")
    }

    func testFailedStudentDeleteLeavesTheStoreUnchanged() async throws {
        let app = try TestApp.make()
        _ = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Work")
        let database = try app.requireDatabase()
        let before = try await database.backupSnapshot()

        await assertNotFound { _ = try await database.deleteStudent(id: UUID()) }

        let after = try await database.backupSnapshot()
        XCTAssertEqual(after, before)
    }

    func testRosterImportIntoAMissingClassFailsWithoutSavingAnything() async throws {
        let app = try TestApp.make()
        let database = try app.requireDatabase()

        await assertNotFound {
            _ = try await database.importRoster([RosterImportRow(displayName: "Alice", localIdentifier: "A1")], into: UUID())
        }

        let students = try await database.students(inClass: nil)
        XCTAssertTrue(students.isEmpty)
        let classes = try await database.classGroups()
        XCTAssertTrue(classes.isEmpty)
    }

    func testRosterImportSurfacesAFailureToTheTeacher() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: nil)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("roster-\(UUID().uuidString).csv")
        try Data("displayName,localIdentifier\nNew Student,N-1".utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let model = RosterModel(classGroupID: seeded.classGroupID, app: app)
        model.previewRosterFile(at: url)
        await app.deleteClass(id: seeded.classGroupID)

        await model.confirmRosterImport()

        XCTAssertNotNil(model.alert)
        XCTAssertNil(model.lastImportResult)
    }

    func testMigrationIsIdempotent() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("migrate-\(UUID().uuidString).sqlite")
        addTeardownBlock { try? FileManager.default.removeItem(at: file) }
        let queue = try DatabaseQueue(path: file.path)

        try AppDatabase.makeMigrator().migrate(queue)
        XCTAssertNoThrow(try AppDatabase.makeMigrator().migrate(queue))
        XCTAssertTrue(try queue.read { try $0.tableExists("assignment") })
    }

    func testPromptPersistsInStoreRoundTrip() async throws {
        let app = try TestApp.make()
        let classID = await app.addClass(name: "6A")
        let database = try app.requireDatabase()
        let assignment = Assignment(classGroupID: try XCTUnwrap(classID), title: "Prompt persistence test", prompt: "Describe the water cycle.")

        try await database.createAssignment(assignment)

        let loaded = try await database.assignmentSetup(id: assignment.id)
        XCTAssertEqual(loaded?.assignment.prompt, "Describe the water cycle.")
    }

    // MARK: - Reports

    func testStudentReportExcludesPrivateTeacherNotes() throws {
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Response 1", subject: "ELA", rubricText: "Claim: 0-4 points"))
        let graph = try approvedGraph(setup: setup)

        let student = MarkdownRenderer.render(try ReportBuilder.studentReport(setup: setup, submission: graph, generatedAt: Date()))
        XCTAssertTrue(student.contains("Final teacher-approved grade"))
        XCTAssertTrue(student.contains("Good claim."))
        XCTAssertFalse(student.contains("Sensitive private note"))

        let audit = MarkdownRenderer.render(ReportBuilder.teacherRecord(setup: setup, submission: graph, generatedAt: Date()))
        XCTAssertTrue(audit.contains("Sensitive private note"))
    }

    /// The model's raw response is no longer kept on the draft, so this checks what is still stored: the
    /// draft's private teacher notes never reach the student report.
    func testStudentReportExcludesModelDraftNotes() throws {
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Essay", subject: "ELA", rubricText: "Claim: 0-4 points"))
        var graph = try approvedGraph(setup: setup, privateNotes: "")
        graph.draft = GradeDraftResult(
            packetFingerprint: "draft-packet", studentResponseSummary: "Summary", criteria: [],
            studentFeedback: "Draft feedback", teacherNotes: "Private model note.", uncertaintyFlags: []
        )
        graph.finalReview?.studentFeedback = "Teacher final feedback."

        let report = MarkdownRenderer.render(try ReportBuilder.studentReport(setup: setup, submission: graph, generatedAt: Date()))

        XCTAssertFalse(report.contains("Private model note"), "Student report must not include the draft's private notes")
        XCTAssertFalse(report.contains("Draft feedback"), "Student report must not include the AI draft's feedback")
        XCTAssertTrue(report.contains("Teacher final feedback"), "Student report should include teacher final feedback")
    }

    /// Evidence is quoted by text only; the scanned-text line it came from is never named.
    func testStudentReportDoesNotExposeEvidenceSourceReferences() throws {
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Privacy", rubricText: "Claim: 0-4 points"))
        var graph = try approvedGraph(setup: setup, privateNotes: "Private")
        let lineID = UUID()
        let evidence = EvidenceReference(
            submissionID: graph.submission.id, ocrLineID: lineID, pageIndex: 0, quote: "Evidence",
            boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4), sourceKind: .ocrLine, teacherConfirmed: true
        )
        graph.evidence = [evidence]
        graph.finalReview?.criteria[0].evidenceIDs = [evidence.id]

        let report = MarkdownRenderer.render(try ReportBuilder.studentReport(setup: setup, submission: graph, generatedAt: Date()))

        XCTAssertTrue(report.contains("Evidence"))
        XCTAssertFalse(report.contains(String(lineID.uuidString.prefix(8))))
        XCTAssertFalse(report.contains("source:"))
        XCTAssertFalse(report.contains("Private"))
    }

    func testEvidenceReferenceModelStoresBoundingBoxTraceability() {
        let lineID = UUID()
        let reference = EvidenceReference(
            submissionID: UUID(),
            ocrLineID: lineID,
            pageIndex: 0,
            quote: "Student evidence",
            startOffset: 0,
            endOffset: 16,
            boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            sourceKind: .ocrLine,
            teacherConfirmed: true
        )
        XCTAssertEqual(reference.ocrLineID, lineID)
        XCTAssertEqual(reference.boundingBox?.width, 0.3)
        XCTAssertTrue(reference.displaySource.contains("page 1"))
    }

    func testSourceInputStoresPDFMetadata() {
        let source = SourceInputRef(submissionID: UUID(), sourceType: .pdf, fileName: "work.pdf", mimeType: "application/pdf", pdfPageCount: 2)
        XCTAssertEqual(source.fileName, "work.pdf")
        XCTAssertEqual(source.mimeType, "application/pdf")
        XCTAssertEqual(source.pdfPageCount, 2)
    }

    // MARK: - Teacher actions on a final review

    func testRecommendedAIConstraintsExcludeSensitiveTemplates() {
        let assignment = Assignment(
            classGroupID: UUID(), title: "Short answer", assessmentPurpose: .summative,
            rubricText: "Claim: 0-2 points", answerKeyText: "Expected claim."
        )

        let ids = GradingConstraintTemplates.recommendedIDs(for: assignment, ocrPresent: false)

        XCTAssertFalse(ids.isEmpty)
        XCTAssertFalse(ids.contains("eald-sensitive"))
        XCTAssertFalse(ids.contains("adjustment-context"))
    }

    func testSavingPastedStudentWorkReplacesReviewedInputAndLeavesOldResultsStale() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Old text")
        let database = try app.requireDatabase()
        let fingerprint = try await TestApp.fingerprint(app, seeded)
        try await database.replaceDraft(
            GradeDraftResult(
                packetFingerprint: fingerprint, studentResponseSummary: "Old", criteria: [],
                studentFeedback: "Old", teacherNotes: "Old", uncertaintyFlags: []
            ),
            submissionID: seeded.submissionID
        )
        try await database.saveFinalReview(
            FinalGradeReview(
                packetFingerprint: fingerprint,
                criteria: [FinalCriterionScore(
                    criterionID: try await firstRubricCriterionID(app, seeded), rating: "", proposedPoints: 1, finalPoints: 1,
                    explanation: "", teacherApproved: true
                )],
                studentFeedback: "", privateTeacherNotes: "", teacherEdited: true
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)

        await session.savePastedText("  New student answer  ")

        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        let graphSaved = try await database.submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        XCTAssertEqual(graph.reviewedText, "New student answer")
        XCTAssertEqual(graph.submission.inputKind, .pasted)
        XCTAssertTrue(graph.sources.isEmpty)
        XCTAssertNotNil(graph.draft)
        XCTAssertNotNil(graph.finalReview)
        XCTAssertTrue(try graph.draftIsStale(setup: setup))
        XCTAssertTrue(try graph.finalReviewIsStale(setup: setup))
        XCTAssertNil(session.alert)
    }

    func testCriterionAcceptAndRejectActionsPersistTeacherDecision() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text.")
        let criterion = FinalCriterionScore(
            criterionID: try await firstRubricCriterionID(app, seeded), rating: "Developing", proposedPoints: 3, finalPoints: 0,
            explanation: "Draft explanation.", teacherApproved: false
        )
        try await app.requireDatabase().saveFinalReview(
            FinalGradeReview(
                packetFingerprint: try await TestApp.fingerprint(app, seeded), criteria: [criterion],
                studentFeedback: "", privateTeacherNotes: "", teacherEdited: false
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)

        session.acceptCriterion(criterion.id)
        XCTAssertEqual(session.review?.criteria.first?.finalPoints, 2, "Accepted points are kept within the criterion's maximum")
        XCTAssertEqual(session.review?.criteria.first?.teacherApproved, true)
        XCTAssertEqual(session.review?.status, .inProgress)

        session.rejectCriterion(criterion.id)
        XCTAssertEqual(session.review?.criteria.first?.teacherApproved, false)
        XCTAssertTrue(session.review?.criteria.first?.teacherRationale.contains("rejected") == true)

        await session.flushPendingEdits()
        let saved = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(saved?.finalReview?.criteria.first?.teacherApproved, false)
    }

    func testApprovedManualFinalReviewEnablesStudentExport() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-2 points", studentWork: "Student text.")
        try await app.requireDatabase().saveFinalReview(
            FinalGradeReview(
                packetFingerprint: try await TestApp.fingerprint(app, seeded),
                status: .approved,
                criteria: [FinalCriterionScore(
                    criterionID: try await firstRubricCriterionID(app, seeded), rating: "", proposedPoints: 0, finalPoints: 2,
                    explanation: "", teacherApproved: true
                )],
                studentFeedback: "Good work.", privateTeacherNotes: "", teacherEdited: true
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canExportStudentReport, true, "Approved manual final review should enable student export")
    }

    func testManualFinalReviewSurvivesStoreRoundTrip() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "", studentWork: "Student wrote this.") { assignment in
            assignment.answerKeyText = "Expected: a claim."
        }
        let review = FinalGradeReview(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            packetFingerprint: try await TestApp.fingerprint(app, seeded),
            criteria: [FinalCriterionScore(
                criterionID: "criterion-1", rating: "", proposedPoints: 0, finalPoints: 1, explanation: "Partial claim.",
                teacherApproved: false, teacherRationale: "Manual teacher-created final review.", title: "Claim", maxPoints: 2
            )],
            studentFeedback: "",
            privateTeacherNotes: "My private note",
            teacherEdited: false
        )
        try await app.requireDatabase().saveFinalReview(review, submissionID: seeded.submissionID)

        let loaded = try await app.requireDatabase().submission(id: seeded.submissionID)

        XCTAssertEqual(loaded?.finalReview, review)
        XCTAssertEqual(loaded?.finalReview?.criteria.count, 1)
        XCTAssertEqual(loaded?.finalReview?.criteria[0].title, "Claim")
        XCTAssertEqual(loaded?.finalReview?.criteria[0].finalPoints, 1)
        XCTAssertEqual(loaded?.finalReview?.privateTeacherNotes, "My private note")
    }

    func testStudentReportBlockedWithoutApprovedFinalReview() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student text.")
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.canExportStudentReport, false, "Student export blocked without final review")
    }

    func testStudentReportBlockedWhenFinalReviewIsStale() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student text.")
        try await app.requireDatabase().saveFinalReview(
            FinalGradeReview(
                packetFingerprint: "stale-fingerprint",
                status: .approved,
                criteria: [FinalCriterionScore(
                    criterionID: try await firstRubricCriterionID(app, seeded), rating: "", proposedPoints: 3, finalPoints: 3,
                    explanation: "Good.", teacherApproved: true
                )],
                studentFeedback: "Good.", privateTeacherNotes: "", teacherEdited: true
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)

        XCTAssertEqual(session.readiness?.finalReviewIsStale, true, "Final review should be stale")
        XCTAssertEqual(session.readiness?.canExportStudentReport, false, "Student export blocked when stale")
    }

    func testDeleteAssignmentRemovesRecord() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: nil)

        await app.deleteAssignment(id: seeded.assignmentID)

        let setup = try await app.requireDatabase().assignmentSetup(id: seeded.assignmentID)
        XCTAssertNil(setup, "Deleted assignment should not remain")
    }

    // MARK: - Roster status

    func testRosterStatusStaleReviewBeatsExported() throws {
        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Stale", rubricText: "Claim: 0-4 points"))
        var graph = try approvedGraph(setup: setup, fingerprint: "OLD-STALE-FINGERPRINT")
        graph.exports = [ExportRecord(
            assignmentID: setup.id, submissionID: graph.submission.id, kind: .studentPDF, contentSHA256: "fp",
            includesPrivateTeacherNotes: false, includesOriginalSources: false
        )]

        XCTAssertEqual(try graph.rosterStatus(setup: setup), .needsRecheck, "Stale final review must produce needsRecheck, not exported")
    }

    func testRosterStatusNeedsRecheckDisplayName() {
        XCTAssertEqual(RosterStatus.needsRecheck.displayName, "Needs recheck")
    }

    func testRosterStatusNeedsRecheckUIStatus() {
        XCTAssertEqual(RosterStatus.needsRecheck.uiStatus, .needsRecheck)
    }

    // MARK: - Backup and restore

    func testFullBackupCanBeReadBack() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Text") { $0.title = "Backup" }
        let url = try await writeBackup(from: app)

        let preview = try await BackupArchiveService.prepareRestore(
            from: url, password: "pw", storageRoot: try app.requireStorageRoot(), database: try app.requireDatabase()
        )
        addTeardownBlock { BackupArchiveService.discard(preview) }

        XCTAssertEqual(preview.snapshot.assignments.map(\.assignment.title), ["Backup"])
        XCTAssertEqual(preview.snapshot.submissions.first?.reviewedText, "Text")
        XCTAssertEqual(preview.conflictingAssignmentIDs, [seeded.assignmentID])
    }

    func testPreviewBackupRestoreDoesNotMutateLocalData() async throws {
        let app = try TestApp.make()
        _ = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Local text") { $0.title = "Local" }
        let url = try await writeBackup(from: app)
        let before = try await app.requireDatabase().backupSnapshot()

        await app.backupRestore.prepareRestore(from: url, password: "pw")

        XCTAssertNotNil(app.backupRestore.preview, "A pending restore preview must be set")
        let after = try await app.requireDatabase().backupSnapshot()
        XCTAssertEqual(after, before, "Preview must not mutate local data")
        app.backupRestore.discardRestore()
    }

    func testCancelPendingRestoreDoesNotMutate() async throws {
        let app = try TestApp.make()
        _ = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Local text") { $0.title = "Local" }
        let url = try await writeBackup(from: app)
        let before = try await app.requireDatabase().backupSnapshot()
        await app.backupRestore.prepareRestore(from: url, password: "pw")
        let staging = try XCTUnwrap(app.backupRestore.preview?.stagingDirectory)

        app.backupRestore.discardRestore()

        XCTAssertNil(app.backupRestore.preview, "Pending restore preview must be cleared")
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path), "The staged files must be removed")
        let after = try await app.requireDatabase().backupSnapshot()
        XCTAssertEqual(after, before, "Cancel must not mutate local data")
    }

    func testConfirmPendingRestoreAddsAssignmentsFromTheBackup() async throws {
        let backupApp = try TestApp.make()
        _ = try await TestApp.seed(backupApp, rubric: "Claim: 0-4 points", studentWork: "Backup text") { $0.title = "New From Backup" }
        let url = try await writeBackup(from: backupApp)
        let app = try TestApp.make()
        _ = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Local text") { $0.title = "Local" }

        await app.backupRestore.prepareRestore(from: url, password: "pw")
        XCTAssertEqual(app.backupRestore.preview?.conflictingAssignmentIDs, [])
        let before = try await app.requireDatabase().assignmentSummaries(inClass: nil)
        XCTAssertEqual(before.count, 1, "Before confirm, assignments unchanged")
        await app.backupRestore.commitRestore()

        XCTAssertEqual(app.backupRestore.alert?.message, RestoreOutcome.completeMessage)
        let after = try await app.requireDatabase().assignmentSummaries(inClass: nil)
        XCTAssertEqual(Set(after.map(\.assignment.title)), ["Local", "New From Backup"])
    }

    // MARK: - Clearing student work and importing

    func testClearingStudentWorkKeepsSourceFilesWhenNothingWasSaved() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: nil)
        let database = try app.requireDatabase()
        let root = try app.requireStorageRoot()
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let relativePath = "Sources/\(seeded.submissionID.uuidString)/page-1.txt"
        let sourceURL = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("source".utf8).write(to: sourceURL)
        let source = SourceInputRef(submissionID: seeded.submissionID, sourceType: .scan, localRelativePath: relativePath, fileName: "page-1.txt")
        let line = OCRLine(text: "Reviewed text", confidence: 0.95, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [source],
            ocr: OCRDocument(pages: [OCRPage(sourceInputID: source.id, pageIndex: 0, lines: [line])], reviewStatus: .reviewed)
        )
        let session = try await openSession(app, seeded.submissionID)

        // The submission is deleted before the action runs: nothing is saved, so nothing may be deleted.
        _ = try await database.deleteStudent(id: seeded.studentID)
        try await waitForCondition { session.isMissing }
        await session.clearStudentWork()
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "Source files must not be removed when nothing was saved.")
    }

    func testClearingStudentWorkRemovesFilesAfterSaving() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: nil)
        let database = try app.requireDatabase()
        let root = try app.requireStorageRoot()
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let relativePath = "Sources/\(seeded.submissionID.uuidString)/page-1.txt"
        let sourceURL = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("source".utf8).write(to: sourceURL)
        let source = SourceInputRef(submissionID: seeded.submissionID, sourceType: .scan, localRelativePath: relativePath, fileName: "page-1.txt")
        let line = OCRLine(text: "Reviewed text", confidence: 0.95, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [source],
            ocr: OCRDocument(pages: [OCRPage(sourceInputID: source.id, pageIndex: 0, lines: [line])], reviewStatus: .reviewed)
        )
        let session = try await openSession(app, seeded.submissionID)

        await session.clearStudentWork()

        let graph = try await database.submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.submission.inputKind, SubmissionInputKind.none)
        XCTAssertTrue(graph?.sources.isEmpty == true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertNil(session.alert)
    }

    func testPhotoImportLeavesPreviousWorkWhenTextRecognitionFails() async throws {
        let app = try TestApp.make(makeImporter: { root in TestImporter(root: root, failure: ImportTestError.injectedOCRFailure) })
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Previous reviewed text")
        let root = try app.requireStorageRoot()
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let session = try await openSession(app, seeded.submissionID)

        session.importPhotos([Data()])
        await app.backgroundWork.waitUntilFinished(submissionID: seeded.submissionID)

        XCTAssertTrue(regularFilesUnder(root).isEmpty, "Failed text recognition must leave no student source files.")
        let graph = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.reviewedText, "Previous reviewed text")
        XCTAssertTrue(graph?.sources.isEmpty == true)
        XCTAssertNil(graph?.ocr)
        XCTAssertNotNil(app.backgroundWork.failures[seeded.submissionID])
    }

    func testPhotoImportRollsBackFilesAndSavedWorkWhenSaveFails() async throws {
        try await assertImportSaveFailureRollsBack(previousText: "Previous reviewed text") { session in
            session.importPhotos([Data()])
        }
    }

    func testPDFImportRollsBackOriginalAndRenderedSourcesWhenSaveFails() async throws {
        try await assertImportSaveFailureRollsBack(previousText: "Previous PDF text") { session in
            session.importPDF(at: FileManager.default.temporaryDirectory.appendingPathComponent("not-read.pdf"))
        }
    }

    /// The import writes its files, then the store refuses the save (two source records share an ID). The files
    /// are removed, the earlier work is unchanged, and the failure is reported.
    private func assertImportSaveFailureRollsBack(previousText: String, start: (SubmissionSession) -> Void) async throws {
        let gate = TestGate()
        let app = try TestApp.make(makeImporter: { root in
            TestImporter(root: root, gate: gate, writesFiles: true, duplicatesSourceID: true)
        })
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: previousText)
        let root = try app.requireStorageRoot()
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let session = try await openSession(app, seeded.submissionID)

        start(session)
        try await waitForCondition { await gate.hasWaiter }
        XCTAssertFalse(regularFilesUnder(root).isEmpty, "The import has written its files before the save")
        await gate.open()
        await app.backgroundWork.waitUntilFinished(submissionID: seeded.submissionID)

        XCTAssertTrue(regularFilesUnder(root).isEmpty, "A failed save must remove the copied student source files.")
        let graph = try await app.requireDatabase().submission(id: seeded.submissionID)
        XCTAssertEqual(graph?.reviewedText, previousText)
        XCTAssertEqual(graph?.submission.inputKind, .pasted)
        XCTAssertTrue(graph?.sources.isEmpty == true)
        XCTAssertNil(graph?.ocr)
        XCTAssertNotNil(app.backgroundWork.failures[seeded.submissionID])
    }
}
