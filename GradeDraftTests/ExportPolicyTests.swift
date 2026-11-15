import XCTest
@testable import GradeDraft

final class ExportPolicyTests: XCTestCase {
    func testEveryExportKindHasExplicitPolicy() {
        let kinds: [ExportKind] = [.studentMarkdown, .teacherAuditMarkdown, .studentPDF, .teacherAuditPDF, .csvGradebook, .zipArchive, .fullBackupArchive]
        XCTAssertEqual(kinds.map { $0.contentPolicy.kind }, kinds)
        XCTAssertTrue(kinds.allSatisfy { !$0.contentPolicy.warningTitle.isEmpty && !$0.contentPolicy.warningBody.isEmpty })
    }

    func testStudentMarkdownPolicyIsStudentFacingAndRequiresApprovedFinal() {
        let policy = ExportKind.studentMarkdown.contentPolicy
        XCTAssertTrue(policy.isStudentFacing)
        XCTAssertFalse(policy.isTeacherOnly)
        XCTAssertTrue(policy.requiresApprovedFinalReview)
    }

    func testStudentPDFPolicyMatchesStudentMarkdownSensitivity() {
        let md = ExportKind.studentMarkdown.contentPolicy
        let pdf = ExportKind.studentPDF.contentPolicy
        XCTAssertEqual(pdf.isStudentFacing, md.isStudentFacing)
        XCTAssertEqual(pdf.includesPrivateTeacherNotes, md.includesPrivateTeacherNotes)
        XCTAssertEqual(pdf.includesDraftGrades, md.includesDraftGrades)
        XCTAssertEqual(pdf.requiresApprovedFinalReview, md.requiresApprovedFinalReview)
    }

    func testTeacherAuditMarkdownPolicyIsTeacherOnlySensitive() {
        let policy = ExportKind.teacherAuditMarkdown.contentPolicy
        XCTAssertTrue(policy.isTeacherOnly)
        XCTAssertTrue(policy.includesPrivateTeacherNotes)
        XCTAssertTrue(policy.includesAuditEvents)
        XCTAssertTrue(policy.includesInternalMetadata)
    }

    func testTeacherAuditPDFPolicyMatchesTeacherAuditMarkdownSensitivity() {
        let markdown = ExportKind.teacherAuditMarkdown.contentPolicy
        let pdf = ExportKind.teacherAuditPDF.contentPolicy
        XCTAssertEqual(pdf.isTeacherOnly, markdown.isTeacherOnly)
        XCTAssertEqual(pdf.includesPrivateTeacherNotes, markdown.includesPrivateTeacherNotes)
        XCTAssertEqual(pdf.includesOCRText, markdown.includesOCRText)
        XCTAssertEqual(pdf.includesAuditEvents, markdown.includesAuditEvents)
    }

    func testCSVPolicyDoesNotIncludePrivateNotesOrReviewedText() {
        let policy = ExportKind.csvGradebook.contentPolicy
        XCTAssertFalse(policy.includesPrivateTeacherNotes)
        XCTAssertFalse(policy.includesReviewedText)
        XCTAssertFalse(policy.includesOCRText)
        XCTAssertFalse(policy.includesSourceFiles)
    }

    func testZipArchivePolicyIncludesPrivateNotesSourcesAndAuditMetadata() {
        let policy = ExportKind.zipArchive.contentPolicy
        XCTAssertTrue(policy.includesPrivateTeacherNotes)
        XCTAssertTrue(policy.includesSourceFiles)
        XCTAssertTrue(policy.includesAuditEvents)
        XCTAssertTrue(policy.includesInternalMetadata)
    }

    func testFullBackupPolicyIncludesPrivateNotesSourcesAndAuditMetadata() {
        let policy = ExportKind.fullBackupArchive.contentPolicy
        XCTAssertTrue(policy.includesPrivateTeacherNotes)
        XCTAssertTrue(policy.includesSourceFiles)
        XCTAssertTrue(policy.includesAuditEvents)
        XCTAssertTrue(policy.includesInternalMetadata)
    }

    func testStudentFacingPoliciesNeverIncludePrivateNotes() {
        let policies = [ExportKind.studentMarkdown.contentPolicy, ExportKind.studentPDF.contentPolicy]
        XCTAssertTrue(policies.allSatisfy { !$0.includesPrivateTeacherNotes })
    }

    func testStudentFacingPoliciesNeverIncludeDraftGrades() {
        let policies = [ExportKind.studentMarkdown.contentPolicy, ExportKind.studentPDF.contentPolicy]
        XCTAssertTrue(policies.allSatisfy { !$0.includesDraftGrades })
    }

    func testStudentFacingPoliciesNeverIncludeOCRText() {
        let policies = [ExportKind.studentMarkdown.contentPolicy, ExportKind.studentPDF.contentPolicy]
        XCTAssertTrue(policies.allSatisfy { !$0.includesOCRText })
    }

    func testStudentFacingPoliciesNeverIncludeAuditEvents() {
        let policies = [ExportKind.studentMarkdown.contentPolicy, ExportKind.studentPDF.contentPolicy]
        XCTAssertTrue(policies.allSatisfy { !$0.includesAuditEvents })
    }

