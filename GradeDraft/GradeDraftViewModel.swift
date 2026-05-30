import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
final class GradeDraftViewModel: ObservableObject {
    @Published var assignments: [AssignmentRecord] = []
    @Published var selectedAssignmentID: UUID?
    @Published var isWorking = false
    @Published var statusMessage = "Local-only mode. No student work is uploaded."
    @Published var errorMessage: String?
    @Published var exportURL: URL?
    @Published var exportKind: ExportKind?
    @Published var classGroups: [ClassGroupRecord] = []
    @Published var students: [StudentRecord] = []
    @Published var assignmentRosterEntries: [AssignmentRosterEntry] = []
    @Published var latestRosterPreview: RosterImportPreview?
    @Published var latestRubricPreview: RubricImportPreview?
    @Published var latestRestorePreview: BackupRestorePreview?
    @Published var backupConflictResolution: BackupConflictResolution = .restoreAsCopy
    @Published var curriculumCatalog: CurriculumCatalog = CurriculumCatalogService.localCatalog
    @Published var curriculumSearchText = ""
    @Published var curriculumLearningAreaFilter = ""
    @Published var curriculumYearLevelFilter = ""
    @Published private(set) var deviceBackupPolicyStatus: DeviceBackupPolicyStatus = .unknown("Backup exclusion has not been checked yet.")

    private let ocrService: OCRServicing
    private let gradingService: GradingServicing & CapabilityChecking
    private let store: AssignmentStoring
    private let fileManager: FileManager
    @Published private(set) var persistenceMode: String

