import XCTest
@testable import GradeDraft

// MARK: - LocalOnlyGradingValidator

final class LocalOnlyGradingValidatorHardeningTests: XCTestCase {
    func testValidInputDoesNotThrow() {
        let input = GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Test",
            prompt: "",
            subject: "",
            gradeLevel: "",
            className: "",
            studentDisplayName: "",
            assignmentType: .essay,
            rubricText: "Claim: 0-4 points",
            parsedRubric: RubricParser.parse("Claim: 0-4 points"),
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: "Student text",
            reviewedTextWithSourceRefs: "Student text",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .notNeeded,
            sourceInputCount: 0,
            packetFingerprint: "fp",
            hasGradingStandard: true
        )
        XCTAssertNoThrow(try LocalOnlyGradingValidator.validate(input))
    }

    func testBlockedOCRThrows() {
        let input = GradingInput(
            assignmentID: UUID(),
            assignmentTitle: "Test",
            prompt: "",
            subject: "",
            gradeLevel: "",
            className: "",
            studentDisplayName: "",
            assignmentType: .essay,
            rubricText: "Claim: 0-4 points",
            parsedRubric: RubricParser.parse("Claim: 0-4 points"),
            customInstructions: "",
            answerKeyText: "",
            exemplarText: "",
            assessmentPurpose: .summative,
            curriculumReference: "",
            reviewedStudentText: "Student text",
            reviewedTextWithSourceRefs: "Student text",
            ocrQualitySummary: OCRQualitySummary(),
            ocrReviewStatus: .blocked,
            sourceInputCount: 0,
            packetFingerprint: "fp",
            hasGradingStandard: true
        )
        XCTAssertThrowsError(try LocalOnlyGradingValidator.validate(input)) { error in
            XCTAssertEqual(error as? GradeDraftError, .ocrReviewRequired)
        }
    }
}

// MARK: - All-features completion v3 coverage

@MainActor
final class AllFeaturesCompletionV3Tests: XCTestCase {
    func testMarkdownRubricParserSupportsHeadingsListsTablesLevelsDuplicatesAndPreview() {
        // The reader takes its structure from the Markdown syntax tree, so a table needs a blank line before it
        // (otherwise it is read as part of the list item above it).
        let markdown = """
        # Argument writing
        - [claim] Claim: 0-4 points. Excellent 4 points: precise claim. Beginning 0-1 points: missing claim.
        1. Evidence: 0-3 pts. Proficient 3 points: relevant evidence.

        | Criterion ID | Criterion | Max Points | Excellent | Developing |
        | --- | --- | ---: | --- | --- |
        | reasoning | Reasoning | 4 | 4 points: explains how evidence supports claim | 1-2 points: limited explanation |
        | duplicate | Claim | 4 | 4 points: duplicate claim | 1 point: duplicate |
        """

        let preview = MarkdownRubricParser.preview(markdown)
        XCTAssertEqual(preview.parsedRubric.groups, ["Argument writing"])
        XCTAssertTrue(preview.detectedCriteria.contains { $0.id == "claim" && $0.groupTitle == "Argument writing" })
        XCTAssertTrue(preview.detectedCriteria.contains { $0.title == "Evidence" })
        XCTAssertTrue(preview.detectedCriteria.contains { $0.id == "reasoning" && $0.title == "Reasoning" })
        XCTAssertTrue(preview.detectedLevels.contains { $0.label.localizedCaseInsensitiveContains("Excellent") })
        XCTAssertTrue(preview.issues.contains { $0.message.localizedCaseInsensitiveContains("Duplicate criterion") })
        XCTAssertTrue(preview.fallbackRawTextAvailable)
    }

