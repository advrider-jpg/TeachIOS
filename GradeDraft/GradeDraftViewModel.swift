import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
final class GradeDraftViewModel: ObservableObject {
    @Published var assignments: [AssignmentRecord] = []
    @Published var selectedAssignmentID: UUID?
    @Published var isWorking = false
    @Published var statusMessage = "Student work stays on this device."
    @Published var errorMessage: String?
    @Published var exportURL: URL?
    @Published var exportKind: ExportKind?
    @Published var preparedExportArtifact: PreparedExportArtifact?
    @Published var lastExportAuthenticationResult: ExportAuthenticationResult?
    @Published var classGroups: [ClassGroupRecord] = []
    @Published var students: [StudentRecord] = []
    @Published var assignmentRosterEntries: [AssignmentRosterEntry] = []
    @Published var latestRosterPreview: RosterImportPreview?
    @Published var latestRubricPreview: RubricImportPreview?
    @Published var rubricPreviewsByAssignmentID: [UUID: RubricImportPreview] = [:]
    @Published var latestRestorePreview: BackupRestorePreview?
    @Published var pendingRestorePreview: BackupRestorePreview?
    @Published var pendingRestoreFileURL: URL?
    @Published var backupConflictResolution: BackupConflictResolution = .restoreAsCopy
    @Published var curriculumCatalog: CurriculumCatalog = CurriculumCatalogService.localCatalog
    @Published var curriculumSearchText = ""
    @Published var curriculumCatalogKindFilter = ""
    @Published var curriculumSubjectFilter = ""
    @Published var curriculumLearningAreaFilter = ""
    @Published var curriculumYearLevelFilter = ""
    @Published var curriculumResultLimit = 50
    @Published var aiReadinessReport: AIReadinessReport?
    @Published var aiPacketPreview: AIPacketPreview?
    @Published var aiGenerationProgress: AIGenerationProgress = .idle
    @Published var deviceBackupPolicyStatus: DeviceBackupPolicyStatus = .unknown("Backup exclusion has not been checked yet.")

    let ocrService: OCRServicing
    let gradingService: GradingServicing & CapabilityChecking
    let store: AssignmentStoring
    let fileManager: FileManager
    let exportAuthenticationService: ExportAuthenticationServicing
    var draftGenerationTask: Task<Void, Never>?
    var pendingRestoreFingerprint: String?
    @Published var persistenceMode: String

    init(
        assignments: [AssignmentRecord] = [],
        ocrService: OCRServicing = VisionOCRService(),
        gradingService: GradingServicing & CapabilityChecking = FoundationModelGradingService(),
        store: AssignmentStoring? = nil,
        fileManager: FileManager = .default,
        exportAuthenticationService: ExportAuthenticationServicing = LocalExportAuthenticationService()
    ) {
        self.ocrService = ocrService
        self.gradingService = gradingService
        self.exportAuthenticationService = exportAuthenticationService
        let resolvedStore: AssignmentStoring
        let resolvedMode: String
        if let store {
            resolvedStore = store
            resolvedMode = "Injected store"
        } else if let dbStore = try? GRDBAssignmentStore(fileManager: fileManager) {
            resolvedStore = dbStore
            resolvedMode = "GRDB-backed local storage"
        } else {
            resolvedStore = LocalJSONStore(fileManager: fileManager)
            resolvedMode = "JSON file-backed storage (GRDB unavailable)"
        }

        self.store = resolvedStore
        self.persistenceMode = resolvedMode
        self.fileManager = fileManager

        if assignments.isEmpty {
            do {
                let loaded = try resolvedStore.loadAssignments()
                self.assignments = loaded.isEmpty ? [AssignmentRecord()] : loaded
                self.classGroups = try resolvedStore.loadClassGroups()
                self.students = try resolvedStore.loadStudents()
                self.assignmentRosterEntries = try resolvedStore.loadAssignmentRosterSnapshot()
            } catch {
                self.assignments = [AssignmentRecord()]
                self.errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
            }
        } else {
            self.assignments = assignments
            self.classGroups = Self.classGroupsFromAssignments(assignments)
            self.students = Self.studentsFromAssignments(assignments)
        }

        if self.classGroups.isEmpty { self.classGroups = Self.classGroupsFromAssignments(self.assignments) }
        if self.students.isEmpty { self.students = Self.studentsFromAssignments(self.assignments) }
        if self.assignmentRosterEntries.isEmpty {
            refreshAssignmentRosterEntries()
        } else {
            reconcileRosterEntriesWithCurrentAssignments()
        }
        selectedAssignmentID = self.assignments.first?.id
        refreshDeviceBackupPolicyStatus()
        refreshCapabilityStatus()
    }

