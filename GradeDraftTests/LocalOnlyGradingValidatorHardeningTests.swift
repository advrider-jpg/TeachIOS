import XCTest
import ZIPFoundation
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

private enum V3ArchiveTestError: Error {
    case missingEntry(String)
}

private final class V3TempAssignmentStore: AssignmentStoring {
    private(set) var assignments: [AssignmentRecord]
    private(set) var rosterEntries: [AssignmentRosterEntry] = []
    private let root: URL

    init(assignments: [AssignmentRecord] = [], root: URL) {
        self.assignments = assignments
        self.root = root
    }

    func loadAssignments() throws -> [AssignmentRecord] { assignments }
    func saveAssignments(_ assignments: [AssignmentRecord]) throws { self.assignments = assignments }
    func deleteAssignment(id: UUID) throws { assignments.removeAll { $0.id == id } }
    func applicationSupportDirectory() throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    func loadClassGroups() throws -> [ClassGroupRecord] { [] }
    func saveClassGroup(_ classGroup: ClassGroupRecord) throws {}
    func deleteClassGroup(id: UUID) throws {}
    func loadStudents() throws -> [StudentRecord] { [] }
    func saveStudent(_ student: StudentRecord) throws {}
    func deleteStudent(id: UUID) throws {}
    func loadAssignmentRoster(assignmentID: UUID) throws -> [AssignmentRosterEntry] { rosterEntries.filter { $0.assignmentID == assignmentID } }
    func loadAssignmentRosterSnapshot() throws -> [AssignmentRosterEntry] { rosterEntries }
    func replaceAssignmentRosterSnapshot(_ entries: [AssignmentRosterEntry]) throws { self.rosterEntries = entries }
    func replaceLocalDataSnapshot(_ snapshot: AssignmentStoreSnapshot) throws {
        self.assignments = snapshot.assignments
        self.rosterEntries = snapshot.rosterEntries
    }
    func saveSourceInputs(_ sourceInputs: [SourceInputRef], assignmentID: UUID) throws {}
    func saveOCRDocument(_ document: OCRDocument, assignmentID: UUID) throws {}
    func saveFinalReview(_ review: FinalGradeReview, assignmentID: UUID) throws {}
    func saveEvidenceReferences(_ references: [EvidenceReference], assignmentID: UUID) throws {}
    func loadFullAssignmentGraph(id: UUID) throws -> AssignmentRecord? { assignments.first { $0.id == id } }
}

final class AllFeaturesCompletionV3Tests: XCTestCase {
    func testMarkdownRubricParserSupportsHeadingsListsTablesLevelsDuplicatesAndPreview() {
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

    func testCurriculumCatalogLoadsFiltersMapsPersistsAndAvoidsEndorsementClaims() throws {
        let catalog = CurriculumCatalogService.localCatalog
        XCTAssertFalse(catalog.items.isEmpty)
        let englishYear7 = catalog.filtered(learningArea: "English", yearLevel: "Year 7")
        XCTAssertFalse(englishYear7.isEmpty)
        XCTAssertFalse(CurriculumCatalogService.sourceWarning.localizedCaseInsensitiveContains("endorsed by"))
        XCTAssertFalse(CurriculumCatalogService.sourceWarning.localizedCaseInsensitiveContains("certified by"))

        var assignment = approvedAssignment(title: "Curriculum map")
        let item = try XCTUnwrap(englishYear7.first)
        assignment.curriculumMappings = [CurriculumMapping(curriculumItemID: item.id, mappingKind: "assignment")]
        assignment.curriculumReference = CurriculumCatalogService.selectedReferenceSummary(items: [item])
        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains(item.code))
        XCTAssertTrue(audit.contains("Curriculum references"))
        XCTAssertTrue(assignment.gradingPacketFingerprint.contains("fnv1a64-"))
        XCTAssertTrue(PromptBuilder.gradingPrompt(input: assignment.gradingInput).contains(item.code))
    }