    func testCurriculumCatalogLoadsFiltersMapsPersistsAndAvoidsEndorsementClaims() async throws {
        let catalog = CurriculumCatalogService()
        let facets = try await catalog.facets()
        XCTAssertFalse(facets.learningAreas.isEmpty)
        let englishYear7 = try await catalog.search("", learningArea: "English", yearLevel: "Year 7")
        XCTAssertFalse(englishYear7.isEmpty)
        XCTAssertFalse(CurriculumCatalogService.sourceWarning.localizedCaseInsensitiveContains("endorsed by"))
        XCTAssertFalse(CurriculumCatalogService.sourceWarning.localizedCaseInsensitiveContains("certified by"))
        let item = try XCTUnwrap(englishYear7.first)

        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student response")
        let database = try app.requireDatabase()
        let beforeSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let before = try XCTUnwrap(beforeSaved)
        let fingerprintBefore = try before.setupFingerprint

        let model = try await openSetupModel(app, seeded.assignmentID)
        model.edit { $0.assignment.curriculumReference = CurriculumCatalogService.selectedReferenceSummary(items: [item]) }
        await model.addMapping(itemID: item.id)

        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        XCTAssertEqual(setup.curriculumMappings.map(\.curriculumItemID), [item.id])
        XCTAssertEqual(try setup.setupFingerprint.count, 64, "Fingerprints are SHA-256 hex")
        XCTAssertNotEqual(try setup.setupFingerprint, fingerprintBefore)

        let graphSaved = try await database.submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        let record = MarkdownRenderer.render(ReportBuilder.teacherRecord(setup: setup, submission: graph, generatedAt: Date()))
        XCTAssertTrue(record.contains(item.code))
        XCTAssertTrue(record.contains("Curriculum references"))
        let input = try GradingPacketBuilder.gradingInput(setup: setup, graph: graph, className: "6A", mappedItems: [])
        let prompt = PromptBuilder.gradingInstructionsText() + "\n" + PromptBuilder.fullPacketPromptText(input: input, mode: .full)
        XCTAssertTrue(prompt.contains(item.code))
    }

    func testRosterCSVPreviewRejectedRowsAndGradebookCSV() throws {
        let csv = """
        displayName,localIdentifier,className,notes
        Alice,A1,6A,
        Bob,A2,6A,
        Alice,A3,6A,same name with a different identifier is allowed
        ,A4,6A,missing name
        Chris,A2,6A,duplicate identifier rejected
        """
        let (rows, result) = RosterImportService.parse(text: csv)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.map(\.localIdentifier), ["A1", "A2", "A3"])
        XCTAssertEqual(result.skippedRows.count, 2)
        XCTAssertTrue(result.warnings.contains("Duplicate display names detected; use localIdentifier values to distinguish students."))
        XCTAssertTrue(result.hasHeaderRow)