    var assignment: AssignmentRecord {
        get {
            guard let selectedAssignmentID,
                  let assignment = assignments.first(where: { $0.id == selectedAssignmentID }) else {
                return assignments.first ?? AssignmentRecord()
            }
            return assignment
        }
        set {
            upsertAssignment(newValue)
        }
    }

    var localAIStatus: LocalAIStatus {
        gradingService.localAIStatus
    }

    var selectedAIConstraintTemplates: [GradingConstraintTemplate] {
        GradingConstraintTemplates.templates(for: assignment.selectedInstructionTemplateIDs)
    }

    var recommendedAIConstraintTemplates: [GradingConstraintTemplate] {
        GradingConstraintTemplates.templates(for: GradingConstraintTemplates.recommendedIDs(for: assignment))
    }

    var hasLowConfidenceOCR: Bool {
        assignment.ocrDocument?.hasLowConfidenceText == true
    }

    var qualitySummary: OCRQualitySummary {
        assignment.ocrDocument?.qualitySummary ?? OCRQualitySummary()
    }

    var readinessIssues: [String] {
        var issues: [String] = []
        if case .unavailable(let message) = localAIStatus {
            issues.append(message)
        }
        if !assignment.hasGradingStandard {
            issues.append("Add a rubric, answer key, exemplar, or grading criteria.")
        }
        if assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Add student work or review scanned text.")
        }
        if assignment.ocrReviewStatus.blocksGrading {
            issues.append("Review scanned text before drafting feedback.")
        }
        if assignment.latestDraftIsStale {
            issues.append("Needs recheck: student work, rubric, or evidence changed.")
        }
        if assignment.finalReviewIsStale {
            issues.append("This review needs rechecking because student work, rubric, or evidence changed.")
        }
        if assignment.finalReview?.status != .approved, let blockMessage = finalReviewApprovalBlockMessage {
            issues.append(blockMessage)
        }

