import Foundation
import Observation
import SwiftUI

/// One assignment's setup (rubric, instructions, templates, curriculum references), for one routed
/// screen. Field edits change the local copy and are autosaved; template, rubric-import, suggestion
/// and mapping actions save at once. When the assignment no longer exists, `isMissing` becomes true and
/// every action does nothing.
@Observable @MainActor
final class AssignmentSetupModel {
    let assignmentID: UUID

    /// The setup as the teacher is editing it.
    private(set) var setup: AssignmentSetup?
    private(set) var isMissing = false
    var alert: AlertMessage?

    /// A Markdown rubric read from pasted text or a file, waiting for the teacher's confirmation.
    private(set) var rubricPreview: RubricImportPreview?
    /// Criteria the on-device model suggested from plain text, waiting for the teacher's confirmation
    /// ("Suggested by on-device AI — check before confirming"). Not saved until confirmed.
    private(set) var suggestedRubric: ParsedRubric?
    private(set) var isSuggestingRubric = false
    private(set) var isSuggestingCurriculum = false
    /// Catalogue details for the mapped curriculum references, keyed by item ID.
    private(set) var mappedItems: [String: CurriculumItem] = [:]
    private(set) var preparedExport: PreparedExport?
    /// File name of the last curriculum/reference file saved as this assignment's curriculum reference.
    private(set) var lastCurriculumImportFileName: String?

    @ObservationIgnored let app: AppModel
    @ObservationIgnored private(set) lazy var autosave = AutosaveScheduler { [weak self] in
        await self?.saveSetup()
    }
    @ObservationIgnored private var storedSetup: AssignmentSetup?

    init(assignmentID: UUID, app: AppModel) {
        self.assignmentID = assignmentID
        self.app = app
    }

    var hasLoaded: Bool { setup != nil }

    var className: String {
        setup.map { app.className(for: $0.assignment.classGroupID) } ?? ""
    }

    var localAIStatus: LocalAIStatus { app.services.grading.localAIStatus }