        let setup = AssignmentSetup(assignment: Assignment(classGroupID: UUID(), title: "Essay", rubricText: "Claim: 0-4 points"))
        let alice = try approvedGraph(setup: setup, student: "Alice", score: 4)
        let bob = try approvedGraph(setup: setup, student: "Bob", score: 3)
        let csvOutput = CSVExportService.gradebookCSV(setup: setup, submissions: [alice, bob])
        XCTAssertTrue(csvOutput.contains("Alice"))
        XCTAssertTrue(csvOutput.contains("Bob"))
        XCTAssertTrue(csvOutput.contains("approved"))
    }

    func testOCRLineEvidenceLinkingBoundingBoxRemovalAndStudentPrivacy() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: nil)
        let database = try app.requireDatabase()
        let line = OCRLine(
            text: "The quote supports my claim.",
            confidence: 0.99,
            boundingBox: NormalizedRect(x: 0.12, y: 0.22, width: 0.45, height: 0.08),
            origin: .visionOCR,
            teacherConfirmed: true
        )
        let source = SourceInputRef(
            submissionID: seeded.submissionID, sourceType: .pdf, pageIndex: 1,
            localRelativePath: "Sources/\(seeded.submissionID.uuidString)/page-2.png"
        )
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [source],
            ocr: OCRDocument(pages: [OCRPage(sourceInputID: source.id, pageIndex: 1, lines: [line])], reviewStatus: .reviewed)
        )
        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        let criterion = FinalCriterionScore(
            criterionID: setup.parsedRubric.criteria[0].id, rating: "Proficient", proposedPoints: 3, finalPoints: 3,
            explanation: "The response supports a claim."
        )
        try await database.saveFinalReview(
            FinalGradeReview(
                packetFingerprint: try await TestApp.fingerprint(app, seeded),
                criteria: [criterion],
                studentFeedback: "Teacher-approved feedback.",
                privateTeacherNotes: "Private teacher notes.",
                teacherEdited: true
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)

        await session.addLineEvidence(lineID: line.id, to: criterion.id)

        let graphSaved = try await database.submission(id: seeded.submissionID)
        var graph = try XCTUnwrap(graphSaved)
        let evidence = try XCTUnwrap(graph.evidence.first)
        XCTAssertEqual(graph.evidence.count, 1)
        XCTAssertEqual(evidence.ocrLineID, line.id)
        XCTAssertEqual(evidence.boundingBox?.stableDisplay, "x:0.1200 y:0.2200 w:0.4500 h:0.0800")
        XCTAssertEqual(session.review?.criteria[0].evidenceIDs, [evidence.id])

        let teacherRecord = MarkdownRenderer.render(ReportBuilder.teacherRecord(setup: setup, submission: graph, generatedAt: Date()))
        XCTAssertTrue(teacherRecord.contains("The quote supports my claim."))
        XCTAssertTrue(teacherRecord.contains("page 2"))
        XCTAssertTrue(teacherRecord.contains("bbox: x:0.1200 y:0.2200 w:0.4500 h:0.0800"))

        session.acceptCriterion(criterion.id)
        await session.approveFinalReview()
        XCTAssertNil(session.alert)
        graph = try await load(database, seeded.submissionID)
        let studentReport = try MarkdownRenderer.render(ReportBuilder.studentReport(setup: setup, submission: graph, generatedAt: Date()))
        XCTAssertTrue(studentReport.contains("The quote supports my claim."))
        XCTAssertFalse(studentReport.contains("bbox"))
        XCTAssertFalse(studentReport.contains("source:"))
        XCTAssertFalse(studentReport.contains("0.4500"))

        await session.removeEvidence(evidence.id, from: criterion.id)
        graph = try await load(database, seeded.submissionID)
        XCTAssertTrue(graph.evidence.isEmpty)
        XCTAssertTrue(graph.finalReview?.criteria[0].evidenceIDs.isEmpty ?? false)
    }

    func testManualEvidenceAddAndClearKeepsEvidenceAndCriterionAligned() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "The quote supports my claim.")
        let database = try app.requireDatabase()
        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        let criterion = FinalCriterionScore(
            criterionID: setup.parsedRubric.criteria[0].id, rating: "", proposedPoints: 0, finalPoints: 0, explanation: ""
        )
        try await database.saveFinalReview(
            FinalGradeReview(
                packetFingerprint: try await TestApp.fingerprint(app, seeded),
                criteria: [criterion], studentFeedback: "", privateTeacherNotes: "", teacherEdited: false
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)

        await session.addManualEvidence(quote: "Teacher-entered quote", to: criterion.id)

        let graphSaved = try await database.submission(id: seeded.submissionID)
        var graph = try XCTUnwrap(graphSaved)
        XCTAssertEqual(graph.evidence.map(\.quote), ["Teacher-entered quote"])
        XCTAssertEqual(graph.evidence.first?.sourceKind, .manualTeacherEntry)
        let evidenceID = try XCTUnwrap(graph.evidence.first?.id)
        XCTAssertEqual(session.review?.criteria[0].evidenceIDs, [evidenceID])

        await session.removeEvidence(evidenceID, from: criterion.id)

        graph = try await load(database, seeded.submissionID)
        XCTAssertTrue(graph.evidence.isEmpty)
        XCTAssertTrue(session.review?.criteria[0].evidenceIDs.isEmpty ?? false)
        XCTAssertTrue(graph.finalReview?.criteria[0].evidenceIDs.isEmpty ?? false)
    }

    func testFullBackupIncludesAllRecordTypesManifestSafePathsAndRestoresSources() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: nil)
        let database = try app.requireDatabase()
        let root = try app.requireStorageRoot()
        let sourceFile = try writeSource(root: root, submissionID: seeded.submissionID, bytes: "source bytes")
        let line = OCRLine(text: "Evidence", confidence: 1, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        let source = SourceInputRef(
            submissionID: seeded.submissionID, sourceType: .pdf, pageIndex: 0, localRelativePath: sourceFile.relativePath,
            fileName: "work.pdf", mimeType: "application/pdf", sha256: ContentDigest.sha256Hex(Data("source bytes".utf8)),
            pdfPageCount: 1, includedInTeacherArchive: true
        )
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [source],
            ocr: OCRDocument(pages: [OCRPage(sourceInputID: source.id, pageIndex: 0, lines: [line])], reviewStatus: .reviewed)
        )
        try await database.addEvidence(
            EvidenceReference(
                submissionID: seeded.submissionID, ocrLineID: line.id, pageIndex: 0, quote: "Evidence",
                boundingBox: NormalizedRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2), sourceKind: .ocrLine, teacherConfirmed: true
            ),
            submissionID: seeded.submissionID
        )
        try await database.recordExport(ExportRecord(
            assignmentID: seeded.assignmentID, submissionID: seeded.submissionID, kind: .teacherAuditPDF,
            contentSHA256: "fp", includesPrivateTeacherNotes: true, includesOriginalSources: true
        ))
        try await database.appendAudit(AuditEvent(
            assignmentID: seeded.assignmentID, submissionID: seeded.submissionID, eventType: .exportPrepared, detail: "Prepared export."
        ))
        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        var setup = try XCTUnwrap(setupSaved)
        setup.curriculumMappings = [CurriculumMapping(assignmentID: seeded.assignmentID, curriculumItemID: "acara-item-1", mappingKind: "assignment")]
        try await database.saveSetup(setup)

        let snapshot = try await database.backupSnapshot()
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("V3Backup-\(UUID().uuidString).markformebackup")
        addTeardownBlock { try? FileManager.default.removeItem(at: destination) }
        let written = try BackupArchiveService.writeFullBackup(
            snapshot: snapshot, storageRoot: root, password: "correct horse", appVersion: "1.0", to: destination
        )
        let preview = try await BackupArchiveService.prepareRestore(from: written, password: "correct horse", storageRoot: root, database: database)

        XCTAssertEqual(preview.conflictingAssignmentIDs, [seeded.assignmentID])
        XCTAssertEqual(preview.classCount, 1)
        XCTAssertEqual(preview.studentCount, 1)
        XCTAssertEqual(preview.assignmentCount, 1)
        XCTAssertEqual(preview.sourceFileCount, 1)
        XCTAssertEqual(preview.manifest.sourceSHA256.keys.sorted(), ["sources/\(seeded.submissionID.uuidString)/page-1.png"])
        XCTAssertFalse(preview.manifest.sourceSHA256.keys.contains { $0.contains("..") })
        let backedUp = try XCTUnwrap(preview.snapshot.submissions.first)
        XCTAssertEqual(backedUp.sources.count, 1)
        XCTAssertEqual(backedUp.evidence.count, 1)
        XCTAssertEqual(backedUp.exports.count, 1)
        XCTAssertTrue(backedUp.audit.contains { $0.eventType == .exportPrepared })
        XCTAssertEqual(backedUp.ocr?.allLines.map(\.rawText), ["Evidence"])
        XCTAssertEqual(preview.snapshot.assignments.first?.curriculumMappings.count, 1)

        let outcome = try await BackupArchiveService.commitRestore(
            preview, resolutions: [seeded.assignmentID: .restoreAsCopy], database: database, storageRoot: root
        )
        let copiedID = try XCTUnwrap(outcome.copiedAssignmentIDs[seeded.assignmentID])
        XCTAssertNotEqual(copiedID, seeded.assignmentID)
        let copiedSubmissionSaved = try await database.submissionSummaries(assignmentID: copiedID).first
        let copiedSubmission = try XCTUnwrap(copiedSubmissionSaved)
        let copiedGraphSaved = try await database.submission(id: copiedSubmission.id)
        let copiedGraph = try XCTUnwrap(copiedGraphSaved)
        let copiedPath = try XCTUnwrap(copiedGraph.sources.first?.localRelativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(copiedPath).path))
    }

    func testRestoreAsCopyRemapsConflictingAssignmentSourcePaths() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: nil)
        let database = try app.requireDatabase()
        let root = try app.requireStorageRoot()
        let sourceFile = try writeSource(root: root, submissionID: seeded.submissionID, bytes: "source bytes")
        let source = SourceInputRef(
            submissionID: seeded.submissionID, sourceType: .pdf, pageIndex: 0, localRelativePath: sourceFile.relativePath,
            fileName: "work.pdf", mimeType: "application/pdf", pdfPageCount: 1, includedInTeacherArchive: true
        )
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [source],
            ocr: OCRDocument(pages: [OCRPage(sourceInputID: source.id, pageIndex: 0, lines: [])])
        )
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("V3CopyBackup-\(UUID().uuidString).markformebackup")
        addTeardownBlock { try? FileManager.default.removeItem(at: destination) }
        let written = try BackupArchiveService.writeFullBackup(
            snapshot: try await database.backupSnapshot(), storageRoot: root, password: "pw", appVersion: "1.0", to: destination
        )
        // The file already on this device (same path) holds different bytes than the backup.
        try Data("local-only bytes".utf8).write(to: sourceFile.url)

        let preview = try await BackupArchiveService.prepareRestore(from: written, password: "pw", storageRoot: root, database: database)
        let outcome = try await BackupArchiveService.commitRestore(
            preview, resolutions: [seeded.assignmentID: .restoreAsCopy], database: database, storageRoot: root
        )

        let copiedID = try XCTUnwrap(outcome.copiedAssignmentIDs[seeded.assignmentID])
        let copiedSubmissionSaved = try await database.submissionSummaries(assignmentID: copiedID).first
        let copiedSubmission = try XCTUnwrap(copiedSubmissionSaved)
        let copiedGraphSaved = try await database.submission(id: copiedSubmission.id)
        let copiedGraph = try XCTUnwrap(copiedGraphSaved)
        let copiedRelativePath = try XCTUnwrap(copiedGraph.sources.first?.localRelativePath)
        XCTAssertNotEqual(copiedSubmission.id, seeded.submissionID)
        XCTAssertEqual(copiedRelativePath, "Sources/\(copiedSubmission.id.uuidString)/page-1.png")
        let copiedText = try String(contentsOf: root.appendingPathComponent(copiedRelativePath), encoding: .utf8)
        XCTAssertEqual(copiedText, "source bytes")
        XCTAssertEqual(try String(contentsOf: sourceFile.url, encoding: .utf8), "local-only bytes")
    }

    func testBackupRestoreUIPathDetectsConflictAndRestoresAsCopy() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "Student text")
        let database = try app.requireDatabase()
        let restore = app.backupRestore

        await restore.createFullBackup(password: "pw")
        XCTAssertNil(restore.alert)
        let backup = try XCTUnwrap(restore.preparedExport)
        await restore.prepareRestore(from: backup.url, password: "pw")

        XCTAssertEqual(restore.preview?.conflictingAssignmentIDs, [seeded.assignmentID])
        XCTAssertFalse(restore.canCommitRestore, "Each conflicting assignment needs the teacher's choice")
        restore.setResolution(.restoreAsCopy, for: seeded.assignmentID)
        XCTAssertTrue(restore.canCommitRestore)
        await restore.commitRestore()

        XCTAssertEqual(restore.alert?.message, RestoreOutcome.completeMessage)
        let assignments = try await database.assignmentSummaries(inClass: nil)
        XCTAssertEqual(assignments.count, 2)
        XCTAssertEqual(Set(assignments.map(\.assignment.title)), ["Essay"])
        XCTAssertTrue(assignments.contains { $0.id == seeded.assignmentID })
    }

    func testNormalizedStoreLoadsEveryRelatedRecord() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: nil)
        let database = try app.requireDatabase()
        let line = OCRLine(text: "Line", confidence: 1, boundingBox: .zero, origin: .visionOCR, teacherConfirmed: true)
        let source = SourceInputRef(
            submissionID: seeded.submissionID, sourceType: .pdf, pageIndex: 0,
            localRelativePath: "Sources/\(seeded.submissionID.uuidString)/page.png", pdfPageCount: 1
        )
        _ = try await database.replaceInput(
            submissionID: seeded.submissionID, kind: .scanned, pastedText: nil, sources: [source],
            ocr: OCRDocument(pages: [OCRPage(sourceInputID: source.id, pageIndex: 0, lines: [line])], reviewStatus: .reviewed)
        )
        let evidence = EvidenceReference(
            submissionID: seeded.submissionID, ocrLineID: line.id, pageIndex: 0, quote: "Line", boundingBox: .zero,
            sourceKind: .ocrLine, teacherConfirmed: true
        )
        try await database.addEvidence(evidence, submissionID: seeded.submissionID)
        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        var setup = try XCTUnwrap(setupSaved)
        setup.curriculumMappings = [CurriculumMapping(assignmentID: seeded.assignmentID, curriculumItemID: "acara-item-1", mappingKind: "assignment")]
        try await database.saveSetup(setup)
        let savedSetupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let savedSetup = try XCTUnwrap(savedSetupSaved)
        let currentSaved = try await database.submission(id: seeded.submissionID)
        let current = try XCTUnwrap(currentSaved)
        try await database.saveFinalReview(
            FinalGradeReview(
                packetFingerprint: try current.packetFingerprint(setup: savedSetup),
                status: .approved,
                criteria: [FinalCriterionScore(
                    criterionID: savedSetup.parsedRubric.criteria[0].id, rating: "", proposedPoints: 4, finalPoints: 4,
                    explanation: "", teacherApproved: true, evidenceIDs: [evidence.id]
                )],
                studentFeedback: "Good.",
                privateTeacherNotes: "",
                teacherEdited: true
            ),
            submissionID: seeded.submissionID
        )

        let loadedSaved = try await database.submission(id: seeded.submissionID)
        let loaded = try XCTUnwrap(loadedSaved)
        let loadedSetupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let loadedSetup = try XCTUnwrap(loadedSetupSaved)
        XCTAssertEqual(loaded.sources.count, 1)
        XCTAssertEqual(loaded.ocr?.pages[0].lines[0].rawText, "Line")
        XCTAssertEqual(loaded.evidence.count, 1)
        XCTAssertEqual(loaded.finalReview?.criteria.count, 1)
        XCTAssertEqual(loaded.finalReview?.criteria[0].evidenceIDs, [evidence.id])
        XCTAssertEqual(loadedSetup.curriculumMappings.count, 1)
        let summarySaved = try await database.submissionSummaries(assignmentID: seeded.assignmentID).first
        let summary = try XCTUnwrap(summarySaved)
        XCTAssertEqual(summary.rosterStatus, .approved)
        let classes = try await database.classGroups()
        let students = try await database.students(inClass: seeded.classGroupID)
        XCTAssertEqual(classes.first?.name, "6A")
        XCTAssertEqual(students.first?.displayName, "Kai")
    }

    func testStudentPDFExportBlockedBeforeApprovedFinalReviewAndTeacherExportRecordIsSensitive() async throws {
        let app = try TestApp.make()
        let seeded = try await TestApp.seed(app, rubric: "Claim: 0-4 points", studentWork: "The quote supports my claim.")
        let database = try app.requireDatabase()
        let setupSaved = try await database.assignmentSetup(id: seeded.assignmentID)
        let setup = try XCTUnwrap(setupSaved)
        try await database.saveFinalReview(
            FinalGradeReview(
                packetFingerprint: try await TestApp.fingerprint(app, seeded),
                status: .inProgress,
                criteria: [FinalCriterionScore(
                    criterionID: setup.parsedRubric.criteria[0].id, rating: "Proficient", proposedPoints: 1, finalPoints: 1,
                    explanation: "The response supports a claim.", teacherApproved: true
                )],
                studentFeedback: "Teacher-approved feedback.",
                privateTeacherNotes: "Private teacher notes.",
                teacherEdited: true
            ),
            submissionID: seeded.submissionID
        )
        let session = try await openSession(app, seeded.submissionID)

        await session.prepareExport(.studentPDF)
        XCTAssertNil(session.preparedExport)
        XCTAssertNotNil(session.alert)

        session.alert = nil
        await session.prepareExport(.teacherAuditPDF)
        XCTAssertNil(session.alert)
        XCTAssertEqual(session.preparedExport?.kind, .teacherAuditPDF)
        let graphSaved = try await database.submission(id: seeded.submissionID)
        let graph = try XCTUnwrap(graphSaved)
        XCTAssertEqual(graph.exports.last?.kind, .teacherAuditPDF)
        XCTAssertTrue(graph.exports.last?.includesPrivateTeacherNotes ?? false)
    }

    // MARK: - Helpers

    private func load(_ database: AppDatabase, _ id: UUID) async throws -> SubmissionGraph {
        guard let graph = try await database.submission(id: id) else { throw AppDatabaseError.notFound(id) }
        return graph
    }

    private func writeSource(root: URL, submissionID: UUID, bytes: String) throws -> (relativePath: String, url: URL) {
        let relativePath = "Sources/\(submissionID.uuidString)/page-1.png"
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(bytes.utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (relativePath, url)
    }

    private func approvedGraph(setup: AssignmentSetup, student: String, score: Double) throws -> SubmissionGraph {
        var graph = SubmissionGraph(
            submission: Submission(assignmentID: setup.id, studentID: UUID(), inputKind: .pasted, pastedText: "The quote supports my claim."),
            student: Student(displayName: student)
        )
        graph.finalReview = FinalGradeReview(
            packetFingerprint: try graph.packetFingerprint(setup: setup),
            status: .approved,
            criteria: [FinalCriterionScore(
                criterionID: setup.parsedRubric.criteria[0].id, rating: "Proficient", proposedPoints: score, finalPoints: score,
                explanation: "The response supports a claim.", teacherApproved: true
            )],
            studentFeedback: "Teacher-approved feedback.",
            privateTeacherNotes: "Private teacher notes.",
            teacherEdited: true
        )
        return graph
    }
}