    init(
        assignments: [AssignmentRecord] = [],
        ocrService: OCRServicing = VisionOCRService(),
        gradingService: GradingServicing & CapabilityChecking = FoundationModelGradingService(),
        store: AssignmentStoring? = nil,
        fileManager: FileManager = .default
    ) {
        self.ocrService = ocrService
        self.gradingService = gradingService
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
        refreshAssignmentRosterEntries()
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

    private var finalReviewApprovalBlockMessage: String? {
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
        "Persistence: \(persistenceMode)"
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

    func refreshDeviceBackupPolicyStatus() {
        do {
            let directory = try store.applicationSupportDirectory()
            let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
            if let excluded = values.isExcludedFromBackup {
                deviceBackupPolicyStatus = excluded ? .excluded : .included
            } else {
                deviceBackupPolicyStatus = .unknown("The platform did not report an exclusion value for the local storage directory.")
            }
        } catch {
            deviceBackupPolicyStatus = .unknown(error.localizedDescription)
        }
    }

    func includeLocalDataInDeviceBackupAfterWarning() {
        do {
            try setApplicationSupportExcludedFromDeviceBackup(false, surfaceStatus: true)
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func keepLocalDataExcludedFromDeviceBackup() {
        do {
            try setApplicationSupportExcludedFromDeviceBackup(true, surfaceStatus: true)
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    private func setApplicationSupportExcludedFromDeviceBackup(_ excluded: Bool, surfaceStatus: Bool) throws {
        var directory = try store.applicationSupportDirectory()
        var values = URLResourceValues()
        values.isExcludedFromBackup = excluded
        try directory.setResourceValues(values)
        deviceBackupPolicyStatus = excluded ? .excluded : .included
        if surfaceStatus {
            statusMessage = excluded
                ? "Local student records remain excluded from device backup where supported."
                : "Local student records may now be included in device backup according to device settings."
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

    func assignmentRosterStatus(for record: AssignmentRecord) -> AssignmentRosterStatus {
        if record.exportRecords.contains(where: { $0.exportKind == .studentPDF || $0.exportKind == .zipArchive }) { return .exported }
        if record.finalReview?.status == .approved && !record.finalReviewIsStale { return .approved }
        if record.finalReview != nil { return .finalReviewInProgress }
        if record.latestDraft != nil && !record.latestDraftIsStale { return .draftGenerated }
        if record.ocrReviewStatus.blocksGrading { return .ocrReviewNeeded }
        if record.reviewedStudentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return record.sourceInputs.isEmpty ? .sourceNeeded : .ocrReviewNeeded }
        if record.hasGradingStandard { return .readyForGrading }
        return .notStarted
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

    func refreshCapabilityStatus() {
        switch gradingService.localAIStatus {
        case .available:
            statusMessage = "Local AI is available on this device. Student work stays on device."
            (gradingService as? FoundationModelGradingService)?.prewarmIfAvailable()
        case .unavailable(let message):
            statusMessage = message
        }
    }

    func selectAssignment(_ id: UUID) {
        selectedAssignmentID = id
        exportURL = nil
        exportKind = nil
        refreshCapabilityStatus()
    }

    func newAssignment(from template: RubricTemplate? = nil) {
        var newRecord = AssignmentRecord()
        newRecord.appendAuditEvent(.assignmentCreated, detail: "Assignment created locally.")
        if let template {
            newRecord.title = template.name
            newRecord.assignmentType = template.assignmentType
            newRecord.assessmentPurpose = template.assessmentPurpose
            newRecord.rubricText = template.rubricText
            newRecord.customInstructions = template.customInstructions
        }
        upsertAssignment(newRecord)
        selectedAssignmentID = newRecord.id
        persistOrSurfaceError()
    }

    func duplicateCurrentAssignment() {
        var copy = assignment
        copy.id = UUID()
        copy.title = "Copy of \(copy.title)"
        copy.latestDraft = nil
        copy.finalReview = nil
        copy.exportRecords = []
        copy.auditEvents = [AuditEvent(eventType: .assignmentCreated, detail: "Assignment duplicated locally from another record.")]
        copy.createdAt = Date()
        copy.updatedAt = Date()
        upsertAssignment(copy)
        selectedAssignmentID = copy.id
        persistOrSurfaceError()
    }

    func deleteCurrentAssignment() {
        guard let selectedAssignmentID else { return }
        let assignmentToDelete = assignments.first { $0.id == selectedAssignmentID }
        assignments.removeAll { $0.id == selectedAssignmentID }
        if assignments.isEmpty {
            assignments = [AssignmentRecord()]
        }
        self.selectedAssignmentID = assignments.first?.id
        do {
            try store.deleteAssignment(id: selectedAssignmentID)
            try store.saveAssignments(assignments)
            // Delete source image files for this assignment if present.
            if let appDir = try? store.applicationSupportDirectory(),
               let toDelete = assignmentToDelete,
               !toDelete.sourceInputs.isEmpty {
                let sourceDir = appDir
                    .appendingPathComponent("Sources", isDirectory: true)
                    .appendingPathComponent(selectedAssignmentID.uuidString, isDirectory: true)
                if fileManager.fileExists(atPath: sourceDir.path) {
                    try? fileManager.removeItem(at: sourceDir)
                }
            }
            statusMessage = "Assignment deleted locally."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func updateAssignment(_ transform: (inout AssignmentRecord) -> Void) {
        var updated = assignment
        let previousFingerprint = updated.gradingPacketFingerprint
        transform(&updated)
        updated.updatedAt = Date()
        if updated.gradingPacketFingerprint != previousFingerprint {
            if updated.latestDraft != nil {
                updated.latestDraft?.status = .stale
                updated.appendAuditEvent(.draftMarkedStale, detail: "Grading inputs changed after a draft was generated.")
            }
            if updated.finalReview != nil {
                updated.finalReview?.status = .stale
                updated.appendAuditEvent(.finalReviewMarkedStale, detail: "Grading inputs changed after final review.")
            }
        }
        upsertAssignment(updated)
    }

    func applyTemplate(_ template: RubricTemplate) {
        updateAssignment { assignment in
            assignment = GradeDraftTemplateApplication.applyingRubricTemplate(template, to: assignment, resetDrafts: false)
        }
        persistOrSurfaceError()
        statusMessage = "Rubric template applied locally. Review before drafting feedback."
    }

    func applyTeacherInstructionTemplate(_ template: TeacherInstructionTemplate, mode: TemplateInsertionMode = .append) {
        updateAssignment { assignment in
            assignment = GradeDraftTemplateApplication.appendingInstructionTemplate(template, to: assignment, mode: mode)
        }
        persistOrSurfaceError()
        statusMessage = "Teacher instruction template appended locally."
    }

    func applyAnswerKeyTemplate(_ template: AnswerKeyTemplate, mode: TemplateInsertionMode = .append) {
        updateAssignment { assignment in
            assignment = GradeDraftTemplateApplication.insertingAnswerKeyTemplate(template, to: assignment, mode: mode)
        }
        persistOrSurfaceError()
        statusMessage = "Answer-key template inserted locally. Existing answer-key text was preserved."
    }

    func applyExemplarTemplate(_ template: ExemplarTemplate, mode: TemplateInsertionMode = .append) {
        updateAssignment { assignment in
            assignment = GradeDraftTemplateApplication.insertingExemplarTemplate(template, to: assignment, mode: mode)
        }
        persistOrSurfaceError()
        statusMessage = "Exemplar template inserted locally. Existing exemplar text was preserved."
    }

    func applyFormativeFocusTemplate(_ template: FormativeFocusTemplate, mode: TemplateInsertionMode = .append) {
        updateAssignment { assignment in
            assignment = GradeDraftTemplateApplication.insertingFormativeFocusTemplate(template, to: assignment, mode: mode)
        }
        persistOrSurfaceError()
        statusMessage = "Formative focus template appended locally."
    }

    func toggleAIConstraintTemplate(_ templateID: String) {
        updateAssignment { assignment in
            if assignment.selectedInstructionTemplateIDs.contains(templateID) {
                assignment.selectedInstructionTemplateIDs.removeAll { $0 == templateID }
            } else {
                assignment.selectedInstructionTemplateIDs.append(templateID)
            }
            assignment.selectedInstructionTemplateIDs = GradingConstraintTemplates.builtIn
                .map(\.id)
                .filter { assignment.selectedInstructionTemplateIDs.contains($0) }
            assignment.appendAuditEvent(.inputChanged, detail: "AI constraint template selection changed.")
        }
        persistOrSurfaceError()
        statusMessage = "AI constraint templates updated. Regenerate any stale draft before final review."
    }

    func applyRecommendedAIConstraintTemplates() {
        updateAssignment { assignment in
            assignment.selectedInstructionTemplateIDs = GradingConstraintTemplates.recommendedIDs(for: assignment)
            assignment.appendAuditEvent(.inputChanged, detail: "Recommended AI constraint templates applied.")
        }
        persistOrSurfaceError()
        statusMessage = "Recommended AI constraint templates applied. Sensitive templates were not selected automatically."
    }

    func clearAIConstraintTemplates() {
        updateAssignment { assignment in
            assignment.selectedInstructionTemplateIDs = []
            assignment.appendAuditEvent(.inputChanged, detail: "AI constraint templates cleared.")
        }
        persistOrSurfaceError()
        statusMessage = "AI constraint templates cleared."
    }

    func applyPastedStudentText(_ text: String) {
        updateAssignment { assignment in
            assignment.reviewedStudentText = text
            assignment.ocrDocument = nil
            assignment.ocrReviewStatus = .notNeeded
            assignment.ocrReviewedAt = nil
            assignment.sourceInputs = [SourceInputRef(sourceType: .pastedText, contentDigest: StableFingerprint.fingerprint([text]), digestAlgorithm: "fnv1a64")]
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Pasted student text applied as teacher-reviewed input.")
        }
        persistOrSurfaceError()
    }

    func applyScannedImages(_ images: [UIImage]) async {
        await applyImages(images, sourceType: .scan)
    }

    func applyPhotoImages(_ images: [UIImage]) async {
        await applyImages(images, sourceType: .photo)
    }

    func applyImages(_ images: [UIImage], sourceType: SourceType) async {
        guard !images.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        exportURL = nil
        exportKind = nil
        defer { isWorking = false }

        do {
            let sourceRefs = try persistSourceImages(images, sourceType: sourceType, assignmentID: assignment.id)
            var document = try await ocrService.recognizeText(in: images)
            for index in document.pages.indices where index < sourceRefs.count {
                document.pages[index].sourceInputID = sourceRefs[index].id
            }
            document.reviewStatus = .needsReview

            updateAssignment { assignment in
                assignment.sourceInputs = sourceRefs
                assignment.ocrDocument = document
                assignment.ocrReviewStatus = .needsReview
                assignment.ocrReviewedAt = nil
                assignment.reviewedStudentText = document.combinedText
                assignment.latestDraft = nil
                assignment.finalReview = nil
                assignment.appendAuditEvent(.sourceCaptured, detail: "Captured \(images.count) \(sourceType.displayName.lowercased()) page(s) locally.")
                assignment.appendAuditEvent(.ocrCompleted, detail: document.qualitySummary.displaySummary)
            }
            statusMessage = "Text recognition complete. Review scanned text before drafting feedback."
            try saveCurrentAssignment()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearCurrentStudentWork() {
        let assignmentID = assignment.id
        let hadSourceInputs = !assignment.sourceInputs.isEmpty
        var cleanupErrorDetail: String?
        if hadSourceInputs {
            do {
                let appDir = try store.applicationSupportDirectory()
                let sourceDir = appDir
                    .appendingPathComponent("Sources", isDirectory: true)
                    .appendingPathComponent(assignmentID.uuidString, isDirectory: true)
                if fileManager.fileExists(atPath: sourceDir.path) {
                    try fileManager.removeItem(at: sourceDir)
                }
            } catch {
                cleanupErrorDetail = error.localizedDescription
            }
        }
        updateAssignment { assignment in
            assignment.ocrDocument = nil
            assignment.ocrReviewStatus = .notNeeded
            assignment.ocrReviewedAt = nil
            assignment.sourceInputs = []
            assignment.reviewedStudentText = ""
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Teacher cleared student work and reviewed text after the local clear-work warning.")
            if let cleanupErrorDetail {
                assignment.appendAuditEvent(.localFileCleanupFailed, detail: cleanupErrorDetail)
            }
        }
        persistOrSurfaceError()
        if let cleanupErrorDetail {
            errorMessage = "Student work references were cleared, but local source files may remain: \(cleanupErrorDetail)"
        } else {
            statusMessage = "Student work cleared locally."
        }
    }

    func markOCRReviewed() {
        guard assignment.ocrDocument != nil else { return }
        updateAssignment { assignment in
            assignment.ocrDocument = assignment.ocrDocument?.markingAllLinesConfirmed()
            assignment.ocrReviewStatus = .reviewed
            assignment.ocrReviewedAt = Date()
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.ocrReviewed, detail: "Teacher marked scanned text reviewed. Reviewed text is now eligible for grading.")
        }
        persistOrSurfaceError()
        statusMessage = "Scanned text reviewed. Draft feedback is now available if Local AI and rubric are ready."
    }

    func draftGrade() async {
        guard canDraftGrade else {
            errorMessage = readinessIssues.first ?? "Draft feedback is not ready."
            return
        }
        isWorking = true
        errorMessage = nil
        exportURL = nil
        exportKind = nil
        defer { isWorking = false }

        do {
            let input = assignment.gradingInput
            let result = try await gradingService.draftGrade(input: input)
            updateAssignment { assignment in
                assignment.latestDraft = result
                assignment.finalReview = nil
                assignment.appendAuditEvent(.draftGenerated, detail: "Local grading draft generated from packet \(input.packetFingerprint).")
            }
            if result.localModelAudit?.generationMode == .perCriterion {
                statusMessage = "Draft generated locally criterion-by-criterion because the full packet was too large. Review every criterion carefully before approval."
            } else {
                statusMessage = "Draft feedback suggestion generated locally using Apple Foundation Models. Start teacher final review before using it."
            }
            try saveCurrentAssignment()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startFinalReviewFromLatestDraft() {
        guard let draft = assignment.latestDraft else { return }
        guard !assignment.latestDraftIsStale else {
            errorMessage = "The latest local AI draft is stale because the grading packet changed. Generate a new draft or start manual final review."
            return
        }
        guard draft.packetFingerprint == assignment.gradingPacketFingerprint else {
            errorMessage = "The latest local AI draft does not match the current grading packet. Generate a new draft or start manual final review."
            return
        }
        let final = FinalGradeReview(
            packetFingerprint: draft.packetFingerprint,
            status: .inProgress,
            criteria: draft.criteria.map(FinalCriterionScore.init(from:)),
            totalScore: draft.totalScore,
            maxScore: draft.maxScore,
            studentFeedback: draft.studentFeedback,
            privateTeacherNotes: draft.teacherNotes,
            teacherEdited: false
        )
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: final)
            assignment.appendAuditEvent(.finalReviewStarted, detail: "Teacher review started from the latest local draft.")
        }
        persistOrSurfaceError()
        statusMessage = "Final review started. Approve each criterion before exporting as final."
    }

    func startManualFinalReview() {
        guard canStartManualFinalReview else {
            errorMessage = manualGradingReadinessIssues.first ?? "Cannot start manual final review yet."
            return
        }

        let parsedCriteria = assignment.parsedRubric.criteria
        let finalCriteria: [FinalCriterionScore]

        if !parsedCriteria.isEmpty {
            finalCriteria = parsedCriteria.map { criterion in
                FinalCriterionScore(
                    criterionID: criterion.id,
                    criterion: criterion.title,
                    rating: "",
                    proposedPoints: 0,
                    finalPoints: 0,
                    maxPoints: criterion.maxPoints,
                    evidence: [],
                    explanation: "",
                    teacherApproved: false,
                    teacherRationale: "Manual teacher-created final review."
                )
            }
        } else {
            finalCriteria = [FinalCriterionScore(
                criterionID: nil,
                criterion: "Teacher-entered grading standard",
                rating: "",
                proposedPoints: 0,
                finalPoints: 0,
                maxPoints: 0,
                evidence: [],
                explanation: "",
                teacherApproved: false,
                teacherRationale: "Manual teacher-created final review. Edit this criterion to match the grading standard, then approve it."
            )]
        }

        let review = FinalGradeReview(
            packetFingerprint: assignment.gradingPacketFingerprint,
            status: .inProgress,
            criteria: finalCriteria,
            totalScore: 0,
            maxScore: finalCriteria.map(\.maxPoints).reduce(0, +),
            studentFeedback: "",
            privateTeacherNotes: "",
            teacherEdited: false
        )
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.finalReviewStarted, detail: "Teacher started manual final review without AI draft.")
        }
        persistOrSurfaceError()
        statusMessage = "Manual final review started. Edit criteria, approve each one, then approve the final grade."
    }

    func addCriterionToFinalReview() {
        guard var review = assignment.finalReview else { return }
        let newCriterion = FinalCriterionScore(
            criterionID: nil,
            criterion: "New criterion",
            rating: "",
            proposedPoints: 0,
            finalPoints: 0,
            maxPoints: 0,
            evidence: [],
            explanation: "",
            teacherApproved: false,
            teacherRationale: ""
        )
        review.criteria.append(newCriterion)
        review.teacherEdited = true
        review = GradeTotals.applyingDeterministicTotals(to: review)
        updateAssignment { assignment in
            assignment.finalReview = review
        }
        persistOrSurfaceError()
    }

    func deleteCriterionFromFinalReview(id: UUID) {
        guard var review = assignment.finalReview else { return }
        review.criteria.removeAll { $0.id == id }
        review.teacherEdited = true
        review = GradeTotals.applyingDeterministicTotals(to: review)
        updateAssignment { assignment in
            assignment.finalReview = review
        }
        persistOrSurfaceError()
    }

    func updateFinalReview(_ review: FinalGradeReview) {
        var review = review
        review.teacherEdited = true
        updateAssignment { assignment in
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
        }
        persistOrSurfaceError()
    }

    func approveFinalReview() {
        guard var review = assignment.finalReview else { return }
        guard canApproveFinalReview else {
            errorMessage = finalReviewApprovalBlockMessage ?? "This final review is not ready for final approval."
            return
        }
        review.criteria = review.criteria.map { criterion in
            var criterion = criterion
            criterion.teacherApproved = true
            return criterion
        }
        review.status = .approved
        review.finalizedAt = Date()
        review = GradeTotals.applyingDeterministicTotals(to: review)
        updateAssignment { assignment in
            assignment.finalReview = review
            assignment.appendAuditEvent(.finalApproved, detail: "Teacher approved final grade \(GradeTotals.formatted(review.totalScore)) / \(GradeTotals.formatted(review.maxScore)).")
        }
        persistOrSurfaceError()
        statusMessage = "Final grade approved and saved locally."
    }

    func saveCurrentAssignment() throws {
        upsertAssignment(assignment)
        do {
            try store.saveAssignments(assignments)
        } catch {
            throw GradeDraftError.persistenceFailed(error.localizedDescription)
        }
    }

    func exportStudentReport() {
        guard canExportStudentReport else {
            errorMessage = "Student-facing export is blocked until the teacher approves the final grade."
            return
        }

        do {
            let markdown = MarkdownReportBuilder.studentMarkdown(for: assignment)
            exportURL = try MarkdownReportBuilder.writeTemporaryStudentReport(for: assignment)
            exportKind = .studentMarkdown
            recordExport(kind: .studentMarkdown, content: markdown, includesPrivateNotes: false, includesOriginalSources: false)
            statusMessage = "Student Markdown report is ready to share."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportTeacherAuditReport() {
        do {
            let generatedAt = Date()
            let markdown = MarkdownReportBuilder.teacherAuditMarkdown(for: assignment, generatedAt: generatedAt)
            exportURL = try MarkdownReportBuilder.writeTemporaryTeacherAuditReport(for: assignment, generatedAt: generatedAt)
            exportKind = .teacherAuditMarkdown
            recordExport(kind: .teacherAuditMarkdown, content: markdown, includesPrivateNotes: true, includesOriginalSources: false)
            statusMessage = "Teacher Review is ready to share. Treat it as sensitive."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportCSVGradebook() {
        do {
            let csv = CSVExportService.exportedCSV(from: [assignment])
            let destination = temporaryExportURL(kind: .csvGradebook, extension: "csv")
            try csv.write(to: destination, atomically: true, encoding: .utf8)
            ExportFileHardening.applyBestEffortProtection(to: destination)
            exportURL = destination
            exportKind = .csvGradebook
            recordExport(kind: .csvGradebook, content: csv, includesPrivateNotes: false, includesOriginalSources: false)
            statusMessage = "CSV grade summary is ready to share."
        } catch {
            handleExportFailure(error)
        }
    }

    func applyPDFFile(_ url: URL) async {
        isWorking = true
        errorMessage = nil
        exportURL = nil
        exportKind = nil
        defer { isWorking = false }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            guard let document = PDFDocument(url: url) else {
                throw GradeDraftError.ocrFailed("The selected PDF could not be opened.")
            }
            guard document.pageCount > 0 else {
                throw GradeDraftError.ocrFailed("The selected PDF did not contain any pages.")
            }

            let appDirectory = try store.applicationSupportDirectory()
            let sourceRoot = appDirectory
                .appendingPathComponent("Sources", isDirectory: true)
                .appendingPathComponent(assignment.id.uuidString, isDirectory: true)
            let originalFolder = sourceRoot.appendingPathComponent("original", isDirectory: true)
            try fileManager.createDirectory(at: originalFolder, withIntermediateDirectories: true)
            let pdfID = UUID()
            let originalPDFURL = originalFolder.appendingPathComponent("\(pdfID.uuidString).pdf")
            if fileManager.fileExists(atPath: originalPDFURL.path) { try fileManager.removeItem(at: originalPDFURL) }
            try fileManager.copyItem(at: url, to: originalPDFURL)
            let pdfData = try Data(contentsOf: originalPDFURL)
            let originalPDFSource = SourceInputRef(
                id: pdfID,
                sourceType: .pdf,
                pageIndex: nil,
                localRelativePath: "Sources/\(assignment.id.uuidString)/original/\(pdfID.uuidString).pdf",
                fileName: url.lastPathComponent,
                mimeType: "application/pdf",
                contentDigest: StableFingerprint.fingerprint(pdfData),
                digestAlgorithm: "fnv1a64",
                pdfPageCount: document.pageCount,
                teacherIncludedInExport: true
            )

            let digitalTextByPage = extractDigitalPDFText(document)
            let images = try renderPDFPages(document)
            guard !images.isEmpty else {
                throw GradeDraftError.ocrFailed("The selected PDF did not contain renderable pages.")
            }
            var pageSourceRefs = try persistSourceImages(images, sourceType: .pdf, assignmentID: assignment.id)
            for index in pageSourceRefs.indices {
                pageSourceRefs[index].fileName = "PDF page \(index + 1) render"
                pageSourceRefs[index].mimeType = "image/png"
                pageSourceRefs[index].pdfPageCount = document.pageCount
            }

            let ocrDocument: OCRDocument
            if digitalTextByPage.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                ocrDocument = ocrDocumentFromDigitalPDFText(digitalTextByPage, sourceRefs: pageSourceRefs)
            } else {
                var recognized = try await ocrService.recognizeText(in: images)
                for index in recognized.pages.indices where index < pageSourceRefs.count {
                    recognized.pages[index].sourceInputID = pageSourceRefs[index].id
                }
                ocrDocument = recognized
            }

            var documentForReview = ocrDocument
            documentForReview.reviewStatus = .needsReview
            updateAssignment { assignment in
                assignment.sourceInputs = [originalPDFSource] + pageSourceRefs
                assignment.ocrDocument = documentForReview
                assignment.ocrReviewStatus = .needsReview
                assignment.ocrReviewedAt = nil
                assignment.reviewedStudentText = documentForReview.combinedText
                assignment.latestDraft = nil
                assignment.finalReview = nil
                assignment.appendAuditEvent(.sourceCaptured, detail: "Imported local PDF with \(document.pageCount) page(s); original PDF and rendered pages stored locally.")
                assignment.appendAuditEvent(.ocrCompleted, detail: documentForReview.qualitySummary.displaySummary)
            }
            statusMessage = "PDF imported. Review scanned text before drafting feedback."
            try saveCurrentAssignment()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previewMarkdownRubric(_ text: String) -> RubricImportPreview {
        let preview = MarkdownRubricParser.preview(text)
        latestRubricPreview = preview
        return preview
    }

    func confirmMarkdownRubricImport(_ preview: RubricImportPreview, useStructuredImport: Bool = true) {
        updateAssignment { assignment in
            assignment.rubricText = preview.rawMarkdown
            let criterionCount = useStructuredImport ? preview.detectedCriteria.count : 0
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Confirmed rubric import with \(criterionCount) structured criterion/criteria and \(preview.issues.count) item(s) needing attention.")
        }
        persistOrSurfaceError()
        latestRubricPreview = nil
        statusMessage = preview.detectedCriteria.isEmpty ? "Rubric text saved for teacher review." : "Rubric imported with a teacher-confirmed structured preview."
    }

    func importMarkdownRubric(from url: URL) {
        do {
            let text = try readTextFile(url)
            let preview = previewMarkdownRubric(text)
            statusMessage = "Markdown rubric preview is ready. Confirm the structured import or use the raw rubric text."
            if preview.detectedCriteria.isEmpty {
                statusMessage = "Markdown rubric preview found no point-bearing criteria. Confirm raw-text import to use it as grading context."
            }
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    var filteredCurriculumItems: [CurriculumItem] {
        curriculumCatalog.filtered(
            learningArea: curriculumLearningAreaFilter,
            yearLevel: curriculumYearLevelFilter,
            searchText: curriculumSearchText
        )
    }

    func mapCurriculumItemToCurrentAssignment(_ item: CurriculumItem, mappingKind: String = "assignment") {
        updateAssignment { assignment in
            if !assignment.curriculumMappings.contains(where: { $0.curriculumItemID == item.id && $0.mappingKind == mappingKind }) {
                assignment.curriculumMappings.append(CurriculumMapping(curriculumItemID: item.id, mappingKind: mappingKind))
            }
            let selectedItems = assignment.curriculumMappings.compactMap { CurriculumCatalogService.item(id: $0.curriculumItemID, in: curriculumCatalog) }
            assignment.curriculumReference = CurriculumCatalogService.selectedReferenceSummary(items: selectedItems)
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Mapped local curriculum item \(item.code) to assignment.")
        }
        persistOrSurfaceError()
        statusMessage = "Curriculum item mapped locally with source provenance."
    }

    func importCurriculumReference(from url: URL) {
        do {
            let text = try CurriculumImportService.importableText(from: url)
            let summary = CurriculumImportService.summary(from: text, sourceName: url.lastPathComponent)
            updateAssignment { assignment in
                assignment.curriculumReference = summary
                assignment.latestDraft = nil
                assignment.finalReview = nil
                assignment.appendAuditEvent(.inputChanged, detail: "Imported local curriculum/reference material from \(url.lastPathComponent).")
            }
            persistOrSurfaceError()
            statusMessage = "Curriculum/reference material imported locally. Confirm it matches your jurisdiction before grading."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func previewRosterCSV(_ text: String, className: String? = nil) -> RosterImportPreview {
        let preview = RosterImportService.preview(csvText: text, defaultClassName: className ?? assignment.className)
        latestRosterPreview = preview
        return preview
    }

    func saveClassGroup(_ classGroup: ClassGroupRecord) {
        if let index = classGroups.firstIndex(where: { $0.id == classGroup.id }) {
            classGroups[index] = classGroup
        } else {
            classGroups.append(classGroup)
        }
        do {
            try store.saveClassGroup(classGroup)
            statusMessage = "Class saved locally."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func saveStudent(_ student: StudentRecord) {
        if let index = students.firstIndex(where: { $0.id == student.id }) {
            students[index] = student
        } else {
            students.append(student)
        }
        do {
            try store.saveStudent(student)
            statusMessage = "Student saved locally."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func deleteClassGroup(id: UUID) {
        classGroups.removeAll { $0.id == id }
        do {
            try store.deleteClassGroup(id: id)
            statusMessage = "Class archived/deleted locally. Existing assignment records are preserved."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func deleteStudent(id: UUID) {
        students.removeAll { $0.id == id }
        assignmentRosterEntries.removeAll { $0.studentID == id }
        do {
            try store.deleteStudent(id: id)
            statusMessage = "Student record deleted locally. Existing assignment records are preserved for audit continuity."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func createAssignmentsFromRosterCSV(_ text: String, className: String? = nil) {
        let preview = previewRosterCSV(text, className: className ?? assignment.className)
        guard !preview.students.isEmpty else {
            errorMessage = preview.rejectedRows.first ?? "Paste at least one valid student row."
            return
        }

        // Use the displayed class name from the UI (className param) when the CSV has no
        // explicit class column, rather than falling back to the currently-selected assignment.
        let resolvedClassName = preview.className.nilIfBlank
            ?? className?.nilIfBlank
            ?? assignment.className.nilIfBlank
            ?? "Untitled class"
        var classGroup = ClassGroupRecord(
            name: resolvedClassName,
            schoolYear: "",
            term: "",
            subject: assignment.subject,
            gradeLevel: assignment.gradeLevel
        )
        if let existing = classGroups.first(where: { $0.name.localizedCaseInsensitiveCompare(classGroup.name) == .orderedSame }) {
            classGroup = existing
        } else {
            saveClassGroup(classGroup)
        }

        let template = assignment
        var created: [AssignmentRecord] = []
        var rosterEntries: [AssignmentRosterEntry] = []
        for (index, student) in preview.students.enumerated() {
            var savedStudent = student
            if let existing = students.first(where: { !$0.localIdentifier.isEmpty && $0.localIdentifier == student.localIdentifier }) {
                savedStudent = existing
            } else {
                saveStudent(savedStudent)
            }

            var copy = template
            copy.id = UUID()
            copy.classGroupID = classGroup.id
            copy.studentID = savedStudent.id
            copy.className = classGroup.name
            copy.studentDisplayName = savedStudent.displayName
            copy.latestDraft = nil
            copy.finalReview = nil
            copy.exportRecords = []
            copy.auditEvents = [AuditEvent(eventType: .assignmentCreated, detail: "Roster-created assignment for \(savedStudent.displayName).")]
            copy.createdAt = Date()
            copy.updatedAt = Date()
            created.append(copy)
            rosterEntries.append(
                AssignmentRosterEntry(
                    assignmentID: copy.id,
                    studentID: savedStudent.id,
                    studentDisplayName: savedStudent.displayName,
                    localIdentifier: savedStudent.localIdentifier,
                    status: assignmentRosterStatus(for: copy),
                    sortOrder: index
                )
            )
        }
        assignments.append(contentsOf: created)
        assignmentRosterEntries.append(contentsOf: rosterEntries)
        assignments.sort { $0.updatedAt > $1.updatedAt }
        selectedAssignmentID = created.first?.id ?? selectedAssignmentID
        persistOrSurfaceError()
        do { try store.saveAssignmentRoster(rosterEntries) } catch { errorMessage = error.localizedDescription }
        statusMessage = "Created \(created.count) roster assignment(s) locally; \(preview.rejectedRows.count) invalid row(s) were rejected."
    }

    func updateOCRLine(pageID: UUID, lineID: UUID, correctedText: String) {
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for pageIndex in document.pages.indices where document.pages[pageIndex].id == pageID {
                for lineIndex in document.pages[pageIndex].lines.indices where document.pages[pageIndex].lines[lineIndex].id == lineID {
                    document.pages[pageIndex].lines[lineIndex].correctedText = correctedText
                    document.pages[pageIndex].lines[lineIndex].teacherConfirmed = false
                }
            }
            assignment.ocrDocument = document
            assignment.reviewedStudentText = document.combinedText
            assignment.ocrReviewStatus = .needsReview
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Edited scanned text line during teacher review.")
        }
        persistOrSurfaceError()
    }

    func confirmOCRLine(pageID: UUID, lineID: UUID) {
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for pageIndex in document.pages.indices where document.pages[pageIndex].id == pageID {
                for lineIndex in document.pages[pageIndex].lines.indices where document.pages[pageIndex].lines[lineIndex].id == lineID {
                    document.pages[pageIndex].lines[lineIndex].teacherConfirmed = true
                }
            }
            assignment.ocrDocument = document
            assignment.reviewedStudentText = document.combinedText
            assignment.ocrReviewStatus = document.hasUnconfirmedLines ? .needsReview : .reviewed
            if !document.hasUnconfirmedLines {
                document.reviewStatus = .reviewed
                document.reviewedAt = Date()
                assignment.ocrReviewedAt = document.reviewedAt
            } else {
                document.reviewStatus = .needsReview
            }
            assignment.ocrDocument = document
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.ocrReviewed, detail: "Confirmed scanned text line during teacher review.")
        }
        persistOrSurfaceError()
    }

    func rejectOCRLine(pageID: UUID, lineID: UUID) {
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for pageIndex in document.pages.indices where document.pages[pageIndex].id == pageID {
                for lineIndex in document.pages[pageIndex].lines.indices where document.pages[pageIndex].lines[lineIndex].id == lineID {
                    document.pages[pageIndex].lines[lineIndex].isRejected = true
                    document.pages[pageIndex].lines[lineIndex].teacherConfirmed = true
                }
            }
            assignment.ocrDocument = document
            assignment.reviewedStudentText = document.combinedText
            assignment.ocrReviewStatus = document.hasUnconfirmedLines ? .needsReview : .reviewed
            if !document.hasUnconfirmedLines { assignment.ocrReviewedAt = Date() }
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Rejected scanned text line during teacher review; original file details were preserved and line text was excluded from reviewed text.")
        }
        persistOrSurfaceError()
    }

    func markOCRPageReviewed(pageID: UUID) {
        updateAssignment { assignment in
            guard var document = assignment.ocrDocument else { return }
            for pageIndex in document.pages.indices where document.pages[pageIndex].id == pageID {
                for lineIndex in document.pages[pageIndex].lines.indices where !document.pages[pageIndex].lines[lineIndex].isRejected {
                    document.pages[pageIndex].lines[lineIndex].teacherConfirmed = true
                }
            }
            document.reviewStatus = document.hasUnconfirmedLines ? .needsReview : .reviewed
            document.reviewedAt = document.hasUnconfirmedLines ? nil : Date()
            assignment.ocrDocument = document
            assignment.reviewedStudentText = document.combinedText
            assignment.ocrReviewStatus = document.reviewStatus
            assignment.ocrReviewedAt = document.reviewedAt
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.ocrReviewed, detail: "Teacher marked a scanned page reviewed after resolving every active line on that page.")
        }
        persistOrSurfaceError()
    }

    func nextUnreviewedLine(after currentLineID: UUID? = nil) -> (pageID: UUID, lineID: UUID)? {
        guard let document = assignment.ocrDocument else { return nil }
        let unresolved = document.pages.sorted { $0.pageIndex < $1.pageIndex }.flatMap { page in
            page.lines.filter { $0.needsReview }.map { (page.id, $0.id) }
        }
        guard !unresolved.isEmpty else { return nil }
        guard let currentLineID, let currentIndex = unresolved.firstIndex(where: { $0.1 == currentLineID }) else { return unresolved.first }
        return unresolved[(currentIndex + 1) % unresolved.count]
    }

    func addOCRLineEvidenceToFinalReview(pageID: UUID, lineID: UUID, criterionID: UUID?) {
        guard var review = assignment.finalReview,
              let document = assignment.ocrDocument,
              let page = document.pages.first(where: { $0.id == pageID }),
              let line = page.lines.first(where: { $0.id == lineID }) else { return }
        let quote = line.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quote.isEmpty else { return }
        let evidenceRef = EvidenceReference(
            sourceInputID: page.sourceInputID,
            ocrLineID: line.id,
            pageIndex: page.pageIndex,
            quote: quote,
            startOffset: nil,
            endOffset: nil,
            boundingBox: line.boundingBox,
            sourceKind: "ocrLine",
            teacherConfirmed: line.teacherConfirmed
        )
        let sourceRef = evidenceSourceReference(page: page, line: line, evidenceID: evidenceRef.id)
        let targetIndex: Int
        if let criterionID, let found = review.criteria.firstIndex(where: { $0.id == criterionID }) {
            targetIndex = found
        } else {
            targetIndex = review.criteria.startIndex
        }
        guard review.criteria.indices.contains(targetIndex) else { return }
        review.criteria[targetIndex].evidence.append(quote)
        var refs = review.criteria[targetIndex].evidenceSourceRefs ?? []
        refs.append(sourceRef)
        review.criteria[targetIndex].evidenceSourceRefs = refs
        review.criteria[targetIndex].teacherApproved = false
        review.teacherEdited = true
        updateAssignment { assignment in
            assignment.evidenceReferences.append(evidenceRef)
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Linked scanned text evidence to final-review criterion.")
        }
        persistOrSurfaceError()
    }

    func addManualEvidenceToFinalReview(criterionID: UUID?, quote: String) {
        guard var review = assignment.finalReview else { return }
        let cleanedQuote = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuote.isEmpty else { return }
        let evidenceRef = EvidenceReference(
            sourceInputID: nil,
            ocrLineID: nil,
            pageIndex: nil,
            quote: cleanedQuote,
            startOffset: nil,
            endOffset: nil,
            boundingBox: nil,
            sourceKind: "manualTeacherEntry",
            teacherConfirmed: true
        )
        let targetIndex: Int
        if let criterionID, let found = review.criteria.firstIndex(where: { $0.id == criterionID }) {
            targetIndex = found
        } else {
            targetIndex = review.criteria.startIndex
        }
        guard review.criteria.indices.contains(targetIndex) else { return }
        review.criteria[targetIndex].evidence.append(cleanedQuote)
        var refs = review.criteria[targetIndex].evidenceSourceRefs ?? []
        refs.append("evidence:\(evidenceRef.id.uuidString):manualTeacherEntry")
        review.criteria[targetIndex].evidenceSourceRefs = refs
        review.criteria[targetIndex].teacherApproved = false
        review.teacherEdited = true
        updateAssignment { assignment in
            assignment.evidenceReferences.append(evidenceRef)
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Added manual teacher evidence to final-review criterion.")
        }
        persistOrSurfaceError()
    }

    func removeEvidenceFromFinalReview(criterionID: UUID, evidenceIndex: Int) {
        guard var review = assignment.finalReview,
              let criterionIndex = review.criteria.firstIndex(where: { $0.id == criterionID }),
              review.criteria[criterionIndex].evidence.indices.contains(evidenceIndex) else { return }
        let removedQuote = review.criteria[criterionIndex].evidence.remove(at: evidenceIndex)
        var removedEvidenceID: UUID?
        if var refs = review.criteria[criterionIndex].evidenceSourceRefs, refs.indices.contains(evidenceIndex) {
            let ref = refs.remove(at: evidenceIndex)
            removedEvidenceID = evidenceID(in: ref)
            review.criteria[criterionIndex].evidenceSourceRefs = refs
        }
        review.criteria[criterionIndex].teacherApproved = false
        review.teacherEdited = true
        updateAssignment { assignment in
            if let removedEvidenceID {
                assignment.evidenceReferences.removeAll { $0.id == removedEvidenceID }
            } else {
                assignment.evidenceReferences.removeAll { $0.quote == removedQuote }
            }
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Removed evidence from final-review criterion and synchronized source references.")
        }
        persistOrSurfaceError()
    }

    func clearEvidenceFromFinalReview(criterionID: UUID) {
        guard var review = assignment.finalReview,
              let criterionIndex = review.criteria.firstIndex(where: { $0.id == criterionID }) else { return }
        let ids = (review.criteria[criterionIndex].evidenceSourceRefs ?? []).compactMap(evidenceID(in:))
        review.criteria[criterionIndex].evidence = []
        review.criteria[criterionIndex].evidenceSourceRefs = []
        review.criteria[criterionIndex].teacherApproved = false
        review.teacherEdited = true
        updateAssignment { assignment in
            assignment.evidenceReferences.removeAll { ids.contains($0.id) }
            assignment.finalReview = GradeTotals.applyingDeterministicTotals(to: review)
            assignment.appendAuditEvent(.inputChanged, detail: "Cleared criterion evidence and source references.")
        }
        persistOrSurfaceError()
    }

    func sourceImage(for source: SourceInputRef) -> UIImage? {
        guard let localRelativePath = source.localRelativePath,
              let appDir = try? store.applicationSupportDirectory() else { return nil }
        let url = appDir.appendingPathComponent(localRelativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func sourceFiles(for assignment: AssignmentRecord) -> [URL] {
        guard let appDir = try? store.applicationSupportDirectory() else { return [] }
        return assignment.sourceInputs.compactMap { source in
            guard let localRelativePath = source.localRelativePath else { return nil }
            let url = appDir.appendingPathComponent(localRelativePath)
            return fileManager.fileExists(atPath: url.path) ? url : nil
        }
    }

    private func mergeRestoredAssignments(_ restored: [AssignmentRecord], resolution: BackupConflictResolution) -> [AssignmentRecord] {
        var byID = Dictionary(uniqueKeysWithValues: assignments.map { ($0.id, $0) })
        for record in restored {
            if let existing = byID[record.id] {
                switch resolution {
                case .keepLocal:
                    var local = existing
                    local.appendAuditEvent(.inputChanged, detail: "Backup restore detected a conflict and kept the local assignment.")
                    byID[local.id] = local
                case .replaceLocal:
                    var replacement = record
                    replacement.appendAuditEvent(.inputChanged, detail: "Backup restore replaced the local assignment after conflict resolution.")
                    byID[record.id] = replacement
                case .restoreAsCopy:
                    var copy = record
                    let originalID = copy.id
                    copy.id = UUID()
                    copy.sourceInputs = copy.sourceInputs.map { source in
                        var sourceCopy = source
                        if let localRelativePath = source.localRelativePath {
                            sourceCopy.localRelativePath = localRelativePath.replacingOccurrences(
                                of: "Sources/\(originalID.uuidString)/",
                                with: "Sources/\(copy.id.uuidString)/"
                            )
                        }
                        return sourceCopy
                    }
                    copy.title = "Restored copy of \(record.title)"
                    copy.appendAuditEvent(.inputChanged, detail: "Restored as copy because a local record existed with the same ID.")
                    byID[copy.id] = copy
                }
            } else {
                var restoredRecord = record
                restoredRecord.appendAuditEvent(.inputChanged, detail: "Restored from local backup archive.")
                byID[restoredRecord.id] = restoredRecord
            }
        }
        return Array(byID.values)
    }

    func sourceFilesForCurrentAssignment() -> [URL] {
        sourceFiles(for: assignment)
    }

    private func mergeRestoredClassGroups(_ restored: [ClassGroupRecord]) {
        guard !restored.isEmpty else { return }
        var byID = Dictionary(uniqueKeysWithValues: classGroups.map { ($0.id, $0) })
        for record in restored {
            if byID[record.id] == nil || backupConflictResolution == .replaceLocal {
                byID[record.id] = record
            }
        }
        classGroups = Array(byID.values).sorted { $0.name < $1.name }
    }

    private func mergeRestoredStudents(_ restored: [StudentRecord]) {
        guard !restored.isEmpty else { return }
        var byID = Dictionary(uniqueKeysWithValues: students.map { ($0.id, $0) })
        for record in restored {
            if byID[record.id] == nil || backupConflictResolution == .replaceLocal {
                byID[record.id] = record
            }
        }
        students = Array(byID.values).sorted { $0.displayName < $1.displayName }
    }

    private func mergeRestoredRosterEntries(_ restored: [AssignmentRosterEntry]) {
        guard !restored.isEmpty else { return }
        var byID = Dictionary(uniqueKeysWithValues: assignmentRosterEntries.map { ($0.id, $0) })
        for entry in restored {
            if byID[entry.id] == nil || backupConflictResolution == .replaceLocal {
                byID[entry.id] = entry
            }
        }
        assignmentRosterEntries = Array(byID.values).sorted { $0.sortOrder < $1.sortOrder }
    }


    func exportStudentPDF() {
        guard canExportStudentReport else {
            errorMessage = "Student-facing export is blocked until the teacher approves the final grade."
            return
        }
        do {
            let destination = temporaryExportURL(kind: .studentPDF, extension: "pdf")
            exportURL = try PDFExportService.studentReportPDF(for: assignment, destination: destination)
            exportKind = .studentPDF
            if let exportURL { recordExport(kind: .studentPDF, fileURL: exportURL, includesPrivateNotes: false, includesOriginalSources: false) }
            statusMessage = "Student Report PDF is ready to share."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportTeacherAuditPDF() {
        do {
            let destination = temporaryExportURL(kind: .teacherAuditPDF, extension: "pdf")
            exportURL = try PDFExportService.teacherAuditPDF(for: assignment, destination: destination)
            exportKind = .teacherAuditPDF
            if let exportURL { recordExport(kind: .teacherAuditPDF, fileURL: exportURL, includesPrivateNotes: true, includesOriginalSources: false) }
            statusMessage = "Teacher Review PDF is ready to share. Treat it as sensitive."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportArchiveBundle() {
        do {
            let sourceFiles = sourceFilesForCurrentAssignment()
            let destination = try BundleExportService.preflightDestination(for: assignment.id)
            exportURL = try BundleExportService.writeTeacherAuditArchive(assignment: assignment, sourceFiles: sourceFiles, to: destination)
            exportKind = .zipArchive
            if let exportURL { recordExport(kind: .zipArchive, fileURL: exportURL, includesPrivateNotes: true, includesOriginalSources: !sourceFiles.isEmpty) }
            statusMessage = "Teacher archive ZIP is ready to share. Treat it as sensitive."
        } catch {
            handleExportFailure(error)
        }
    }

    func exportBackupJSON() {
        do {
            let destination = temporaryExportURL(kind: .fullBackupArchive, extension: "zip", assignmentID: nil)
            let sourceFilesForBackup = assignments.flatMap { assignment in
                sourceFiles(for: assignment)
            }
            exportURL = try BundleExportService.writeFullBackup(assignments: assignments, sourceFiles: sourceFilesForBackup, to: destination, classGroups: classGroups, students: students, rosterEntries: assignmentRosterEntries)
            exportKind = .fullBackupArchive
            if let exportURL { recordExport(kind: .fullBackupArchive, fileURL: exportURL, includesPrivateNotes: true, includesOriginalSources: !sourceFilesForBackup.isEmpty) }
            statusMessage = "Full local backup archive is ready to share. Treat it as sensitive student data."
        } catch {
            handleExportFailure(error)
        }
    }

    func restoreBackup(from url: URL) {
        do {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let restored: [AssignmentRecord]
            var restoredDatabaseExport: BackupDatabaseExport?
            if url.pathExtension.lowercased() == "zip" {
                latestRestorePreview = try BundleExportService.previewRestore(from: url, existingAssignments: assignments)
                restoredDatabaseExport = try BundleExportService.readBackupDatabaseExport(from: url)
                restored = try BundleExportService.restoreBackupArchive(
                    from: url,
                    existingAssignments: assignments,
                    applicationSupportDirectory: try store.applicationSupportDirectory(),
                    conflictResolution: backupConflictResolution
                )
            } else {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                restored = try decoder.decode([AssignmentRecord].self, from: data)
                latestRestorePreview = BackupRestorePreview(
                    archiveKind: "legacy-json",
                    schemaVersion: "legacy-json",
                    assignmentCount: restored.count,
                    classCount: 0,
                    studentCount: 0,
                    sourceFileCount: 0,
                    conflictAssignmentIDs: restored.compactMap { restoredRecord in assignments.contains(where: { $0.id == restoredRecord.id }) ? restoredRecord.id : nil },
                    warnings: ["Legacy JSON backup does not contain original files, classes, students, or backup details."]
                )
            }
            guard !restored.isEmpty else {
                errorMessage = "Backup contained no assignments."
                return
            }
            let merged = mergeRestoredAssignments(restored, resolution: backupConflictResolution)
            assignments = merged.sorted { $0.updatedAt > $1.updatedAt }
            refreshAssignmentRosterEntries()
            if let restoredDatabaseExport {
                mergeRestoredClassGroups(restoredDatabaseExport.classGroups)
                mergeRestoredStudents(restoredDatabaseExport.students)
                mergeRestoredRosterEntries(restoredDatabaseExport.rosterEntries)
            }
            selectedAssignmentID = assignments.first?.id
            try store.saveAssignments(assignments)
            for classGroup in classGroups { try? store.saveClassGroup(classGroup) }
            for student in students { try? store.saveStudent(student) }
            if !assignmentRosterEntries.isEmpty { try? store.saveAssignmentRoster(assignmentRosterEntries) }
            statusMessage = "Restored \(restored.count) assignment(s) plus related class, student, roster, and original-file records from local backup with \(backupConflictResolution.displayName.lowercased()) handling."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func copyPreparedExportTextToClipboard() {
        guard let exportURL, let exportKind else {
            errorMessage = "Create an export before copying text."
            return
        }
        guard clipboardTextExportKinds.contains(exportKind) else {
            errorMessage = "Clipboard copy is available only for text-based exports."
            return
        }
        do {
            let text = try String(contentsOf: exportURL, encoding: .utf8)
            UIPasteboard.general.string = text
            updateAssignment { assignment in
                assignment.appendAuditEvent(.exportPrepared, detail: "Copied \(exportKind.displayName) text to clipboard after the clipboard warning.")
            }
            persistOrSurfaceError()
            statusMessage = "Export text copied to the clipboard. Share only through approved channels."
        } catch {
            errorMessage = GradeDraftError.exportFailed(error.localizedDescription).localizedDescription
        }
    }

    func exportRiskSummary(for exportKind: ExportKind) -> ExportRiskSummary {
        let scopedAssignments: [AssignmentRecord]
        switch exportKind {
        case .fullBackupArchive, .backupJSON:
            scopedAssignments = assignments
        default:
            scopedAssignments = [assignment]
        }
        let includesDraftContent: Bool
        switch exportKind {
        case .studentMarkdown, .studentPDF:
            includesDraftContent = false
        case .csvGradebook:
            includesDraftContent = scopedAssignments.contains { record in
                record.finalReview == nil || record.finalReview?.status != .approved || record.finalReviewIsStale
            }
        case .teacherAuditMarkdown, .teacherAuditPDF, .zipArchive, .backupJSON, .fullBackupArchive:
            includesDraftContent = scopedAssignments.contains { record in
                record.latestDraft != nil || record.finalReview?.status != .approved || record.finalReviewIsStale
            }
        }
        let includesPrivateNotes: Bool
        switch exportKind {
        case .studentMarkdown, .studentPDF, .csvGradebook:
            includesPrivateNotes = false
        case .teacherAuditMarkdown, .teacherAuditPDF, .zipArchive, .backupJSON, .fullBackupArchive:
            includesPrivateNotes = true
        }
        let includesOriginalSources: Bool
        switch exportKind {
        case .zipArchive:
            includesOriginalSources = !sourceFilesForCurrentAssignment().isEmpty
        case .fullBackupArchive:
            includesOriginalSources = assignments.contains { !sourceFiles(for: $0).isEmpty }
        default:
            includesOriginalSources = false
        }
        return ExportRiskSummary(
            includesDraftContent: includesDraftContent,
            includesPrivateNotes: includesPrivateNotes,
            includesOriginalSources: includesOriginalSources,
            affectedAssignmentCount: scopedAssignments.count
        )
    }

    private var clipboardTextExportKinds: Set<ExportKind> {
        [.studentMarkdown, .teacherAuditMarkdown, .csvGradebook, .backupJSON]
    }

    private func recordExport(kind: ExportKind, content: String, includesPrivateNotes: Bool, includesOriginalSources: Bool) {
        appendExportRecord(
            kind: kind,
            contentFingerprint: StableFingerprint.fingerprint(Data(content.utf8)),
            includesPrivateNotes: includesPrivateNotes,
            includesOriginalSources: includesOriginalSources
        )
    }

    private func recordExport(kind: ExportKind, fileURL: URL, includesPrivateNotes: Bool, includesOriginalSources: Bool) {
        do {
            let data = try Data(contentsOf: fileURL)
            appendExportRecord(
                kind: kind,
                contentFingerprint: StableFingerprint.fingerprint(data),
                includesPrivateNotes: includesPrivateNotes,
                includesOriginalSources: includesOriginalSources
            )
        } catch {
            exportURL = nil
            exportKind = nil
            errorMessage = "GradeDraft could not create the export. No file was shared. Could not fingerprint the exported file."
        }
    }

    private func appendExportRecord(kind: ExportKind, contentFingerprint: String, includesPrivateNotes: Bool, includesOriginalSources: Bool) {
        updateAssignment { assignment in
            assignment.exportRecords.append(
                ExportRecord(
                    exportKind: kind,
                    contentFingerprint: contentFingerprint,
                    includesPrivateTeacherNotes: includesPrivateNotes,
                    includesOriginalSources: includesOriginalSources
                )
            )
            assignment.appendAuditEvent(.exportPrepared, detail: "Prepared \(kind.rawValue). Includes private notes: \(includesPrivateNotes ? "yes" : "no"). Includes original sources: \(includesOriginalSources ? "yes" : "no").")
        }
        persistOrSurfaceError()
    }

    private func handleExportFailure(_ error: Error) {
        exportURL = nil
        exportKind = nil
        let detail = error.localizedDescription.replacingOccurrences(of: fileManager.temporaryDirectory.path, with: "[temporary directory]")
        errorMessage = "GradeDraft could not create the export. No file was shared. \(detail)"
    }

    private func upsertAssignment(_ updated: AssignmentRecord) {
        var updated = updated
        updated.updatedAt = Date()
        if let index = assignments.firstIndex(where: { $0.id == updated.id }) {
            assignments[index] = updated
        } else {
            assignments.insert(updated, at: 0)
        }
        assignments.sort { $0.updatedAt > $1.updatedAt }
    }

    private func persistOrSurfaceError() {
        do {
            try saveCurrentAssignment()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistSourceImages(_ images: [UIImage], sourceType: SourceType, assignmentID: UUID) throws -> [SourceInputRef] {
        let appDirectory = try store.applicationSupportDirectory()
        let sourceDirectory = appDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(assignmentID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: sourceDirectory.path) {
            try fileManager.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        }

        return try images.enumerated().map { index, image in
            guard let data = image.pngData() else {
                throw GradeDraftError.persistenceFailed("Could not serialize captured page \(index + 1).")
            }
            let filename = "page-\(index + 1)-\(UUID().uuidString).png"
            let url = sourceDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic])
            let relativePath = "Sources/\(assignmentID.uuidString)/\(filename)"
            return SourceInputRef(
                sourceType: sourceType,
                pageIndex: index,
                localRelativePath: relativePath,
                contentDigest: StableFingerprint.fingerprint(data),
                digestAlgorithm: "fnv1a64",
                imageWidth: Double(image.size.width),
                imageHeight: Double(image.size.height),
                teacherIncludedInExport: false
            )
        }
    }

    private func renderPDFPages(_ document: PDFDocument) throws -> [UIImage] {
        var images: [UIImage] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0
            let size = CGSize(width: max(bounds.width, 1) * scale, height: max(bounds.height, 1) * scale)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                context.cgContext.saveGState()
                context.cgContext.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()
            }
            images.append(image)
        }
        return images
    }

    private func extractDigitalPDFText(_ document: PDFDocument) -> [String] {
        (0..<document.pageCount).map { index in
            document.page(at: index)?.string ?? ""
        }
    }

    private func ocrDocumentFromDigitalPDFText(_ pageTexts: [String], sourceRefs: [SourceInputRef]) -> OCRDocument {
        let pages: [OCRPage] = pageTexts.enumerated().map { pageIndex, text in
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { lineIndex, lineText in
                    OCRLine(
                        text: lineText,
                        confidence: 1.0,
                        boundingBox: NormalizedRect(x: 0.02, y: CGFloat(lineIndex) * 0.035, width: 0.96, height: 0.03),
                        teacherConfirmed: false
                    )
                }
            return OCRPage(
                sourceInputID: pageIndex < sourceRefs.count ? sourceRefs[pageIndex].id : nil,
                pageIndex: pageIndex,
                imageWidth: sourceRefs[safe: pageIndex]?.imageWidth,
                imageHeight: sourceRefs[safe: pageIndex]?.imageHeight,
                lines: lines
            )
        }
        return OCRDocument(engine: "PDFKit digital text", engineVersion: "system", pages: pages)
    }

    private func readTextFile(_ url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .utf16) {
            return text
        }
        throw GradeDraftError.persistenceFailed("Could not read imported file as text.")
    }

    private func evidenceSourceReference(page: OCRPage, line: OCRLine, evidenceID: UUID? = nil) -> String {
        let sourceID = page.sourceInputID?.uuidString ?? "unknown-source"
        let box = line.boundingBox
        let evidencePart = evidenceID.map { "evidence:\($0.uuidString):" } ?? ""
        return "\(evidencePart)source:\(sourceID):page:\(page.pageIndex):ocrLine:\(line.id.uuidString):bbox:\(box.x),\(box.y),\(box.width),\(box.height)"
    }

    private func evidenceID(in sourceReference: String) -> UUID? {
        guard let range = sourceReference.range(of: #"evidence:([A-Fa-f0-9-]{36})"#, options: .regularExpression) else { return nil }
        let match = String(sourceReference[range])
        return UUID(uuidString: match.replacingOccurrences(of: "evidence:", with: ""))
    }

    private func temporaryExportURL(kind: ExportKind, extension ext: String, assignmentID: UUID? = nil) -> URL {
        let filename = ExportFilenameBuilder.filename(kind: kind, assignmentID: assignmentID ?? assignment.id, extension: ext)
        return fileManager.temporaryDirectory.appendingPathComponent(filename)
    }

    private func refreshAssignmentRosterEntries() {
        assignmentRosterEntries = assignments.enumerated().compactMap { index, record in
            guard let studentID = record.studentID else { return nil }
            return AssignmentRosterEntry(
                assignmentID: record.id,
                studentID: studentID,
                studentDisplayName: record.studentDisplayName,
                localIdentifier: students.first(where: { $0.id == studentID })?.localIdentifier ?? "",
                status: assignmentRosterStatus(for: record),
                sortOrder: index
            )
        }
    }

    private static func classGroupsFromAssignments(_ assignments: [AssignmentRecord]) -> [ClassGroupRecord] {
        var byName: [String: ClassGroupRecord] = [:]
        for record in assignments where !record.className.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let key = record.className.lowercased()
            if byName[key] == nil {
                byName[key] = ClassGroupRecord(name: record.className, subject: record.subject, gradeLevel: record.gradeLevel)
            }
        }
        return Array(byName.values).sorted { $0.name < $1.name }
    }

    private static func studentsFromAssignments(_ assignments: [AssignmentRecord]) -> [StudentRecord] {
        var byName: [String: StudentRecord] = [:]
        for record in assignments where !record.studentDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let key = [record.className, record.studentDisplayName].joined(separator: "|").lowercased()
            if byName[key] == nil {
                byName[key] = StudentRecord(displayName: record.studentDisplayName, className: record.className)
            }
        }
        return Array(byName.values).sorted { $0.displayName < $1.displayName }
    }
}

private enum CurriculumImportService {
    static func importableText(from url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        if url.pathExtension.lowercased() == "xlsx" {
            return try xlsxSharedText(from: url)
        }
        throw GradeDraftError.persistenceFailed("Could not read imported curriculum/reference file as text.")
    }

    private static func xlsxSharedText(from url: URL) throws -> String {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw GradeDraftError.persistenceFailed("Could not open local curriculum workbook as a ZIP-based XLSX file.")
        }
        var collected: [String] = []
        for entry in archive where entry.path.hasSuffix(".xml") {
            var data = Data()
            _ = try archive.extract(entry) { chunk in data.append(chunk) }
            guard let xml = String(data: data, encoding: .utf8) else { continue }
            let cleaned = xml
                .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
            collected.append(cleaned)
        }
        return collected.joined(separator: "\n")
    }

    static func summary(from text: String, sourceName: String) -> String {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let codePattern = #"\b[A-Z]{2,}[A-Z0-9]{3,}\b"#
        let codes = lines.flatMap { line -> [String] in
            guard let regex = try? NSRegularExpression(pattern: codePattern) else { return [] }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            return regex.matches(in: line, range: range).compactMap { match in
                Range(match.range, in: line).map { String(line[$0]) }
            }
        }
        let excerpts = lines.prefix(20).joined(separator: "\n")
        return """
        Source: \(sourceName)
        Import status: Teacher-provided local curriculum/reference material. Confirm against the official jurisdiction source before reporting.
        Detected codes: \(Array(Set(codes)).sorted().joined(separator: ", "))

        Excerpts:
        \(excerpts)
        """
    }
}


private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
