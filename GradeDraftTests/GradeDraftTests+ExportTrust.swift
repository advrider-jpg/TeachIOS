import XCTest
import ZIPFoundation
@testable import GradeDraft

extension GradeDraftTests {
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

    func testCSVExportBuildRowsUsesFormulaSafeguardsAndOmitsPrivateNotes() throws {
        let draft = GradeDraftResult(
            studentResponseSummary: "Draft summary",
            criteria: [
                CriterionScore(
                    criterionID: "claim",
                    criterion: "Claim",
                    rating: "Proficient",
                    proposedPoints: 3,
                    maxPoints: 4,
                    evidence: ["Student text"],
                    explanation: "Evidence supports claim.",
                    teacherReviewRequired: false
                )
            ],
            totalScore: 3,
            maxScore: 4,
            studentFeedback: "Good effort.",
            teacherNotes: "Private grading note.",
            uncertaintyFlags: []
        )

        var assignment = AssignmentRecord(
            title: "=Exploit prompt",
            subject: "+English",
            gradeLevel: "9",
            studentDisplayName: "-Jane",
            assignmentType: .essay
        )
        assignment.latestDraft = draft
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterionID: "claim",
                criterion: "Claim",
                rating: "Proficient",
                proposedPoints: 3,
                finalPoints: 4,
                maxPoints: 4,
                evidence: ["Student text"],
                explanation: "Strong claim.",
                teacherApproved: true
            )],
            totalScore: 4,
            maxScore: 4,
            studentFeedback: "Good.",
            privateTeacherNotes: "Private instructor comment.",
            teacherEdited: true
        )

        let rows = CSVExportService.buildStudentRows(from: [assignment])
        XCTAssertEqual(rows.count, 2)
        let dataRow = rows[1]
        XCTAssertEqual(dataRow[1], "'=Exploit prompt")
        XCTAssertEqual(dataRow[2], "'+English")
        XCTAssertEqual(dataRow[5], "'-Jane")
        XCTAssertEqual(dataRow.count, 16)
        XCTAssertEqual(dataRow[10], "approved")
        XCTAssertEqual(dataRow[11], "notNeeded")
        XCTAssertEqual(dataRow[12], "teacherReviewRequired")
        XCTAssertEqual(dataRow[13], "false")
        XCTAssertEqual(dataRow[14], "false")

        let csv = CSVExportService.exportedCSV(from: [assignment])
        let parsedRows = try CSVParser.parseRows(csv)
        XCTAssertEqual(parsedRows.first, ["assignment_id", "title", "subject", "grade_level", "class_name", "student", "assignment_type", "assessment_purpose", "total_score", "max_score", "final_status", "ocr_status", "draft_status", "final_review_stale", "draft_stale", "updated_at"])
        XCTAssertTrue(csv.hasPrefix("\"assignment_id\""))
        XCTAssertFalse(csv.contains("Private grading note."))
        XCTAssertFalse(csv.contains("Private instructor comment."))
    }

    @MainActor
    func testTeacherAuditIncludesPrivateNotesAndOCRStatusAndFingerprint() {
        var assignment = AssignmentRecord(title: "Audit test", subject: "Science")
        assignment.reviewedStudentText = "Student text"
        assignment.rubricText = "Claim: 0-4 points"
        assignment.ocrReviewStatus = .reviewed
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 4,
                maxPoints: 4,
                evidence: [],
                explanation: "",
                teacherApproved: true
            )],
            totalScore: 4,
            maxScore: 4,
            studentFeedback: "Great.",
            privateTeacherNotes: "Private audit note here.",
            teacherEdited: true
        )

        let audit = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment)
        XCTAssertTrue(audit.contains("Private audit note here."), "Teacher review should include private notes")
        XCTAssertTrue(audit.contains("Scanned-text review status: Ready for teacher review"), "Teacher review should include scanned-text status")
        XCTAssertTrue(audit.contains(assignment.gradingPacketFingerprint), "Teacher review should include packet fingerprint")
    }

    @MainActor
    func testTeacherArchiveFailsVisiblyWhenReferencedSourceFileIsMissing() {
        var assignment = AssignmentRecord(title: "Missing source")
        assignment.sourceInputs = [
            SourceInputRef(
                sourceType: .scan,
                localRelativePath: "Sources/\(assignment.id.uuidString)/missing.png",
                fileName: "missing.png",
                teacherIncludedInExport: true
            )
        ]
        let store = InMemoryAssignmentStore(assignments: [assignment])
        store.appSupportDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("GradeDraftMissingSource-\(UUID())")
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        viewModel.exportArchiveBundle()

        XCTAssertNil(viewModel.exportURL)
        XCTAssertNil(viewModel.exportKind)
        XCTAssertTrue(viewModel.errorMessage?.contains("missing") == true)
        XCTAssertFalse(viewModel.statusMessage.contains("ready to share"))
    }

    @MainActor
    func testClipboardCopyBlocksBackupArchiveAndPDFArtifactsByDefault() {
        let assignment = AssignmentRecord(title: "Clipboard safety")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let viewModel = GradeDraftViewModel(assignments: [assignment], store: store)

        XCTAssertTrue(viewModel.clipboardTextExportKinds.contains(.studentMarkdown))
        XCTAssertTrue(viewModel.clipboardTextExportKinds.contains(.teacherAuditMarkdown))
        XCTAssertTrue(viewModel.clipboardTextExportKinds.contains(.csvGradebook))

        for blockedKind in [ExportKind.studentPDF, .teacherAuditPDF, .zipArchive, .fullBackupArchive, .backupJSON, .assignmentGradebookArchive] {
            XCTAssertFalse(
                viewModel.clipboardTextExportKinds.contains(blockedKind),
                "\(blockedKind.displayName) must not be copied to the clipboard; create and share the file artifact instead."
            )
        }
    }

    // MARK: - Local AI unavailability tests

    @MainActor
    func testPDFExportServicesWriteNonEmptyFiles() throws {
        var assignment = AssignmentRecord(title: "PDF", reviewedStudentText: "Evidence")
        assignment.finalReview = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .approved,
            criteria: [FinalCriterionScore(
                criterion: "Claim",
                rating: "",
                proposedPoints: 0,
                finalPoints: 1,
                maxPoints: 1,
                evidence: ["Evidence"],
                explanation: "Met.",
                teacherApproved: true
            )],
            totalScore: 1,
            maxScore: 1,
            studentFeedback: "Good.",
            privateTeacherNotes: "Private",
            teacherEdited: true
        )
        let studentURL = FileManager.default.temporaryDirectory.appendingPathComponent("student-\(UUID()).pdf")
        let auditURL = FileManager.default.temporaryDirectory.appendingPathComponent("audit-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: studentURL); try? FileManager.default.removeItem(at: auditURL) }
        let writtenStudent = try PDFExportService.studentReportPDF(for: assignment, destination: studentURL)
        let writtenAudit = try PDFExportService.teacherAuditPDF(for: assignment, destination: auditURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: writtenStudent.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: writtenAudit.path))
        XCTAssertGreaterThan((try Data(contentsOf: writtenStudent)).count, 100)
        XCTAssertGreaterThan((try Data(contentsOf: writtenAudit)).count, 100)
    }

    func testArchiveContainsManifestAndCoreFiles() throws {
        let assignment = AssignmentRecord(title: "Archive", reviewedStudentText: "Text")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("archive-\(UUID()).zip")
        defer { try? FileManager.default.removeItem(at: destination) }
        let written = try BundleExportService.writeTeacherAuditArchive(assignment: assignment, sourceFiles: [], to: destination)
        guard let archive = Archive(url: written, accessMode: .read) else {
            return XCTFail("Archive should open")
        }
        XCTAssertNotNil(archive["manifest.json"])
        XCTAssertNotNil(archive["student_report.md"])
        XCTAssertNotNil(archive["teacher_audit_report.md"])
        XCTAssertNotNil(archive["assignment.json"])
    }

    func testPDFImportPlannerIdentifiesScannedPagesInMixedPDF() {
        let pagesNeedingOCR = PDFImportPlanner.pageIndexesNeedingOCR(digitalTextByPage: [
            "Digital page text",
            "   ",
            "Second digital page"
        ])

        XCTAssertEqual(pagesNeedingOCR, [1])
    }

    func testPDFImportPlannerMergesDigitalAndOCRPages() {
        let refs = (0..<3).map { index in
            SourceInputRef(
                sourceType: .pdf,
                pageIndex: index,
                fileName: "PDF page \(index + 1)",
                imageWidth: 600,
                imageHeight: 800
            )
        }
        let scannedPage = OCRPage(
            sourceInputID: refs[1].id,
            pageIndex: 1,
            imageWidth: 600,
            imageHeight: 800,
            lines: [OCRLine(text: "Scanned page OCR", confidence: 0.83, boundingBox: .zero)]
        )

        let document = PDFImportPlanner.mergedDocument(
            digitalTextByPage: ["Digital page text", "", "More digital text"],
            sourceRefs: refs,
            recognizedOCRPagesByPageIndex: [1: scannedPage],
            pageCount: 3
        )

        XCTAssertEqual(document.engine, "PDFKit digital text + Apple Vision")
        XCTAssertEqual(document.pages.map(\.pageIndex), [0, 1, 2])
        XCTAssertEqual(document.pages[0].lines.first?.rawText, "Digital page text")
        XCTAssertEqual(document.pages[1].lines.first?.rawText, "Scanned page OCR")
        XCTAssertEqual(document.pages[2].lines.first?.rawText, "More digital text")
    }

    func testPDFImportPlannerPreservesEmptyPageWhenOCRReturnsNoLines() {
        let refs = [
            SourceInputRef(sourceType: .pdf, pageIndex: 0, fileName: "PDF page 1", imageWidth: 600, imageHeight: 800)
        ]

        let document = PDFImportPlanner.mergedDocument(
            digitalTextByPage: [""],
            sourceRefs: refs,
            recognizedOCRPagesByPageIndex: [:],
            pageCount: 1
        )

        XCTAssertEqual(document.engine, "PDFKit digital text + Apple Vision")
        XCTAssertEqual(document.pages.count, 1)
        XCTAssertEqual(document.pages[0].sourceInputID, refs[0].id)
        XCTAssertTrue(document.pages[0].lines.isEmpty)
    }

    // MARK: - Change 1: Export authentication gate tests

    @MainActor
    func testTeacherAuditExportBlockedWhenAuthFails() async {
        let alwaysDeny = StubExportAuthenticationService(result: ExportAuthenticationResult(allowed: false, authenticationPerformed: true, message: "Denied"))
        let assignment = AssignmentRecord(title: "Test")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store, exportAuthenticationService: alwaysDeny)
        let allowed = await vm.authenticateForExportIfNeeded(.teacherAuditMarkdown)
        XCTAssertFalse(allowed, "Teacher-only export must be blocked when auth fails")
        XCTAssertNil(vm.exportURL, "exportURL must be nil after auth failure")
    }

    @MainActor
    func testGradebookCSVBlockedWhenAuthFails() async {
        let alwaysDeny = StubExportAuthenticationService(result: ExportAuthenticationResult(allowed: false, authenticationPerformed: true, message: nil))
        let assignment = AssignmentRecord(title: "Test")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store, exportAuthenticationService: alwaysDeny)
        await vm.performConfirmedExport(.gradebookCSV)
        XCTAssertNil(vm.exportURL, "Gradebook CSV must not be created when auth fails")
    }

    @MainActor
    func testGradebookArchiveBlockedWhenAuthFails() async {
        let alwaysDeny = StubExportAuthenticationService(result: ExportAuthenticationResult(allowed: false, authenticationPerformed: true, message: nil))
        let assignment = AssignmentRecord(title: "Test")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store, exportAuthenticationService: alwaysDeny)
        await vm.performConfirmedExport(.gradebookArchive)
        XCTAssertNil(vm.exportURL, "Gradebook Archive must not be created when auth fails")
    }

    @MainActor
    func testAuthUnavailableAllowsExportAndSetsStatusMessage() async {
        let unavailableResult = ExportAuthenticationResult(allowed: true, authenticationPerformed: false, message: "Device authentication is unavailable on this platform.")
        let unavailable = StubExportAuthenticationService(result: unavailableResult)
        let assignment = AssignmentRecord(title: "Test")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store, exportAuthenticationService: unavailable)
        let allowed = await vm.authenticateForExportIfNeeded(.teacherAuditMarkdown)
        XCTAssertTrue(allowed, "Export should proceed when auth is unavailable but policy allows it")
        XCTAssertNotNil(vm.lastExportAuthenticationResult)
        XCTAssertFalse(vm.lastExportAuthenticationResult?.authenticationPerformed ?? true)
    }

    // MARK: - Change 2: Gradebook CSV and Gradebook Archive tests

    @MainActor
    func testGradebookCSVExportsAllAssignments() {
        let a1 = AssignmentRecord(title: "Assign 1", studentDisplayName: "Alice")
        let a2 = AssignmentRecord(title: "Assign 2", studentDisplayName: "Bob")
        let store = InMemoryAssignmentStore(assignments: [a1, a2])
        let vm = GradeDraftViewModel(assignments: [a1, a2], store: store)
        vm.exportCSVGradebook()
        // The CSV file should reference both students
        if let url = vm.exportURL, let content = try? String(contentsOf: url, encoding: .utf8) {
            XCTAssertTrue(content.contains("Alice") || content.contains("Assign 1"), "CSV must include first assignment")
            XCTAssertTrue(content.contains("Bob") || content.contains("Assign 2"), "CSV must include second assignment")
        } else {
            XCTFail("exportURL not set after exportCSVGradebook")
        }
        XCTAssertEqual(vm.exportKind, .csvGradebook)
    }

    @MainActor
    func testGradebookArchiveWritesZIP() throws {
        let assignment = AssignmentRecord(title: "Archive Test")
        let store = InMemoryAssignmentStore(assignments: [assignment])
        let vm = GradeDraftViewModel(assignments: [assignment], store: store)
        vm.exportGradebookArchive()
        guard let url = vm.exportURL else {
            XCTFail("exportURL not set after exportGradebookArchive")
            return
        }
        XCTAssertEqual(url.pathExtension, "zip", "Gradebook archive must be a ZIP file")
        XCTAssertEqual(vm.exportKind, .assignmentGradebookArchive)
    }

    // MARK: - Change 3: Two-phase backup restore tests

}