    func testTeacherOnlyPoliciesRequireShareWarning() {
        let policies = [
            ExportKind.teacherAuditMarkdown.contentPolicy,
            ExportKind.teacherAuditPDF.contentPolicy,
            ExportKind.csvGradebook.contentPolicy,
            ExportKind.zipArchive.contentPolicy,
            ExportKind.fullBackupArchive.contentPolicy
        ]
        XCTAssertTrue(policies.allSatisfy(\.isTeacherOnly))
        XCTAssertTrue(policies.allSatisfy(\.requiresShareWarning))
    }

    func testSensitivePoliciesRequireLocalAuthenticationWhenAvailableExceptStudentReports() {
        XCTAssertFalse(ExportKind.studentMarkdown.contentPolicy.requiresLocalAuthenticationWhenAvailable)
        XCTAssertFalse(ExportKind.studentPDF.contentPolicy.requiresLocalAuthenticationWhenAvailable)
        XCTAssertTrue(ExportKind.teacherAuditPDF.contentPolicy.requiresLocalAuthenticationWhenAvailable)
        XCTAssertTrue(ExportKind.csvGradebook.contentPolicy.requiresLocalAuthenticationWhenAvailable)
        XCTAssertTrue(ExportKind.zipArchive.contentPolicy.requiresLocalAuthenticationWhenAvailable)
        XCTAssertTrue(ExportKind.fullBackupArchive.contentPolicy.requiresLocalAuthenticationWhenAvailable)
    }

    func testInclusionSummaryMentionsPrivateNotesWhenIncluded() {
        XCTAssertTrue(ExportKind.teacherAuditPDF.contentPolicy.inclusionSummaryLines.contains { $0.localizedCaseInsensitiveContains("private teacher notes") })
    }

    func testInclusionSummaryMentionsSourceFilesWhenIncluded() {
        XCTAssertTrue(ExportKind.zipArchive.contentPolicy.inclusionSummaryLines.contains { $0.localizedCaseInsensitiveContains("source files") })
    }

    func testCSVWarningMentionsFormulaInjection() {
        let policy = ExportKind.csvGradebook.contentPolicy
        XCTAssertTrue(policy.warningBody.localizedCaseInsensitiveContains("formula"))
        XCTAssertTrue(policy.inclusionSummaryLines.contains { $0.localizedCaseInsensitiveContains("formula") })
    }

    func testGradebookCSVDisplayName() {
        XCTAssertEqual(ExportKind.csvGradebook.displayName, "Gradebook CSV")
    }

    func testGradebookCSVSafeFilenameToken() {
        XCTAssertEqual(ExportKind.csvGradebook.safeFilenameToken, "GradebookCSV")
    }

    func testSensitivePoliciesRequireLocalAuthenticationIncludingGradebookCSV() {
        XCTAssertTrue(ExportKind.csvGradebook.contentPolicy.requiresLocalAuthenticationWhenAvailable)
        XCTAssertTrue(ExportKind.teacherAuditMarkdown.contentPolicy.requiresLocalAuthenticationWhenAvailable)
        XCTAssertTrue(ExportKind.fullBackupArchive.contentPolicy.requiresLocalAuthenticationWhenAvailable)
        XCTAssertFalse(ExportKind.studentMarkdown.contentPolicy.requiresLocalAuthenticationWhenAvailable)
        XCTAssertFalse(ExportKind.studentPDF.contentPolicy.requiresLocalAuthenticationWhenAvailable)
    }

    func testExportRiskSummaryDoesNotInventDraftContentForBlankAssignment() throws {
        let fixture = try ExportFixtureFactory.baseAssignment(title: "Blank local record")

        let summary = ExportRiskSummary.summary(
            for: .teacherAuditMarkdown,
            items: [(setup: fixture.setup, submission: fixture.submission)]
        )

        XCTAssertFalse(summary.includesDraftContent)
        XCTAssertTrue(summary.includesPrivateNotes)
        XCTAssertFalse(summary.includesOriginalSources)
        XCTAssertEqual(summary.affectedAssignmentCount, 1)
    }

    func testExportRiskSummaryFlagsActualDraftAndUnapprovedFinalContent() throws {
        let draft = try ExportFixtureFactory.draftOnlyAssignment()
        let finalInProgress = try ExportFixtureFactory.inProgressFinalReviewAssignment()

        XCTAssertTrue(ExportRiskSummary.summary(
            for: .teacherAuditPDF,
            items: [(setup: draft.setup, submission: draft.submission)]
        ).includesDraftContent)
        XCTAssertTrue(ExportRiskSummary.summary(
            for: .csvGradebook,
            items: [(setup: finalInProgress.setup, submission: finalInProgress.submission)]
        ).includesDraftContent)
    }

    func testExportRiskSummaryUsesInjectedSourceAvailability() throws {
        let fixture = try ExportFixtureFactory.baseAssignment(title: "Archived")
        let items = [(setup: fixture.setup, submission: fixture.submission)]

        let noSource = ExportRiskSummary.summary(for: .zipArchive, items: items, sourceAvailability: { _ in false })
        let hasSource = ExportRiskSummary.summary(for: .zipArchive, items: items, sourceAvailability: { _ in true })

        XCTAssertFalse(noSource.includesOriginalSources)
        XCTAssertTrue(hasSource.includesOriginalSources)
    }
}