    /// The AI rubric suggestion is offered only when the Markdown reader finds no criteria in the rubric text.
    var canSuggestRubric: Bool {
        guard let setup else { return false }
        return setup.parsedRubric.criteria.isEmpty
            && !setup.assignment.rubricText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The submissions under this assignment, in roster order.
    var submissions: [SubmissionSummary] {
        app.submissionSummaries.filter { $0.assignmentID == assignmentID }
    }

    // MARK: - Observation

    func observe() async {
        let database: AppDatabase
        do {
            database = try app.requireDatabase()
        } catch {
            alert = AlertMessage(title: "Assignment could not be opened", error: error)
            return
        }
        do {
            for try await value in database.observeAssignment(id: assignmentID) {
                guard let value else {
                    isMissing = true
                    autosave.discardPending()
                    finishSharing()
                    continue
                }
                let mappingsChanged = storedSetup?.curriculumMappings.map(\.curriculumItemID) != value.curriculumMappings.map(\.curriculumItemID)
                storedSetup = value
                if !autosave.holdsLocalEdits { setup = value }
                if mappingsChanged { await loadMappedItems(value) }
            }
        } catch is CancellationError {
        } catch {
            alert = AlertMessage(title: "Assignment could not be read", error: error)
        }
    }

    private func loadMappedItems(_ setup: AssignmentSetup) async {
        do {
            let items = try await app.services.curriculumCatalog.items(ids: setup.curriculumMappings.map(\.curriculumItemID))
            mappedItems = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            alert = AlertMessage(title: "Curriculum references could not be read", error: error)
        }
    }

    // MARK: - Editing (autosaved)

    /// A binding to one text field of the assignment. Edits autosave 0.6 s after the last keystroke.
    func text(_ keyPath: WritableKeyPath<Assignment, String> & Sendable) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.setup?.assignment[keyPath: keyPath] ?? "" },
            set: { [weak self] value in self?.edit { $0.assignment[keyPath: keyPath] = value } }
        )
    }

    /// Any other edit to the setup (assignment type, purpose, rubric text, constraint templates). Autosaved.
    /// Editing the rubric text returns the rubric to automatic reading (a confirmed structure no longer applies).
    func edit(_ change: (inout AssignmentSetup) -> Void) {
        guard !isMissing, let current = setup else { return }
        var edited = current
        change(&edited)
        if edited.assignment.rubricText != current.assignment.rubricText {
            edited.assignment.rubricImportMode = .automatic
            edited.assignment.confirmedRubric = nil
        }
        guard edited != current else { return }
        setup = edited
        autosave.schedule()
    }

    func toggleConstraintTemplate(_ templateID: String) {
        edit { setup in
            if setup.assignment.constraintTemplateIDs.contains(templateID) {
                setup.assignment.constraintTemplateIDs.removeAll { $0 == templateID }
            } else {
                setup.assignment.constraintTemplateIDs.append(templateID)
            }
        }
    }

    private func saveSetup() async {
        guard !isMissing, var setup else { return }
        setup.assignment.updatedAt = Date()
        do {
            try await app.requireDatabase().saveSetup(setup)
        } catch {
            alert = AlertMessage(title: "Assignment not saved", error: error)
            autosave.discardPending()
            self.setup = storedSetup
        }
    }

    /// Saves pending edits now (screen disappears, app goes to the background).
    func flushPendingEdits() async {
        await autosave.flushNow()
    }

    /// Saves a setup change at once, with an assignment-level audit event.
    private func saveNow(_ updated: AssignmentSetup, action: String, auditDetail: String?) async {
        guard !isMissing else { return }
        autosave.discardPending()
        var updated = updated
        updated.assignment.updatedAt = Date()
        setup = updated
        do {
            let database = try app.requireDatabase()
            try await database.saveSetup(updated)
            if let auditDetail {
                try await database.appendAudit(AuditEvent(
                    assignmentID: assignmentID, submissionID: nil, eventType: .inputChanged, detail: auditDetail
                ))
            }
        } catch {
            alert = AlertMessage(title: action, error: error)
            setup = storedSetup
        }
    }

    /// The setup including any pending edits, after flushing them; nil when missing or not loaded.
    private func currentSetup() async -> AssignmentSetup? {
        await autosave.flushNow()
        guard !isMissing else { return nil }
        return setup
    }

    // MARK: - Templates (each appends an `.inputChanged` audit event)

    func applyRubricTemplate(_ template: RubricTemplate) async {
        guard let current = await currentSetup() else { return }
        await saveNow(GradeDraftTemplateApplication.applyingRubricTemplate(template, to: current),
                      action: "Template not applied", auditDetail: "Rubric template \"\(template.name)\" applied.")
    }

    func applyInstructionTemplate(_ template: TeacherInstructionTemplate, mode: TemplateInsertionMode = .append) async {
        guard let current = await currentSetup() else { return }
        await applyTemplate(GradeDraftTemplateApplication.appendingInstructionTemplate(template, to: current, mode: mode),
                            from: current, name: template.name)
    }

    func applyAnswerKeyTemplate(_ template: AnswerKeyTemplate, mode: TemplateInsertionMode = .append) async {
        guard let current = await currentSetup() else { return }
        await applyTemplate(GradeDraftTemplateApplication.insertingAnswerKeyTemplate(template, to: current, mode: mode),
                            from: current, name: template.name)
    }

    func applyExemplarTemplate(_ template: ExemplarTemplate, mode: TemplateInsertionMode = .append) async {
        guard let current = await currentSetup() else { return }
        await applyTemplate(GradeDraftTemplateApplication.insertingExemplarTemplate(template, to: current, mode: mode),
                            from: current, name: template.name)
    }

    func applyFormativeFocusTemplate(_ template: FormativeFocusTemplate, mode: TemplateInsertionMode = .append) async {
        guard let current = await currentSetup() else { return }
        await applyTemplate(GradeDraftTemplateApplication.insertingFormativeFocusTemplate(template, to: current, mode: mode),
                            from: current, name: template.name)
    }

    /// A template already present is not inserted again (unless "append again"); nothing is saved then.
    private func applyTemplate(_ updated: AssignmentSetup, from current: AssignmentSetup, name: String) async {
        guard updated != current else { return }
        await saveNow(updated, action: "Template not applied", auditDetail: "Template \"\(name)\" inserted.")
    }

    // MARK: - Rubric import

    func previewRubric(text: String) {
        guard !isMissing else { return }
        rubricPreview = MarkdownRubricParser.preview(text)
    }

    func importRubricFile(at url: URL) {
        guard !isMissing else { return }
        do {
            rubricPreview = MarkdownRubricParser.preview(try TextFileReader.read(url))
        } catch {
            alert = AlertMessage(title: "Rubric file not read", error: error)
        }
    }

    /// Saves the previewed rubric: as teacher-confirmed structured criteria, or as raw text only.
    func confirmRubricPreview(structured: Bool) async {
        guard let preview = rubricPreview, var updated = await currentSetup() else { return }
        updated.assignment.rubricText = preview.rawMarkdown
        updated.assignment.rubricImportMode = structured ? .structuredConfirmed : .rawTextOnly
        updated.assignment.confirmedRubric = structured ? preview.parsedRubric : nil
        let count = structured ? preview.detectedCriteria.count : 0
        await saveNow(updated, action: "Rubric not saved",
                      auditDetail: "Rubric import confirmed with \(count) structured criterion/criteria and \(preview.issues.count) item(s) needing attention.")
        if alert == nil { rubricPreview = nil }
    }

    func discardRubricPreview() {
        rubricPreview = nil
    }

    // MARK: - On-device AI suggestions

    /// Asks the on-device model for criteria from the plain-text rubric. The result is only shown until
    /// the teacher confirms or discards it.
    func suggestRubricCriteria() async {
        guard let current = await currentSetup(), canSuggestRubric, !isSuggestingRubric else { return }
        if case .unavailable(let message) = localAIStatus {
            alert = AlertMessage(title: "No suggestion", message: message)
            return
        }
        isSuggestingRubric = true
        defer { isSuggestingRubric = false }
        do {
            suggestedRubric = try await app.services.rubricSuggestions.suggest(fromPlainText: current.assignment.rubricText)
        } catch {
            alert = AlertMessage(title: "No suggestion", error: error)
        }
    }

    func confirmSuggestedRubric() async {
        guard let suggestion = suggestedRubric, var updated = await currentSetup() else { return }
        updated.assignment.rubricImportMode = .structuredConfirmed
        updated.assignment.confirmedRubric = suggestion
        await saveNow(updated, action: "Rubric not saved",
                      auditDetail: "Teacher confirmed \(suggestion.criteria.count) rubric criterion/criteria suggested by the on-device model.")
        if alert == nil { suggestedRubric = nil }
    }

    func discardSuggestedRubric() {
        suggestedRubric = nil
    }

    /// Asks the on-device model for up to five catalogue references. Each is saved as a suggested,
    /// unconfirmed mapping until the teacher confirms it.
    func suggestCurriculumReferences() async {
        guard let current = await currentSetup(), !isSuggestingCurriculum else { return }
        if case .unavailable(let message) = localAIStatus {
            alert = AlertMessage(title: "No suggestion", message: message)
            return
        }
        isSuggestingCurriculum = true
        defer { isSuggestingCurriculum = false }
        do {
            let itemIDs = try await app.services.curriculumSuggestions.suggest(for: current)
            let mapped = Set(current.curriculumMappings.map(\.curriculumItemID))
            let newMappings = CurriculumSuggestionService.unconfirmedMappings(
                itemIDs: itemIDs.filter { !mapped.contains($0) }, assignmentID: assignmentID
            )
            guard !newMappings.isEmpty else {
                alert = AlertMessage(title: "No new suggestions", message: "The on-device model found no further matching curriculum references.")
                return
            }
            var updated = current
            updated.curriculumMappings += newMappings
            await saveNow(updated, action: "Suggestions not saved", auditDetail: nil)
        } catch {
            alert = AlertMessage(title: "No suggestion", error: error)
        }
    }

    // MARK: - Curriculum mappings

    /// Adds a reference the teacher chose in the curriculum browser (teacher-confirmed).
    func addMapping(itemID: String) async {
        guard var updated = await currentSetup(),
              !updated.curriculumMappings.contains(where: { $0.curriculumItemID == itemID }) else { return }
        updated.curriculumMappings.append(CurriculumMapping(assignmentID: assignmentID, curriculumItemID: itemID, mappingKind: "assignment"))
        await saveNow(updated, action: "Reference not added", auditDetail: nil)
    }

    func confirmMapping(id: UUID) async {
        guard var updated = await currentSetup(),
              let index = updated.curriculumMappings.firstIndex(where: { $0.id == id }) else { return }
        updated.curriculumMappings[index].teacherConfirmed = true
        await saveNow(updated, action: "Reference not confirmed", auditDetail: nil)
    }

    /// Rejecting a suggestion and removing a confirmed reference both delete the mapping.
    func removeMapping(id: UUID) async {
        guard var updated = await currentSetup(),
              updated.curriculumMappings.contains(where: { $0.id == id }) else { return }
        updated.curriculumMappings.removeAll { $0.id == id }
        await saveNow(updated, action: "Reference not removed", auditDetail: nil)
    }

    // MARK: - Curriculum reference import

    /// Reads a teacher's curriculum/reference file (text, CSV or Excel) and saves a summary of it as the
    /// assignment's curriculum reference. Drafts and final reviews that used the old reference become stale
    /// through the normal fingerprint check; mappings are kept.
    func importCurriculumFile(at url: URL) async {
        guard let current = await currentSetup() else { return }
        let text: String
        do {
            text = try Self.curriculumText(from: url)
        } catch {
            alert = AlertMessage(title: "Curriculum file not read", error: error)
            return
        }
        var updated = current
        updated.assignment.curriculumReference = Self.curriculumSummary(from: text, sourceName: url.lastPathComponent)
        await saveNow(updated, action: "Curriculum reference not saved",
                      auditDetail: "Imported teacher-provided curriculum/reference material from \(url.lastPathComponent).")
        if alert == nil { lastCurriculumImportFileName = url.lastPathComponent }
    }

    private static func curriculumText(from url: URL) throws -> String {
        guard url.pathExtension.lowercased() == "xlsx" else { return try TextFileReader.read(url) }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try SpreadsheetReader.rows(fromXLSX: url)
            .map { $0.joined(separator: "\t") }
            .joined(separator: "\n")
    }

    private static func curriculumSummary(from text: String, sourceName: String) -> String {
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

    // MARK: - Gradebook export

    /// Writes the assignment's gradebook CSV into `tmp/Exports/` and records it. Totals appear only for
    /// approved, current final reviews.
    func prepareGradebookCSV() async {
        guard let current = await currentSetup() else { return }
        if let message = await app.services.authenticateIfRequired(for: .csvGradebook) {
            alert = AlertMessage(title: "Export not created", message: message)
            return
        }
        finishSharing()
        var writtenURL: URL?
        do {
            let database = try app.requireDatabase()
            let assignmentID = assignmentID
            let submissions = try await database.submissionGraphs(assignmentID: assignmentID)
            let order = Dictionary(
                submissions.map { graph in (graph.id, self.submissions.firstIndex { $0.id == graph.id } ?? Int.max) },
                uniquingKeysWith: { first, _ in first }
            )
            let ordered = submissions.sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
            let csv = CSVExportService.gradebookCSV(setup: current, submissions: ordered)
            let generatedAt = Date()
            let url = try ExportFileStore.write(
                Data(csv.utf8),
                fileName: ExportFilenameBuilder.filename(kind: .csvGradebook, assignmentID: assignmentID, extension: "csv", date: generatedAt)
            )
            writtenURL = url
            try await database.recordExport(ExportRecord(
                assignmentID: assignmentID, submissionID: nil, kind: .csvGradebook, createdAt: generatedAt,
                contentSHA256: ContentDigest.sha256Hex(Data(csv.utf8)),
                includesPrivateTeacherNotes: false, includesOriginalSources: false
            ))
            preparedExport = PreparedExport(kind: .csvGradebook, url: url, title: "Gradebook CSV — \(current.assignment.title)")
        } catch {
            if let writtenURL { ExportFileStore.remove(writtenURL) }
            alert = AlertMessage(title: "Export not created", error: error)
        }
    }

    func finishSharing() {
        if let preparedExport { ExportFileStore.remove(preparedExport.url) }
        preparedExport = nil
    }
}