        if !canExportStudentReport {
            issues.append("Student-facing export is blocked until the teacher approves the final grade.")
        }
        return issues
    }

    var canExportStudentReport: Bool {
        assignment.isStudentFacingExportReady
    }

    var canApproveFinalReview: Bool {
        guard let finalReview = assignment.finalReview else {
            return false
        }
        guard finalReview.criteria.isEmpty == false else {
            return false
        }
        if assignment.hasGradingStandard && assignment.finalReviewIsStale {
            return false
        }
        if !finalReview.allCriteriaApproved {
            return false
        }
        if finalReview.criteria.contains(where: { criterion in
            criterion.finalPoints < 0 || criterion.finalPoints > criterion.maxPoints
        }) {
            return false
        }
        return true
    }

    var finalReviewApprovalBlockMessage: String? {
        guard let finalReview = assignment.finalReview else {
            return "Create a final review before final approval."
        }
        if finalReview.criteria.isEmpty {
            return "Add at least one criterion before approval."
        }
        if assignment.hasGradingStandard && assignment.finalReviewIsStale {
            return "Recheck final review because student work, rubric, or evidence changed."
        }
        if !finalReview.allCriteriaApproved {
            return "Approve all final-review criteria before finalizing."
        }
        if finalReview.criteria.contains(where: { criterion in
            criterion.finalPoints < 0 || criterion.finalPoints > criterion.maxPoints
        }) {
            return "Correct out-of-range criterion scores before finalizing."
        }
        return nil
    }

    var persistenceSummary: String {
        "Stored locally on this device"
    }

    var localDataExcludedFromDeviceBackup: Bool {
        deviceBackupPolicyStatus.isExcluded
    }

    var deviceBackupStatusSummary: String {
        switch deviceBackupPolicyStatus {
        case .excluded:
            return "Student records are marked to stay out of device backup where the platform supports this file setting."
        case .included:
            return "Student records may be included in device backup according to this device and account configuration."
        case .unknown(let detail):
            return "Device-backup exclusion has not been verified. \(detail)"
        }
    }

    var canDraftGrade: Bool {
        guard assignment.assignmentInputReady, !isWorking else { return false }
        if case .available = localAIStatus { return true }
        return false
    }

    var canStartManualFinalReview: Bool {
        !assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        assignment.hasGradingStandard &&
        !assignment.requiresOCRReviewBeforeGrading
    }

    var gradebookAssignments: [AssignmentRecord] {
        assignments.sorted { lhs, rhs in
            let classCompare = lhs.className.localizedCaseInsensitiveCompare(rhs.className)
            if classCompare != .orderedSame { return classCompare == .orderedAscending }
            let titleCompare = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleCompare != .orderedSame { return titleCompare == .orderedAscending }
            return lhs.studentDisplayName.localizedCaseInsensitiveCompare(rhs.studentDisplayName) == .orderedAscending
        }
    }

    /// Readiness issues that block manual grading (no AI required).
    var manualGradingReadinessIssues: [String] {
        var issues: [String] = []
        if !assignment.hasGradingStandard {
            issues.append("Add a rubric, answer key, exemplar, or grading criteria before drafting feedback.")
        }
        if assignment.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Add or review the student text before drafting feedback.")
        }
        if assignment.ocrReviewStatus.blocksGrading {
            issues.append("Review and confirm scanned text before drafting feedback.")
        }
        return issues
    }

    var canCancelDraftGeneration: Bool {
        draftGenerationTask != nil && aiGenerationProgress.canCancel
    }

    var curriculumCatalogSummary: String {
        "\(curriculumCatalog.displayName): \(curriculumCatalog.items.count) item(s) from \(curriculumCatalog.sources.count) source(s)."
    }

    var curriculumAvailableCatalogKinds: [String] {
        CurriculumCatalogService.availableCatalogKinds(in: curriculumCatalog)
    }

    var curriculumAvailableLearningAreas: [String] {
        CurriculumCatalogService.availableLearningAreas(in: curriculumCatalog)
    }

    var curriculumAvailableSubjects: [String] {
        CurriculumCatalogService.availableSubjects(in: curriculumCatalog)
    }

    var curriculumAvailableYearLevelsAndBands: [String] {
        CurriculumCatalogService.availableYearLevelsAndBands(in: curriculumCatalog)
    }

    var curriculumSearchResults: [CurriculumItem] {
        CurriculumCatalogService.searchItems(
            in: curriculumCatalog,
            catalogKind: curriculumCatalogKindFilter,
            subject: curriculumSubjectFilter,
            learningArea: curriculumLearningAreaFilter,
            yearLevel: curriculumYearLevelFilter,
            searchText: curriculumSearchText
        )
    }

    var filteredCurriculumItems: [CurriculumItem] {
        curriculumSearchResults
    }

    var mappedCurriculumItemsForCurrentAssignment: [CurriculumItem] {
        let ids = assignment.curriculumMappings
            .filter { $0.teacherSelected }
            .map(\.curriculumItemID)
        return CurriculumCatalogService.items(ids: ids, in: curriculumCatalog)
    }

    var clipboardTextExportKinds: Set<ExportKind> {
        [.studentMarkdown, .teacherAuditMarkdown, .csvGradebook]
        // assignmentGradebookArchive is a ZIP; not clipboard-copyable
    }

}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