    func testRosterCSVPreviewDuplicateDetectionRejectedRowsAndGradebookCSV() {
        let csv = """
        displayName,localIdentifier,className,notes
        Alice,A1,6A,
        Bob,A2,6A,
        Alice,A3,6A,duplicate name allowed with warning
        ,A4,6A,missing name
        Chris,A2,6A,duplicate identifier rejected
        """
        let preview = RosterImportService.preview(csvText: csv, defaultClassName: "6A")
        XCTAssertEqual(preview.students.count, 3)
        XCTAssertTrue(preview.duplicateNames.contains("alice"))
        XCTAssertEqual(preview.rejectedRowDetails.count, 2)
        XCTAssertTrue(preview.hasHeaderRow)

        var alice = approvedAssignment(title: "Essay", student: "Alice", score: 4)
        alice.className = "6A"
        var bob = approvedAssignment(title: "Essay", student: "Bob", score: 3)
        bob.className = "6A"
        let csvOutput = CSVExportService.exportedCSV(from: [alice, bob])
        XCTAssertTrue(csvOutput.contains("Alice"))
        XCTAssertTrue(csvOutput.contains("Bob"))
        XCTAssertTrue(csvOutput.contains("approved"))
    }

    @MainActor
    func testOCRLineEvidenceLinkingBoundingBoxRemovalAndStudentPrivacy() throws {
        let sourceID = UUID()
        var assignment = approvedAssignment(title: "Evidence", student: "Student")
        let line = OCRLine(
            text: "The quote supports my claim.",
            confidence: 0.99,
            boundingBox: NormalizedRect(x: 0.12, y: 0.22, width: 0.45, height: 0.08),
            teacherConfirmed: true
        )
        let page = OCRPage(sourceInputID: sourceID, pageIndex: 1, lines: [line])
        assignment.sourceInputs = [SourceInputRef(id: sourceID, sourceType: .pdf, pageIndex: 1, localRelativePath: "Sources/page-2.png")]
        assignment.ocrDocument = OCRDocument(pages: [page], reviewStatus: .reviewed)
        assignment.ocrReviewStatus = .reviewed
        assignment.reviewedStudentText = page.lines.map(\.reviewedText).joined(separator: "\n")
        var evidenceReview = try XCTUnwrap(assignment.finalReview)
        evidenceReview.criteria[0].evidence = []
        evidenceReview.criteria[0].evidenceSourceRefs = []
        let criterionID = evidenceReview.criteria[0].id
        assignment.finalReview = evidenceReview

        let store = V3TempAssignmentStore(assignments: [assignment], root: FileManager.default.temporaryDirectory.appendingPathComponent("V3Evidence-\(UUID())"))
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)
        viewModel.addOCRLineEvidenceToFinalReview(pageID: page.id, lineID: line.id, criterionID: criterionID)

