import Foundation
import PDFKit
import UIKit
import ZIPFoundation

@MainActor
extension GradeDraftViewModel {
    func applyTemplate(_ template: RubricTemplate) {
        guard currentSavedAssignmentForAction("Rubric template application") != nil else { return }
        updateAssignment { assignment in
            assignment = GradeDraftTemplateApplication.applyingRubricTemplate(template, to: assignment, resetDrafts: true)
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Rubric template applied locally. Review before drafting feedback."
    }

    func applyTeacherInstructionTemplate(_ template: TeacherInstructionTemplate, mode: TemplateInsertionMode = .append) {
        guard currentSavedAssignmentForAction("Teacher instruction template application") != nil else { return }
        updateAssignment { assignment in
            assignment = GradeDraftTemplateApplication.appendingInstructionTemplate(template, to: assignment, mode: mode)
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Teacher instruction template appended locally."
    }

    func applyAnswerKeyTemplate(_ template: AnswerKeyTemplate, mode: TemplateInsertionMode = .append) {
        guard currentSavedAssignmentForAction("Answer-key template application") != nil else { return }
        updateAssignment { assignment in
            assignment = GradeDraftTemplateApplication.insertingAnswerKeyTemplate(template, to: assignment, mode: mode)
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Answer-key template inserted locally. Existing answer-key text was preserved."
    }

    func applyExemplarTemplate(_ template: ExemplarTemplate, mode: TemplateInsertionMode = .append) {
        guard currentSavedAssignmentForAction("Exemplar template application") != nil else { return }
        updateAssignment { assignment in
            assignment = GradeDraftTemplateApplication.insertingExemplarTemplate(template, to: assignment, mode: mode)
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Exemplar template inserted locally. Existing exemplar text was preserved."
    }

    func applyFormativeFocusTemplate(_ template: FormativeFocusTemplate, mode: TemplateInsertionMode = .append) {
        guard currentSavedAssignmentForAction("Formative focus template application") != nil else { return }
        updateAssignment { assignment in
            assignment = GradeDraftTemplateApplication.insertingFormativeFocusTemplate(template, to: assignment, mode: mode)
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Formative focus template appended locally."
    }

    func toggleAIConstraintTemplate(_ templateID: String) {
        guard currentSavedAssignmentForAction("AI constraint template selection") != nil else { return }
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
        guard persistOrSurfaceError() else { return }
        statusMessage = "AI constraint templates updated. Regenerate any outdated draft before final review."
    }

    func applyRecommendedAIConstraintTemplates() {
        guard currentSavedAssignmentForAction("Recommended AI constraint template application") != nil else { return }
        updateAssignment { assignment in
            assignment.selectedInstructionTemplateIDs = GradingConstraintTemplates.recommendedIDs(for: assignment)
            assignment.appendAuditEvent(.inputChanged, detail: "Recommended AI constraint templates applied.")
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Recommended AI constraint templates applied. Sensitive templates were not selected automatically."
    }

    func clearAIConstraintTemplates() {
        guard currentSavedAssignmentForAction("Clear AI constraint templates") != nil else { return }
        updateAssignment { assignment in
            assignment.selectedInstructionTemplateIDs = []
            assignment.appendAuditEvent(.inputChanged, detail: "AI constraint templates cleared.")
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "AI constraint templates cleared."
    }

    func applyPastedStudentText(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            errorMessage = "Paste non-empty student work before saving it as reviewed input."
            return false
        }
        guard currentSavedAssignmentForAction("Paste student work") != nil else { return false }
        updateAssignment { assignment in
            assignment.reviewedStudentText = cleaned
            assignment.ocrDocument = nil
            assignment.ocrReviewStatus = .notNeeded
            assignment.ocrReviewedAt = nil
            assignment.sourceInputs = [SourceInputRef(sourceType: .pastedText, contentDigest: StableFingerprint.fingerprint([cleaned]), digestAlgorithm: "fnv1a64")]
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Pasted student text applied as teacher-reviewed input.")
        }
        guard persistOrSurfaceError() else { return false }
        statusMessage = "Pasted student work saved locally as teacher-reviewed input."
        return true
    }

    func clearCurrentStudentWork() {
        guard let currentAssignment = currentSavedAssignmentForAction("Clear student work") else { return }
        let assignmentID = currentAssignment.id
        let hadSourceInputs = !currentAssignment.sourceInputs.isEmpty
        updateAssignment { assignment in
            assignment.ocrDocument = nil
            assignment.ocrReviewStatus = .notNeeded
            assignment.ocrReviewedAt = nil
            assignment.sourceInputs = []
            assignment.reviewedStudentText = ""
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Teacher cleared student work and reviewed text after the local clear-work warning.")
        }
        guard persistOrSurfaceError() else { return }
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
        if let cleanupErrorDetail {
            errorMessage = "Student work references were cleared, but local source files may remain: \(cleanupErrorDetail)"
        } else {
            statusMessage = "Student work cleared locally."
        }
    }

    func exportStudentReport() {
        guard let currentAssignment = currentSavedAssignmentForAction("Student Markdown report export") else { return }
        guard currentAssignment.isStudentFacingExportReady else {
            errorMessage = "Student-facing export is blocked until the teacher approves the final grade."
            return
        }

        do {
            let markdown = MarkdownReportBuilder.studentMarkdown(for: currentAssignment)
            let url = try MarkdownReportBuilder.writeTemporaryStudentReport(for: currentAssignment)
            guard recordExport(kind: .studentMarkdown, content: markdown, includesPrivateNotes: false, includesOriginalSources: false) else { return }
            publishPreparedExport(url, kind: .studentMarkdown, assignmentID: currentAssignment.id)
            statusMessage = "Student Markdown report is ready to share."
        } catch {
            handleExportFailure(error)
        }
    }

    func classAssignments(for className: String) -> [AssignmentRecord] {
        assignments
            .filter { $0.className.caseInsensitiveCompare(className) == .orderedSame }
            .sorted { $0.studentDisplayName.localizedCaseInsensitiveCompare($1.studentDisplayName) == .orderedAscending }
    }

    func nextUngradedAssignment(in className: String) -> AssignmentRecord? {
        classAssignments(for: className).first { record in
            record.finalReview?.status != .approved || record.finalReviewIsStale
        }
    }

    func previewMarkdownRubric(_ text: String) -> RubricImportPreview {
        let preview = MarkdownRubricParser.preview(text)
        guard let currentAssignment = currentSavedAssignmentForAction("Markdown rubric preview") else { return preview }
        latestRubricPreview = preview
        rubricPreviewsByAssignmentID[currentAssignment.id] = preview
        return preview
    }

    func confirmMarkdownRubricImport(_ preview: RubricImportPreview, for assignmentID: UUID? = nil, useStructuredImport: Bool = true) {
        guard let currentAssignment = currentSavedAssignmentForAction("Markdown rubric import") else { return }
        let targetID = assignmentID ?? currentAssignment.id
        guard targetID == currentAssignment.id else {
            errorMessage = "Rubric import was not saved because the selected assignment changed. Reopen the target assignment and import again."
            return
        }
        guard rubricPreviewsByAssignmentID[targetID] == preview else {
            errorMessage = "Rubric import was not saved because the preview no longer belongs to this assignment. Preview the rubric again before confirming."
            return
        }
        updateAssignment { assignment in
            assignment.rubricText = preview.rawMarkdown
            if useStructuredImport {
                assignment.rubricImportMode = .structuredConfirmed
                assignment.confirmedParsedRubric = preview.parsedRubric
            } else {
                assignment.rubricImportMode = .rawTextOnly
                assignment.confirmedParsedRubric = nil
            }
            let criterionCount = useStructuredImport ? preview.detectedCriteria.count : 0
            assignment.appendAuditEvent(.inputChanged, detail: "Confirmed rubric import with \(criterionCount) structured criterion/criteria and \(preview.issues.count) item(s) needing attention.")
        }
        guard persistOrSurfaceError() else { return }
        rubricPreviewsByAssignmentID[targetID] = nil
        latestRubricPreview = nil
        statusMessage = useStructuredImport ? "Rubric imported with a teacher-confirmed structured preview." : "Rubric text saved as raw text for teacher review."
    }

    func updateRubricText(_ text: String) {
        guard currentSavedAssignmentForAction("Rubric text update") != nil else { return }
        updateAssignment { assignment in
            assignment.rubricText = text
            assignment.rubricImportMode = .automatic
            assignment.confirmedParsedRubric = nil
        }
        persistOrSurfaceError()
    }

    func importMarkdownRubric(from url: URL) {
        guard currentSavedAssignmentForAction("Markdown rubric import") != nil else { return }
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

    func clearCurriculumFilters() {
        curriculumSearchText = ""
        curriculumCatalogKindFilter = ""
        curriculumSubjectFilter = ""
        curriculumLearningAreaFilter = ""
        curriculumYearLevelFilter = ""
        curriculumResultLimit = 50
    }

    func loadMoreCurriculumResults() {
        curriculumResultLimit += 50
    }

    func mapCurriculumItemToCurrentAssignment(_ item: CurriculumItem, mappingKind: String = "assignment") {
        guard item.isOfficial || !item.isEditable else { return }
        guard currentSavedAssignmentForAction("Curriculum reference mapping") != nil else { return }
        updateAssignment { assignment in
            if !assignment.curriculumMappings.contains(where: { $0.curriculumItemID == item.id && $0.mappingKind == mappingKind && $0.teacherSelected }) {
                assignment.curriculumMappings.append(CurriculumMapping(curriculumItemID: item.id, mappingKind: mappingKind, teacherSelected: true))
            }
            let selectedItems = assignment.curriculumMappings
                .filter { $0.teacherSelected }
                .compactMap { CurriculumCatalogService.item(id: $0.curriculumItemID, in: curriculumCatalog) }
            assignment.curriculumReference = CurriculumCatalogService.selectedReferenceSummary(items: selectedItems, catalog: curriculumCatalog)
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Teacher mapped Australian Curriculum reference \(item.code) to assignment from \(item.sourceVersion).")
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Mapped Australian Curriculum reference locally. Confirm jurisdiction reporting requirements before final reporting."
    }

    func unmapCurriculumItemFromCurrentAssignment(_ item: CurriculumItem) {
        guard currentSavedAssignmentForAction("Curriculum reference removal") != nil else { return }
        updateAssignment { assignment in
            assignment.curriculumMappings.removeAll { $0.curriculumItemID == item.id }
            let selectedItems = assignment.curriculumMappings
                .filter { $0.teacherSelected }
                .compactMap { CurriculumCatalogService.item(id: $0.curriculumItemID, in: curriculumCatalog) }
            assignment.curriculumReference = CurriculumCatalogService.selectedReferenceSummary(items: selectedItems, catalog: curriculumCatalog)
            assignment.latestDraft = nil
            assignment.finalReview = nil
            assignment.appendAuditEvent(.inputChanged, detail: "Teacher removed Australian Curriculum reference \(item.code) from assignment.")
        }
        guard persistOrSurfaceError() else { return }
        statusMessage = "Curriculum reference removed from the current assignment."
    }

    func importCurriculumReference(from url: URL) {
        guard currentSavedAssignmentForAction("Curriculum reference import") != nil else { return }
        do {
            let text = try Self.importableText(from: url)
            let summary = Self.summary(from: text, sourceName: url.lastPathComponent)
            updateAssignment { assignment in
                assignment.curriculumReference = summary
                assignment.latestDraft = nil
                assignment.finalReview = nil
                assignment.curriculumMappings.removeAll()
                assignment.appendAuditEvent(.inputChanged, detail: "Imported teacher-provided curriculum/reference material from \(url.lastPathComponent).")
            }
            guard persistOrSurfaceError() else { return }
            statusMessage = "Teacher-provided curriculum/reference material imported locally. Confirm it matches the current jurisdiction source before grading."
        } catch {
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func previewRosterCSV(_ text: String, className: String? = nil) -> RosterImportPreview {
        guard let currentAssignment = currentSavedAssignmentForAction("Roster preview") else {
            return RosterImportService.preview(csvText: text, defaultClassName: className)
        }
        let defaultClassName = currentAssignment.className
        let preview = RosterImportService.preview(csvText: text, defaultClassName: className ?? defaultClassName)
        latestRosterPreview = preview
        return preview
    }

    func saveClassGroup(_ classGroup: ClassGroupRecord) {
        var nextClassGroups = classGroups
        if let index = nextClassGroups.firstIndex(where: { $0.id == classGroup.id }) {
            nextClassGroups[index] = classGroup
        } else {
            nextClassGroups.append(classGroup)
        }
        do {
            try store.replaceLocalDataSnapshot(currentStoreSnapshot(classGroups: nextClassGroups))
            classGroups = nextClassGroups
            statusMessage = "Class saved locally."
        } catch {
            reloadFromStoreAfterPersistenceFailure()
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func saveStudent(_ student: StudentRecord) {
        var nextStudents = students
        if let index = nextStudents.firstIndex(where: { $0.id == student.id }) {
            nextStudents[index] = student
        } else {
            nextStudents.append(student)
        }
        do {
            try store.replaceLocalDataSnapshot(currentStoreSnapshot(students: nextStudents))
            students = nextStudents
            reconcileRosterEntriesWithCurrentAssignments()
            statusMessage = "Student saved locally."
        } catch {
            reloadFromStoreAfterPersistenceFailure()
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func deleteClassGroup(id: UUID) {
        let nextClassGroups = classGroups.filter { $0.id != id }
        do {
            try store.replaceLocalDataSnapshot(currentStoreSnapshot(classGroups: nextClassGroups))
            classGroups = nextClassGroups
            statusMessage = "Class archived/deleted locally. Existing assignment records are preserved."
        } catch {
            reloadFromStoreAfterPersistenceFailure()
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func deleteStudent(id: UUID) {
        let nextStudents = students.filter { $0.id != id }
        let nextRosterEntries = assignmentRosterEntries.filter { $0.studentID != id }
        do {
            try store.replaceLocalDataSnapshot(currentStoreSnapshot(students: nextStudents, rosterEntries: nextRosterEntries))
            students = nextStudents
            assignmentRosterEntries = nextRosterEntries
            statusMessage = "Student record deleted locally. Existing assignment records are preserved for audit continuity."
        } catch {
            reloadFromStoreAfterPersistenceFailure()
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func createAssignmentsFromRosterCSV(_ text: String, className: String? = nil) {
        guard let currentAssignment = currentSavedAssignmentForAction("Roster assignment creation") else { return }
        let preview = previewRosterCSV(text, className: className ?? currentAssignment.className)
        guard !preview.students.isEmpty else {
            errorMessage = preview.rejectedRows.first ?? "Paste at least one valid student row."
            return
        }

        let resolvedClassName = preview.className.nilIfBlank
            ?? className?.nilIfBlank
            ?? currentAssignment.className.nilIfBlank
            ?? "Untitled class"
        var classGroup = classGroups.first { $0.name.localizedCaseInsensitiveCompare(resolvedClassName) == .orderedSame }
            ?? ClassGroupRecord(
                name: resolvedClassName,
                schoolYear: "",
                term: "",
                subject: currentAssignment.subject,
                gradeLevel: currentAssignment.gradeLevel
            )
        classGroup.updatedAt = Date()

        var nextClassGroups = classGroups
        if let index = nextClassGroups.firstIndex(where: { $0.id == classGroup.id }) {
            nextClassGroups[index] = classGroup
        } else {
            nextClassGroups.append(classGroup)
        }

        var nextStudents = students
        let template = currentAssignment
        var created: [AssignmentRecord] = []
        var rosterEntries: [AssignmentRosterEntry] = []

        for (index, student) in preview.students.enumerated() {
            var savedStudent = student
            if let existing = nextStudents.first(where: { !$0.localIdentifier.isEmpty && $0.localIdentifier == student.localIdentifier }) {
                savedStudent = existing
            } else {
                savedStudent.className = savedStudent.className.nilIfBlank ?? classGroup.name
                nextStudents.append(savedStudent)
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

        var nextAssignments = assignments + created
        nextAssignments.sort { $0.updatedAt > $1.updatedAt }
        let nextRosterEntries = reconciledRosterEntries(
            assignmentRosterEntries + rosterEntries,
            assignments: nextAssignments,
            students: nextStudents
        )
        do {
            try store.replaceLocalDataSnapshot(
                AssignmentStoreSnapshot(
                    assignments: nextAssignments,
                    classGroups: nextClassGroups,
                    students: nextStudents,
                    rosterEntries: nextRosterEntries
                )
            )
            assignments = nextAssignments
            classGroups = nextClassGroups
            students = nextStudents
            assignmentRosterEntries = nextRosterEntries
            selectedAssignmentID = created.first?.id ?? selectedAssignmentID
            statusMessage = "Created \(created.count) roster assignment(s) locally; \(preview.rejectedRows.count) invalid row(s) were rejected."
        } catch {
            reloadFromStoreAfterPersistenceFailure()
            errorMessage = GradeDraftError.persistenceFailed(error.localizedDescription).localizedDescription
        }
    }

    func remappedRestoredRosterEntries(
        _ restored: [AssignmentRosterEntry],
        assignmentIDMap: [UUID: UUID],
        conflictResolution: BackupConflictResolution,
        localConflictAssignmentIDs: Set<UUID>,
        assignmentsForStatus: [AssignmentRecord]
    ) -> [AssignmentRosterEntry] {
        restored.compactMap { entry in
            if conflictResolution == .keepLocal, localConflictAssignmentIDs.contains(entry.assignmentID) {
                return nil
            }
            var copy = entry
            if let remappedID = assignmentIDMap[entry.assignmentID] {
                copy.id = UUID()
                copy.assignmentID = remappedID
                copy.updatedAt = Date()
            }
            if let matched = assignmentsForStatus.first(where: { $0.id == copy.assignmentID }) {
                copy.status = assignmentRosterStatus(for: matched)
            }
            return copy
        }
    }

    func mergeRestoredClassGroups(_ restored: [ClassGroupRecord]) {
        guard !restored.isEmpty else { return }
        var byID = Dictionary(uniqueKeysWithValues: classGroups.map { ($0.id, $0) })
        for record in restored {
            if byID[record.id] == nil || backupConflictResolution == .replaceLocal {
                byID[record.id] = record
            }
        }
        classGroups = Array(byID.values).sorted { $0.name < $1.name }
    }

    func mergeRestoredStudents(_ restored: [StudentRecord]) {
        guard !restored.isEmpty else { return }
        var byID = Dictionary(uniqueKeysWithValues: students.map { ($0.id, $0) })
        for record in restored {
            if byID[record.id] == nil || backupConflictResolution == .replaceLocal {
                byID[record.id] = record
            }
        }
        students = Array(byID.values).sorted { $0.displayName < $1.displayName }
    }

    func mergeRestoredRosterEntries(_ restored: [AssignmentRosterEntry]) {
        guard !restored.isEmpty else { return }
        var byID = Dictionary(uniqueKeysWithValues: assignmentRosterEntries.map { ($0.id, $0) })
        for entry in restored {
            if byID[entry.id] == nil || backupConflictResolution == .replaceLocal {
                byID[entry.id] = entry
            }
        }
        assignmentRosterEntries = Array(byID.values).sorted { $0.sortOrder < $1.sortOrder }
    }

    func mergeRestoredRosterEntries(_ restored: [AssignmentRosterEntry], assignmentIDMap: [UUID: UUID], conflictResolution: BackupConflictResolution) {
        let localConflictIDs = Set(assignmentIDMap.keys)
        let remapped = remappedRestoredRosterEntries(
            restored,
            assignmentIDMap: assignmentIDMap,
            conflictResolution: conflictResolution,
            localConflictAssignmentIDs: localConflictIDs,
            assignmentsForStatus: assignments
        )
        guard !remapped.isEmpty else { return }
        var byID = Dictionary(uniqueKeysWithValues: assignmentRosterEntries.map { ($0.id, $0) })
        for entry in remapped {
            if byID[entry.id] == nil || conflictResolution == .replaceLocal {
                byID[entry.id] = entry
            }
        }
        assignmentRosterEntries = Array(byID.values).sorted { $0.sortOrder < $1.sortOrder }
    }

    func exportStudentPDF() {
        guard let currentAssignment = currentSavedAssignmentForAction("Student Report PDF export") else { return }
        guard currentAssignment.isStudentFacingExportReady else {
            errorMessage = "Student-facing export is blocked until the teacher approves the final grade."
            return
        }
        do {
            let destination = temporaryExportURL(kind: .studentPDF, extension: "pdf", assignmentID: currentAssignment.id)
            let url = try PDFExportService.studentReportPDF(for: currentAssignment, destination: destination)
            guard recordExport(kind: .studentPDF, fileURL: url, includesPrivateNotes: false, includesOriginalSources: false) else { return }
            publishPreparedExport(url, kind: .studentPDF, assignmentID: currentAssignment.id)
            statusMessage = "Student Report PDF is ready to share."
        } catch {
            handleExportFailure(error)
        }
    }

    func refreshAssignmentRosterEntries() {
        assignmentRosterEntries = generatedRosterEntries(assignments: assignments, students: students)
    }

    func reconcileRosterEntriesWithCurrentAssignments() {
        assignmentRosterEntries = reconciledRosterEntries(assignmentRosterEntries, assignments: assignments, students: students)
    }

    func generatedRosterEntries(assignments: [AssignmentRecord], students: [StudentRecord]) -> [AssignmentRosterEntry] {
        assignments.enumerated().compactMap { index, record in
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

    func reconciledRosterEntries(
        _ candidates: [AssignmentRosterEntry],
        assignments: [AssignmentRecord],
        students: [StudentRecord]
    ) -> [AssignmentRosterEntry] {
        let assignmentsByID = Dictionary(uniqueKeysWithValues: assignments.map { ($0.id, $0) })
        let studentsByID = Dictionary(uniqueKeysWithValues: students.map { ($0.id, $0) })
        let assignmentOrder = Dictionary(uniqueKeysWithValues: assignments.enumerated().map { ($0.element.id, $0.offset) })
        var byAssignmentAndStudent: [String: AssignmentRosterEntry] = [:]

        for candidate in candidates {
            guard let record = assignmentsByID[candidate.assignmentID],
                  let studentID = record.studentID,
                  studentsByID[studentID] != nil else { continue }
            let key = "\(record.id.uuidString)|\(studentID.uuidString)"
            guard byAssignmentAndStudent[key] == nil else { continue }
            var entry = candidate
            entry.assignmentID = record.id
            entry.studentID = studentID
            entry.studentDisplayName = record.studentDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? candidate.studentDisplayName : record.studentDisplayName
            entry.localIdentifier = studentsByID[studentID]?.localIdentifier ?? candidate.localIdentifier
            entry.status = assignmentRosterStatus(for: record)
            entry.sortOrder = assignmentOrder[record.id] ?? candidate.sortOrder
            entry.updatedAt = Date()
            byAssignmentAndStudent[key] = entry
        }

        for (index, record) in assignments.enumerated() {
            guard let studentID = record.studentID,
                  studentsByID[studentID] != nil else { continue }
            let key = "\(record.id.uuidString)|\(studentID.uuidString)"
            if byAssignmentAndStudent[key] == nil {
                byAssignmentAndStudent[key] = AssignmentRosterEntry(
                    assignmentID: record.id,
                    studentID: studentID,
                    studentDisplayName: record.studentDisplayName,
                    localIdentifier: studentsByID[studentID]?.localIdentifier ?? "",
                    status: assignmentRosterStatus(for: record),
                    sortOrder: index
                )
            }
        }

        return byAssignmentAndStudent.values.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.studentDisplayName.localizedCaseInsensitiveCompare(rhs.studentDisplayName) == .orderedAscending
        }
    }

    func mergedClassGroups(local: [ClassGroupRecord], restored: [ClassGroupRecord]) -> [ClassGroupRecord] {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for record in restored where byID[record.id] == nil {
            byID[record.id] = record
        }
        return Array(byID.values).sorted { $0.name < $1.name }
    }

    func mergedStudents(local: [StudentRecord], restored: [StudentRecord]) -> [StudentRecord] {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for record in restored where byID[record.id] == nil {
            byID[record.id] = record
        }
        return Array(byID.values).sorted { $0.displayName < $1.displayName }
    }

    static func classGroupsFromAssignments(_ assignments: [AssignmentRecord]) -> [ClassGroupRecord] {
        var byName: [String: ClassGroupRecord] = [:]
        for record in assignments where !record.className.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let key = record.className.lowercased()
            if byName[key] == nil {
                byName[key] = ClassGroupRecord(name: record.className, subject: record.subject, gradeLevel: record.gradeLevel)
            }
        }
        return Array(byName.values).sorted { $0.name < $1.name }
    }

    static func studentsFromAssignments(_ assignments: [AssignmentRecord]) -> [StudentRecord] {
        var byName: [String: StudentRecord] = [:]
        for record in assignments where !record.studentDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let key = [record.className, record.studentDisplayName].joined(separator: "|").lowercased()
            if byName[key] == nil {
                byName[key] = StudentRecord(id: record.studentID ?? UUID(), displayName: record.studentDisplayName, className: record.className)
            }
        }
        return Array(byName.values).sorted { $0.displayName < $1.displayName }
    }
}