        XCTAssertEqual(viewModel.assignment.evidenceReferences.count, 1)
        XCTAssertEqual(viewModel.assignment.evidenceReferences.first?.ocrLineID, line.id)
        XCTAssertEqual(viewModel.assignment.evidenceReferences.first?.boundingBox?.stableDisplay, "x:0.1200 y:0.2200 w:0.4500 h:0.0800")
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria[0].evidence.count, 1)
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria[0].evidenceSourceRefs?.count, 1)

        let teacherAudit = MarkdownReportBuilder.teacherAuditMarkdown(for: viewModel.assignment)
        XCTAssertTrue(teacherAudit.contains("bbox"))
        XCTAssertTrue(teacherAudit.contains("text line"))
        let studentReport = MarkdownReportBuilder.studentMarkdown(for: viewModel.assignment)
        XCTAssertFalse(studentReport.contains("bbox"))
        XCTAssertFalse(studentReport.contains("source:"))

        viewModel.removeEvidenceFromFinalReview(criterionID: criterionID, evidenceIndex: 0)
        XCTAssertTrue(viewModel.assignment.evidenceReferences.isEmpty)
        XCTAssertTrue(viewModel.assignment.finalReview?.criteria[0].evidence.isEmpty ?? false)
        XCTAssertTrue(viewModel.assignment.finalReview?.criteria[0].evidenceSourceRefs?.isEmpty ?? false)
    }

    @MainActor
    func testManualEvidenceAddAndClearKeepsEvidenceArraysAligned() throws {
        var assignment = approvedAssignment(title: "Manual evidence")
        var manualReview = try XCTUnwrap(assignment.finalReview)
        manualReview.criteria[0].evidence = []
        manualReview.criteria[0].evidenceSourceRefs = []
        let criterionID = manualReview.criteria[0].id
        assignment.finalReview = manualReview
        let store = V3TempAssignmentStore(assignments: [assignment], root: FileManager.default.temporaryDirectory.appendingPathComponent("V3ManualEvidence-\(UUID())"))
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.addManualEvidenceToFinalReview(criterionID: criterionID, quote: "Teacher-entered quote")
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria[0].evidence, ["Teacher-entered quote"])
        XCTAssertEqual(viewModel.assignment.finalReview?.criteria[0].evidenceSourceRefs?.count, 1)
        XCTAssertEqual(viewModel.assignment.evidenceReferences.first?.sourceKind, "manualTeacherEntry")

        viewModel.clearEvidenceFromFinalReview(criterionID: criterionID)
        XCTAssertTrue(viewModel.assignment.finalReview?.criteria[0].evidence.isEmpty ?? false)
        XCTAssertTrue(viewModel.assignment.finalReview?.criteria[0].evidenceSourceRefs?.isEmpty ?? false)
        XCTAssertTrue(viewModel.assignment.evidenceReferences.isEmpty)
    }

    func testFullBackupArchiveIncludesAllRecordTypesManifestSafePathsAndRestoresSources() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("V3BackupSource-\(UUID())")
        let sourceFolder = tempRoot.appendingPathComponent("Sources/assignment-1", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceFolder, withIntermediateDirectories: true)
        let sourceFile = sourceFolder.appendingPathComponent("page-1.png")
        try Data("source bytes".utf8).write(to: sourceFile)

        var assignment = approvedAssignment(title: "Backup", student: "Alice")
        assignment.sourceInputs = [SourceInputRef(sourceType: .pdf, pageIndex: 0, localRelativePath: "Sources/assignment-1/page-1.png", fileName: "work.pdf", mimeType: "application/pdf", contentDigest: "digest", digestAlgorithm: "fnv1a64", pdfPageCount: 1, teacherIncludedInExport: true)]
        assignment.evidenceReferences = [EvidenceReference(sourceInputID: assignment.sourceInputs[0].id, ocrLineID: UUID(), pageIndex: 0, quote: "Evidence", boundingBox: NormalizedRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2), sourceKind: "ocrLine", teacherConfirmed: true)]
        assignment.exportRecords = [ExportRecord(exportKind: .teacherAuditPDF, contentFingerprint: "fp", includesPrivateTeacherNotes: true, includesOriginalSources: true)]
        assignment.auditEvents = [AuditEvent(eventType: .exportPrepared, detail: "Prepared export.")]
        assignment.curriculumMappings = [CurriculumMapping(curriculumItemID: CurriculumCatalogService.localCatalog.items[0].id, mappingKind: "assignment")]
        assignment.ocrDocument = OCRDocument(pages: [OCRPage(sourceInputID: assignment.sourceInputs[0].id, pageIndex: 0, lines: [OCRLine(text: "Evidence", confidence: 1, boundingBox: .zero, teacherConfirmed: true)])], reviewStatus: .reviewed)

        let classGroup = ClassGroupRecord(name: "6A", schoolYear: "2026", term: "Term 1", subject: "English", gradeLevel: "Year 6")
        let student = StudentRecord(displayName: "Alice", className: "6A", localIdentifier: "A1")
        let rosterEntry = AssignmentRosterEntry(assignmentID: assignment.id, studentID: student.id, studentDisplayName: student.displayName, localIdentifier: student.localIdentifier, status: .approved, sortOrder: 0)
        let zipURL = tempRoot.appendingPathComponent("backup.zip")
        let written = try BundleExportService.writeFullBackup(assignments: [assignment], sourceFiles: [sourceFile], to: zipURL, classGroups: [classGroup], students: [student], rosterEntries: [rosterEntry])
        let archive = try openArchive(written)
        let expectedEntries = ["manifest.json", "schema_version.json", "database_export.json", "assignments.json", "class_groups.json", "students.json", "assignment_roster_entries.json", "source_inputs.json", "evidence_refs.json", "audit_events.json", "export_records.json", "curriculum_mappings.json", "ocr_documents.json", "archive_inventory.json"]
        for path in expectedEntries { XCTAssertNotNil(archive[path], "Missing archive entry: \(path)") }
        XCTAssertTrue(archive.contains { $0.path == "sources/Sources/assignment-1/page-1.png" })
        XCTAssertFalse(archive.contains { $0.path.contains("..") })

        let manifestData = try archiveData("manifest.json", in: archive)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupArchiveManifest.self, from: manifestData)
        XCTAssertEqual(manifest.archiveKind, GradeDraftArchiveKind.fullLocalBackup.rawValue)
        XCTAssertEqual(manifest.recordCounts["assignments"], 1)
        XCTAssertEqual(manifest.recordCounts["students"], 1)
        XCTAssertTrue(manifest.includesOriginalSources)

        let restoreRoot = FileManager.default.temporaryDirectory.appendingPathComponent("V3BackupRestore-\(UUID())")
        let preview = try BundleExportService.previewRestore(from: written, existingAssignments: [assignment])
        XCTAssertEqual(preview.conflictAssignmentIDs, [assignment.id])
        let restoredAsCopy = try BundleExportService.restoreBackupArchive(from: written, existingAssignments: [assignment], applicationSupportDirectory: restoreRoot, conflictResolution: .restoreAsCopy)
        XCTAssertEqual(restoredAsCopy.count, 1)
        XCTAssertNotEqual(restoredAsCopy[0].id, assignment.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoreRoot.appendingPathComponent("Sources/assignment-1/page-1.png").path))
    }

    func testRestoreAsCopyRemapsConflictingAssignmentSourcePaths() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("V3BackupCopySource-\(UUID())")
        let restoreRoot = FileManager.default.temporaryDirectory.appendingPathComponent("V3BackupCopyRestore-\(UUID())")

        var assignment = approvedAssignment(title: "Backup", student: "Alice")
        let originalRelativePath = "Sources/\(assignment.id.uuidString)/page-1.png"
        let sourceFile = tempRoot.appendingPathComponent(originalRelativePath)
        try FileManager.default.createDirectory(at: sourceFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("source bytes".utf8).write(to: sourceFile)
        let localConflictFile = restoreRoot.appendingPathComponent(originalRelativePath)
        try FileManager.default.createDirectory(at: localConflictFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("local-only bytes".utf8).write(to: localConflictFile)
        assignment.sourceInputs = [
            SourceInputRef(
                sourceType: .pdf,
                pageIndex: 0,
                localRelativePath: originalRelativePath,
                fileName: "work.pdf",
                mimeType: "application/pdf",
                contentDigest: "digest",
                digestAlgorithm: "fnv1a64",
                pdfPageCount: 1,
                teacherIncludedInExport: true
            )
        ]

        let zipURL = tempRoot.appendingPathComponent("backup.zip")
        let written = try BundleExportService.writeFullBackup(assignments: [assignment], sourceFiles: [sourceFile], to: zipURL)

        let restoredAsCopy = try BundleExportService.restoreBackupArchive(
            from: written,
            existingAssignments: [assignment],
            applicationSupportDirectory: restoreRoot,
            conflictResolution: .restoreAsCopy
        )

        let copiedAssignment = try XCTUnwrap(restoredAsCopy.first)
        let copiedRelativePath = try XCTUnwrap(copiedAssignment.sourceInputs.first?.localRelativePath)
        XCTAssertNotEqual(copiedAssignment.id, assignment.id)
        XCTAssertEqual(copiedRelativePath, "Sources/\(copiedAssignment.id.uuidString)/page-1.png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoreRoot.appendingPathComponent(copiedRelativePath).path))
        let copiedText = try XCTUnwrap(String(data: try Data(contentsOf: restoreRoot.appendingPathComponent(copiedRelativePath)), encoding: .utf8))
        XCTAssertEqual(copiedText, "source bytes")
        XCTAssertTrue(FileManager.default.fileExists(atPath: restoreRoot.appendingPathComponent(originalRelativePath).path))
        let localConflictText = try XCTUnwrap(String(data: try Data(contentsOf: localConflictFile), encoding: .utf8))
        XCTAssertEqual(localConflictText, "local-only bytes")
    }

    @MainActor
    func testBackupRestoreUIPathDetectsConflictAndRestoresAsCopy() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent("V3ViewModelRestore-\(UUID())")
        let local = approvedAssignment(title: "Local", student: "Alice")
        var backup = local
        backup.title = "Backup version"
        let zipURL = tempRoot.appendingPathComponent("backup.zip")
        try BundleExportService.writeFullBackup(assignments: [backup], sourceFiles: [], to: zipURL)
        let store = V3TempAssignmentStore(assignments: [local], root: tempRoot.appendingPathComponent("AppSupport"))
        let viewModel = GradeDraftViewModel(assignments: [local], store: store)
        viewModel.backupConflictResolution = .restoreAsCopy

        viewModel.restoreBackup(from: zipURL)

        XCTAssertEqual(viewModel.latestRestorePreview?.conflictAssignmentIDs, [local.id])
        XCTAssertEqual(viewModel.assignments.count, 2)
        XCTAssertTrue(viewModel.assignments.contains { $0.title == "Local" })
        XCTAssertTrue(viewModel.assignments.contains { $0.title.contains("Restored copy") })
    }

    func testNormalizedDatabaseLoadsFromNormalizedTablesAfterCompatibilityPayloadsAreRemoved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("V3NormalizedDB-\(UUID())")
        let database = try GradeDraftDatabase(applicationSupportURL: root)
        try database.bootstrapIfNeeded()

        let classGroup = ClassGroupRecord(name: "6A", schoolYear: "2026", term: "Term 1", subject: "English", gradeLevel: "Year 6")
        let student = StudentRecord(displayName: "Alice", className: "6A", localIdentifier: "A1")
        var assignment = approvedAssignment(title: "Normalized", student: student.displayName)
        assignment.classGroupID = classGroup.id
        assignment.studentID = student.id
        assignment.sourceInputs = [SourceInputRef(sourceType: .pdf, pageIndex: 0, localRelativePath: "Sources/normalized/page.png", pdfPageCount: 1)]
        assignment.ocrDocument = OCRDocument(pages: [OCRPage(sourceInputID: assignment.sourceInputs[0].id, pageIndex: 0, lines: [OCRLine(text: "Line", confidence: 1, boundingBox: .zero, teacherConfirmed: true)])], reviewStatus: .reviewed)
        assignment.evidenceReferences = [EvidenceReference(sourceInputID: assignment.sourceInputs[0].id, ocrLineID: assignment.ocrDocument?.pages[0].lines[0].id, pageIndex: 0, quote: "Line", boundingBox: .zero, sourceKind: "ocrLine", teacherConfirmed: true)]
        assignment.curriculumMappings = [CurriculumMapping(curriculumItemID: CurriculumCatalogService.localCatalog.items[0].id, mappingKind: "assignment")]
        let rosterEntry = AssignmentRosterEntry(assignmentID: assignment.id, studentID: student.id, studentDisplayName: student.displayName, localIdentifier: student.localIdentifier, status: .approved, sortOrder: 0)

        try database.saveClassGroup(classGroup)
        try database.saveStudent(student)
        try database.saveAssignments([assignment])
        try database.replaceAssignmentRosterSnapshot([rosterEntry])
        try database.removeCompatibilityPayloadsForValidation()

        let loaded = try XCTUnwrap(database.loadFullAssignmentGraph(id: assignment.id))
        XCTAssertEqual(loaded.title, "Normalized")
        XCTAssertEqual(loaded.sourceInputs.count, 1)
        XCTAssertEqual(loaded.ocrDocument?.pages[0].lines[0].rawText, "Line")
        XCTAssertEqual(loaded.evidenceReferences.count, 1)
        XCTAssertEqual(loaded.finalReview?.criteria.count, 1)
        XCTAssertEqual(loaded.curriculumMappings.count, 1)
        XCTAssertEqual(try database.loadAssignmentRoster(assignmentID: assignment.id).first?.status, .approved)
        XCTAssertEqual(try database.loadClassGroups().first?.name, "6A")
        XCTAssertEqual(try database.loadStudents().first?.displayName, "Alice")
    }

    @MainActor
    func testStudentPDFExportBlockedBeforeApprovedFinalReviewAndTeacherExportRecordIsSensitive() throws {
        var assignment = approvedAssignment(title: "Exports")
        var pendingReview = try XCTUnwrap(assignment.finalReview)
        pendingReview.status = .inProgress
        assignment.finalReview = pendingReview
        let store = V3TempAssignmentStore(assignments: [assignment], root: FileManager.default.temporaryDirectory.appendingPathComponent("V3ExportGate-\(UUID())"))
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.exportStudentPDF()
        XCTAssertNil(viewModel.exportURL)
        XCTAssertNotNil(viewModel.errorMessage)

        viewModel.exportTeacherAuditPDF()
        XCTAssertEqual(viewModel.assignment.exportRecords.last?.exportKind, .teacherAuditPDF)
        XCTAssertTrue(viewModel.assignment.exportRecords.last?.includesPrivateTeacherNotes ?? false)
    }

    private func approvedAssignment(title: String, student: String = "Student", score: Double = 1) -> AssignmentRecord {
        var assignment = AssignmentRecord(
            title: title,
            prompt: "Prompt",
            subject: "English",
            gradeLevel: "Year 6",
            curriculumReference: "",
            className: "6A",
            studentDisplayName: student,
            assignmentType: .essay,
            rubricText: "Claim: 0-4 points",
            reviewedStudentText: "The quote supports my claim.",
            ocrReviewStatus: .reviewed
        )
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: score,
                finalPoints: score,
                maxPoints: 4,
                evidence: ["The quote supports my claim."],
                evidenceSourceRefs: [],
                explanation: "The response supports a claim.",
                teacherApproved: true
            )],
            totalScore: score,
            maxScore: 4,
            studentFeedback: "Teacher-approved feedback.",
            privateTeacherNotes: "Private teacher notes.",
            teacherEdited: true
        )
        return assignment
    }

    private func openArchive(_ url: URL) throws -> Archive {
        guard let archive = Archive(url: url, accessMode: .read) else { throw V3ArchiveTestError.missingEntry(url.lastPathComponent) }
        return archive
    }

    private func archiveData(_ path: String, in archive: Archive) throws -> Data {
        guard let entry = archive[path] else { throw V3ArchiveTestError.missingEntry(path) }
        var data = Data()
        _ = try archive.extract(entry) { chunk in data.append(chunk) }
        return data
    }
}
