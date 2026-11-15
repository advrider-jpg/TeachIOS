import CoreGraphics
import Foundation
import Observation
import SwiftUI

/// One student's submission, for one routed screen. Every read and write names `id`; nothing here
/// depends on what another screen has open. When the submission (or its assignment) no longer exists,
/// `isMissing` becomes true, the host shows `MissingAssignmentRouteView`, and every action does nothing.
@Observable @MainActor
final class SubmissionSession {
    let id: UUID

    private(set) var graph: SubmissionGraph?
    private(set) var setup: AssignmentSetup?
    private(set) var isMissing = false
    var alert: AlertMessage?

    /// The final review as the teacher is editing it. Edits are autosaved; while an edit is pending,
    /// observed values do not replace it.
    private(set) var review: FinalGradeReview?

    /// Criteria the on-device model has written so far ("Draft in progress — not saved").
    private(set) var partialCriteria: [PartialCriterion] = []
    private(set) var generationProgress: AIGenerationProgress = .idle

    /// Built by `prepareAIDraft()` when the AI Draft screen opens, for the packet it was built from.
    private(set) var aiReadiness: AIReadinessReport?
    private(set) var packetPreview: AIPacketPreview?
    @ObservationIgnored private var aiReadinessFingerprint: String?

    private(set) var preparedExport: PreparedExport?

    @ObservationIgnored let app: AppModel
    @ObservationIgnored private(set) lazy var reviewAutosave = AutosaveScheduler { [weak self] in
        await self?.saveReview()
    }

    /// The export kinds a single submission offers.
    static let exportKinds: [ExportKind] = [.studentMarkdown, .studentPDF, .teacherAuditMarkdown, .teacherAuditPDF, .zipArchive]

    init(id: UUID, app: AppModel) {
        self.id = id
        self.app = app
    }

    // MARK: - Derived state (never stored)

    var hasLoaded: Bool { graph != nil && setup != nil }

    /// The class name, for display. Jobs and exports read it from the store when they run.
    var className: String {
        setup.map { app.className(for: $0.assignment.classGroupID) } ?? ""
    }

    var runningWork: WorkKind? { app.backgroundWork.kind(for: id) }

    /// The last failure of a slow job for this submission, if the teacher has not dismissed it.
    var workFailure: AlertMessage? { app.backgroundWork.failures[id] }

    var localAIStatus: LocalAIStatus { app.services.grading.localAIStatus }

    /// Changes whenever the grading inputs change; the AI Draft screen uses it as its `.task(id:)`.
    var packetFingerprint: String? {
        guard let graph, let setup else { return nil }
        return try? graph.packetFingerprint(setup: setup)
    }

    /// Readiness of every step, using the review as currently edited.
    var readiness: AssignmentReadiness? {
        guard var graph, let setup else { return nil }
        graph.finalReview = review
        let report = aiReadinessFingerprint == packetFingerprint ? aiReadiness : nil
        return AssignmentReadiness(
            setup: setup,
            submission: graph,
            aiStatus: localAIStatus,
            aiReport: report,
            draftRunning: runningWork == .draft
        )
    }

    /// The next student under the same assignment, in roster order.
    var nextSubmissionID: UUID? { app.nextSubmission(after: id)?.id }

    func dismissWorkFailure() {
        app.backgroundWork.clearFailure(submissionID: id)
    }

    // MARK: - Observation

    /// Feeds `graph`, `setup` and `review` for as long as the calling task runs (the host's `.task`).
    func observe() async {
        let database: AppDatabase
        let first: SubmissionGraph?
        do {
            database = try app.requireDatabase()
            first = try await database.submission(id: id)
        } catch {
            alert = AlertMessage(title: "Student work could not be opened", error: error)
            return
        }
        guard let first else {
            markMissing()
            return
        }
        apply(graph: first)
        let assignmentID = first.submission.assignmentID
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.observeGraph(database) }
            group.addTask { await self.observeSetup(database, assignmentID: assignmentID) }
        }
    }

    private func observeGraph(_ database: AppDatabase) async {
        do {
            for try await value in database.observeSubmission(id: id) {
                apply(graph: value)
            }
        } catch is CancellationError {
        } catch {
            alert = AlertMessage(title: "Student work could not be read", error: error)
        }
    }

    private func observeSetup(_ database: AppDatabase, assignmentID: UUID) async {
        do {
            for try await value in database.observeAssignment(id: assignmentID) {
                guard let value else {
                    markMissing()
                    continue
                }
                setup = value
            }
        } catch is CancellationError {
        } catch {
            alert = AlertMessage(title: "Assignment could not be read", error: error)
        }
    }

    private func apply(graph value: SubmissionGraph?) {
        guard let value else {
            markMissing()
            return
        }
        let draftChanged = graph?.draft?.id != value.draft?.id
        graph = value
        if draftChanged { partialCriteria = [] }
        if !reviewAutosave.holdsLocalEdits {
            review = value.finalReview
        }
    }

    private func markMissing() {
        isMissing = true
        reviewAutosave.discardPending()
        finishSharing()
    }

    /// What every action needs; nil (and nothing happens) when the submission is missing or not loaded.
    private func actionContext(_ action: String) -> ActionContext? {
        guard !isMissing, let graph, let setup else { return nil }
        do {
            return ActionContext(database: try app.requireDatabase(), graph: graph, setup: setup)
        } catch {
            alert = AlertMessage(title: "\(action) failed", error: error)
            return nil
        }
    }

    private func busyAlert(_ action: String) {
        let running = runningWork?.displayName ?? "Another task"
        alert = AlertMessage(title: "\(action) not started", message: "\(running) is still running for this student. Wait for it to finish.")
    }

    // MARK: - Student work

    func importScan(_ images: [CGImage]) {
        startImport(.scan, action: "Scan") { importer, submissionID in
            try await importer.importScannedImages(images, submissionID: submissionID)
        }
    }

    func importPhotos(_ imageData: [Data]) {
        startImport(.photoImport, action: "Photo import") { importer, submissionID in
            try await importer.importPhotos(imageData, submissionID: submissionID)
        }
    }

    func importPDF(at url: URL) {
        startImport(.pdfImport, action: "PDF import") { importer, submissionID in
            try await importer.importPDF(at: url, submissionID: submissionID)
        }
    }

    private func startImport(
        _ kind: WorkKind,
        action: String,
        run: @escaping @Sendable (any SourceImporting, UUID) async throws -> ImportedInput
    ) {
        guard let context = actionContext(action) else { return }
        let importer: any SourceImporting
        let storageRoot: URL
        do {
            importer = try app.requireImporter()
            storageRoot = try app.requireStorageRoot()
        } catch {
            alert = AlertMessage(title: "\(action) failed", error: error)
            return
        }
        let database = context.database
        let submissionID = id
        let assignmentID = context.graph.submission.assignmentID
        let started = app.backgroundWork.start(kind, submissionID: submissionID) {
            let imported = try await run(importer, submissionID)
            try await SubmissionSession.saveImported(
                imported, database: database, storageRoot: storageRoot,
                submissionID: submissionID, assignmentID: assignmentID
            )
        }
        if !started { busyAlert(action) }
    }

    /// Saves imported work for the submission it was started for, then deletes the files it replaced.
    /// If the submission is gone, the newly written files are deleted and the failure is reported.
    nonisolated private static func saveImported(
        _ imported: ImportedInput,
        database: AppDatabase,
        storageRoot: URL,
        submissionID: UUID,
        assignmentID: UUID
    ) async throws {
        let replaced: [String]
        do {
            replaced = try await database.replaceInput(
                submissionID: submissionID, kind: .scanned, pastedText: nil,
                sources: imported.sources, ocr: imported.ocr
            )
        } catch {
            _ = SourceFileCleanup.delete(imported.sources.compactMap(\.localRelativePath), storageRoot: storageRoot)
            throw error
        }
        try await database.appendAudit(AuditEvent(
            assignmentID: assignmentID, submissionID: submissionID, eventType: .sourceCaptured,
            detail: "\(imported.ocr.pages.count) page(s) imported with \(imported.ocr.engine). Scanned text needs teacher review."
        ))
        try await recordCleanup(of: replaced, database: database, storageRoot: storageRoot, submissionID: submissionID, assignmentID: assignmentID)
    }

    nonisolated private static func recordCleanup(
        of paths: [String],
        database: AppDatabase,
        storageRoot: URL,
        submissionID: UUID,
        assignmentID: UUID
    ) async throws {
        let failed = SourceFileCleanup.delete(paths, storageRoot: storageRoot)
        guard !failed.isEmpty else { return }
        try await database.appendAudit(AuditEvent(
            assignmentID: assignmentID, submissionID: submissionID, eventType: .localFileCleanupFailed,
            detail: SourceFileCleanup.failureMessage(failed)
        ))
    }

    /// Saves pasted text as the submission's teacher-reviewed work, replacing any earlier work.
    func savePastedText(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let context = actionContext("Paste student work") else { return }
        guard !trimmed.isEmpty else {
            alert = AlertMessage(title: "Student work not saved", message: "Paste non-empty student work before saving it.")
            return
        }
        await replaceInput(context, kind: .pasted, pastedText: trimmed, action: "Student work not saved",
                           detail: "Pasted student text saved as teacher-reviewed work.")
    }

    /// Removes the submission's student work (sources, scanned text and evidence).
    func clearStudentWork() async {
        guard let context = actionContext("Clear student work") else { return }
        await replaceInput(context, kind: .none, pastedText: nil, action: "Student work not cleared",
                           detail: "Student work removed by the teacher.")
    }

    private func replaceInput(
        _ context: ActionContext,
        kind: SubmissionInputKind,
        pastedText: String?,
        action: String,
        detail: String
    ) async {
        guard runningWork == nil else {
            busyAlert(action)
            return
        }
        do {
            let storageRoot = try app.requireStorageRoot()
            let replaced = try await context.database.replaceInput(
                submissionID: id, kind: kind, pastedText: pastedText, sources: [], ocr: nil
            )
            try await context.database.appendAudit(AuditEvent(
                assignmentID: context.graph.submission.assignmentID, submissionID: id, eventType: .inputChanged, detail: detail
            ))
            try await SubmissionSession.recordCleanup(
                of: replaced, database: context.database, storageRoot: storageRoot,
                submissionID: id, assignmentID: context.graph.submission.assignmentID
            )
        } catch {
            alert = AlertMessage(title: action, error: error)
        }
    }

    // MARK: - Scanned text review

    func confirmLine(_ lineID: UUID) async {
        await updateLine(lineID, action: "Line not confirmed") { line in
            line.teacherConfirmed = true
            line.isRejected = false
        }
    }

    func correctLine(_ lineID: UUID, text: String) async {
        let corrected = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !corrected.isEmpty else {
            alert = AlertMessage(title: "Line not corrected", message: "Enter the corrected text, or reject the line.")
            return
        }
        await updateLine(lineID, action: "Line not corrected") { line in
            line.correctedText = corrected
            line.teacherConfirmed = true
            line.isRejected = false
        }
    }

    func rejectLine(_ lineID: UUID) async {
        await updateLine(lineID, action: "Line not rejected") { line in
            line.isRejected = true
            line.teacherConfirmed = false
        }
    }

    /// "Confirm all": confirms only Vision lines at or above the confidence threshold. Low-confidence
    /// lines and PDF text-layer lines still need line-by-line action.
    func confirmAllConfidentLines() async {
        guard let context = actionContext("Confirm lines"), let ocr = context.graph.ocr else { return }
        let before = Dictionary(ocr.allLines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let changed = ocr.markingAllLinesConfirmed().allLines.filter { before[$0.id] != $0 }
        do {
            for line in changed {
                try await context.database.updateOCRLine(line, submissionID: id)
            }
        } catch {
            alert = AlertMessage(title: "Lines not confirmed", error: error)
        }
    }

    private func updateLine(_ lineID: UUID, action: String, change: (inout OCRLine) -> Void) async {
        guard let context = actionContext(action) else { return }
        guard var line = context.graph.ocr?.allLines.first(where: { $0.id == lineID }) else {
            alert = AlertMessage(title: action, message: AppDatabaseError.notFound(lineID).localizedDescription)
            return
        }
        change(&line)
        do {
            try await context.database.updateOCRLine(line, submissionID: id)
        } catch {
            alert = AlertMessage(title: action, error: error)
        }
    }

    /// Refused by the store while any line still needs the teacher's action.
    func markScannedTextReviewed() async {
        guard let context = actionContext("Mark scanned text reviewed") else { return }
        do {
            try await context.database.setOCRReviewStatus(.reviewed, submissionID: id)
            try await context.database.appendAudit(AuditEvent(
                assignmentID: context.graph.submission.assignmentID, submissionID: id, eventType: .ocrReviewed,
                detail: "Teacher marked the scanned text reviewed."
            ))
        } catch {
            alert = AlertMessage(title: "Scanned text not marked reviewed", error: error)
        }
    }

    // MARK: - AI draft

    /// Builds the AI readiness report and packet preview for the current grading inputs and prewarms the
    /// on-device model. Called by the AI Draft screen with `.task(id: packetFingerprint)`.
    func prepareAIDraft() async {
        guard let context = actionContext("AI readiness") else { return }
        let services = app.services
        do {
            let fingerprint = try context.graph.packetFingerprint(setup: context.setup)
            let className = try await SubmissionSession.className(context.database, classGroupID: context.setup.assignment.classGroupID)
            let input = try GradingPacketBuilder.gradingInput(setup: context.setup, graph: context.graph, className: className)
            var plan: PromptBudgetPlan?
            var budgetError: (any Error)?
            do {
                try LocalOnlyGradingValidator.validate(input)
                plan = try await services.budgeter.plan(input: input, after: nil)
            } catch {
                budgetError = error
            }
            aiReadiness = AIReadinessAnalyzer.report(
                input: input,
                draftIsStale: try context.graph.draftIsStale(setup: context.setup),
                finalReviewIsStale: try context.graph.finalReviewIsStale(setup: context.setup),
                localAIStatus: services.grading.localAIStatus,
                supportsCurrentLocale: services.grading.supportsCurrentLocale,
                budgetPlan: plan,
                budgetError: budgetError
            )
            packetPreview = plan.map { AIPacketPreviewBuilder.preview(input: input, plan: $0) }
            aiReadinessFingerprint = fingerprint
            (services.grading as? FoundationModelGradingService)?.prewarmIfAvailable()
        } catch {
            aiReadiness = nil
            packetPreview = nil
            aiReadinessFingerprint = nil
            alert = AlertMessage(title: "AI readiness could not be checked", error: error)
        }
    }

    /// Drafts feedback locally in the background. The draft is built from the saved grading inputs and
    /// stored for this submission only, even if the teacher has moved on to another student.
    func startDraft() {
        guard let context = actionContext("Draft") else { return }
        if let issue = readiness?.draftIssues.first {
            alert = AlertMessage(title: "Draft not started", message: issue.message)
            return
        }
        let database = context.database
        let grading = app.services.grading
        let submissionID = id
        let assignmentID = context.setup.id
        let classGroupID = context.setup.assignment.classGroupID
        let progress: AIGenerationProgressHandler = { [weak self] update in
            self?.receive(update)
        }
        partialCriteria = []
        generationProgress = AIGenerationProgress(stage: .validatingInputs, detail: "Checking local grading inputs.", canCancel: true)
        let started = app.backgroundWork.start(.draft, submissionID: submissionID) {
            guard let graph = try await database.submission(id: submissionID) else { throw AppDatabaseError.notFound(submissionID) }
            guard let setup = try await database.assignmentSetup(id: assignmentID) else { throw AppDatabaseError.notFound(assignmentID) }
            let className = try await SubmissionSession.className(database, classGroupID: classGroupID)
            let input = try GradingPacketBuilder.gradingInput(setup: setup, graph: graph, className: className)
            let draft = try await grading.draftGrade(input: input, progress: progress)
            try Task.checkCancellation()
            try await database.replaceDraft(draft, submissionID: submissionID)
            try await database.appendAudit(AuditEvent(
                assignmentID: assignmentID, submissionID: submissionID, eventType: .draftGenerated,
                detail: "Local grading draft generated from packet \(input.packetFingerprint)."
            ))
        }
        if !started {
            generationProgress = .idle
            busyAlert("Draft")
        }
    }

    func cancelDraft() {
        guard runningWork == .draft else { return }
        generationProgress = AIGenerationProgress(
            stage: .cancellationRequested,
            detail: "Cancelling the local draft. No draft will be saved if cancellation completes."
        )
        app.backgroundWork.cancel(submissionID: id)
    }

    private func receive(_ update: AIGenerationProgress) {
        generationProgress = update
        if case .partial(let rows) = update.stage {
            partialCriteria = rows
        }
    }

    /// Rewrites the student feedback of the saved final review locally. The result is written into this
    /// submission's final review (left in progress for the teacher to approve), even if the teacher has
    /// moved on to another student.
    func rewriteFeedback(mode: FeedbackRewriteMode) async {
        guard let context = actionContext("Feedback rewrite") else { return }
        guard let review, review.status != .approved else {
            alert = AlertMessage(
                title: "Feedback not rewritten",
                message: review == nil
                    ? "Start final review before using the feedback rewrite assistant."
                    : "Approved feedback cannot be rewritten by AI. Edit it yourself; the review then needs approval again."
            )
            return
        }
        if case .unavailable(let message) = localAIStatus {
            alert = AlertMessage(title: "Feedback not rewritten", message: message)
            return
        }
        await reviewAutosave.flushNow()
        let database = context.database
        let grading = app.services.grading
        let submissionID = id
        let assignmentID = context.setup.id
        let progress: AIGenerationProgressHandler = { [weak self] update in
            self?.receive(update)
        }
        let started = app.backgroundWork.start(.feedbackRewrite, submissionID: submissionID) {
            guard let graph = try await database.submission(id: submissionID),
                  let current = graph.finalReview else { throw AppDatabaseError.notFound(submissionID) }
            guard let setup = try await database.assignmentSetup(id: assignmentID) else { throw AppDatabaseError.notFound(assignmentID) }
            let input = try FeedbackRewriteInput(
                setup: setup, graph: graph, review: current, mode: mode,
                selectedTeacherNotes: mode == .teacherNotesToStudentSafe ? current.privateTeacherNotes : ""
            )
            let result = try await grading.rewriteFeedback(input: input, progress: progress)
            try Task.checkCancellation()
            guard var latest = try await database.submission(id: submissionID)?.finalReview else {
                throw AppDatabaseError.notFound(submissionID)
            }
            latest.studentFeedback = result.rewrittenFeedback
            latest.teacherEdited = true
            latest.status = .inProgress
            latest.finalizedAt = nil
            try await database.saveFinalReview(latest, submissionID: submissionID)
            try await database.appendAudit(AuditEvent(
                assignmentID: assignmentID, submissionID: submissionID, eventType: .feedbackRewritten,
                detail: "Student feedback rewritten locally (\(mode.displayName)). Teacher approval remains required."
            ))
        }
        if !started { busyAlert("Feedback rewrite") }
    }

    nonisolated private static func className(_ database: AppDatabase, classGroupID: UUID) async throws -> String {
        try await database.classGroups().first { $0.id == classGroupID }?.name ?? ""
    }

    // MARK: - Final review

    /// Starts the teacher's final review from the current AI draft (replacing any earlier review).
    func startFinalReviewFromDraft() async {
        guard let context = actionContext("Start final review") else { return }
        if let issue = readiness?.draftReviewStartIssues.first {
            alert = AlertMessage(title: "Final review not started", message: issue.message)
            return
        }
        guard let draft = context.graph.draft else { return }
        do {
            let started = FinalGradeReview(
                packetFingerprint: try context.graph.packetFingerprint(setup: context.setup),
                criteria: draft.criteria.map(FinalCriterionScore.init(from:)),
                studentFeedback: draft.studentFeedback,
                privateTeacherNotes: draft.teacherNotes,
                teacherEdited: false
            )
            try await persistReview(started, context: context, event: .finalReviewStarted,
                                    detail: "Teacher review started from the current local draft.")
        } catch {
            alert = AlertMessage(title: "Final review not started", error: error)
        }
    }

    /// Starts a final review without an AI draft: one row per rubric criterion, or one teacher-entered
    /// criterion when the assignment has no point-bearing rubric (replacing any earlier review).
    func startManualFinalReview() async {
        guard let context = actionContext("Start manual final review") else { return }
        if let issue = readiness?.finalReviewStartIssues.first {
            alert = AlertMessage(title: "Final review not started", message: issue.message)
            return
        }
        let rubric = context.setup.parsedRubric.criteria
        let criteria: [FinalCriterionScore] = rubric.isEmpty
            ? [Self.blankCriterion(title: "Teacher-entered grading standard")]
            : rubric.map { criterion in
                FinalCriterionScore(
                    criterionID: criterion.id, rating: "", proposedPoints: 0, finalPoints: 0, explanation: "",
                    teacherRationale: "Manual teacher-created final review."
                )
            }
        do {
            let started = FinalGradeReview(
                packetFingerprint: try context.graph.packetFingerprint(setup: context.setup),
                criteria: criteria,
                studentFeedback: "",
                privateTeacherNotes: "",
                teacherEdited: false
            )
            try await persistReview(started, context: context, event: .finalReviewStarted,
                                    detail: "Teacher started a manual final review without an AI draft.")
        } catch {
            alert = AlertMessage(title: "Final review not started", error: error)
        }
    }

    private static func blankCriterion(title: String) -> FinalCriterionScore {
        FinalCriterionScore(
            criterionID: "teacher-\(UUID().uuidString.lowercased())",
            rating: "", proposedPoints: 0, finalPoints: 0, explanation: "",
            teacherRationale: "Teacher-entered criterion. Edit it to match the grading standard, then approve it.",
            title: title, maxPoints: 0
        )
    }

    /// A binding to one text field of the review (student feedback, private notes). Edits autosave.
    func reviewText(_ keyPath: WritableKeyPath<FinalGradeReview, String> & Sendable) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.review?[keyPath: keyPath] ?? "" },
            set: { [weak self] value in self?.editReview { $0[keyPath: keyPath] = value } }
        )
    }

    /// A binding to one text field of a criterion (rating, explanation, teacher rationale, title). Edits autosave.
    func criterionText(_ criterionID: UUID, _ keyPath: WritableKeyPath<FinalCriterionScore, String> & Sendable) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.review?.criteria.first { $0.id == criterionID }?[keyPath: keyPath] ?? "" },
            set: { [weak self] value in
                self?.editCriterion(criterionID) { $0[keyPath: keyPath] = value }
            }
        )
    }

    func setFinalPoints(_ points: Double, for criterionID: UUID) {
        editCriterion(criterionID) { $0.finalPoints = points }
    }

    /// For a criterion without a rubric maximum (teacher-entered criteria).
    func setMaximumPoints(_ points: Double, for criterionID: UUID) {
        editCriterion(criterionID) { $0.maxPoints = points }
    }

    /// Takes the draft's proposed points (kept within 0 and the maximum) and marks the criterion approved.
    func acceptCriterion(_ criterionID: UUID) {
        guard let setup else { return }
        editCriterion(criterionID) { criterion in
            let maximum = AssignmentReadiness.maximumPoints(for: criterion, setup: setup) ?? 0
            criterion.finalPoints = maximum > 0 ? min(max(criterion.proposedPoints, 0), maximum) : max(criterion.proposedPoints, 0)
            criterion.teacherApproved = true
            if criterion.teacherRationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                criterion.teacherRationale = "Teacher accepted this criterion suggestion after review."
            }
        }
    }

    func rejectCriterion(_ criterionID: UUID) {
        editCriterion(criterionID) { criterion in
            criterion.teacherApproved = false
            criterion.teacherRationale = "Teacher rejected this criterion suggestion; edit score, evidence, and feedback before approval."
        }
    }

    func addCriterion() {
        editReview { $0.criteria.append(Self.blankCriterion(title: "New criterion")) }
    }

    func deleteCriterion(_ criterionID: UUID) {
        editReview { $0.criteria.removeAll { $0.id == criterionID } }
    }

    private func editCriterion(_ criterionID: UUID, change: (inout FinalCriterionScore) -> Void) {
        editReview { review in
            guard let index = review.criteria.firstIndex(where: { $0.id == criterionID }) else { return }
            change(&review.criteria[index])
        }
    }

    /// Every review edit goes through here and the same autosave. An edit to an approved review returns
    /// it to in progress: the teacher approves the changed grade again.
    private func editReview(_ change: (inout FinalGradeReview) -> Void) {
        guard !isMissing, let current = review else { return }
        var edited = current
        change(&edited)
        guard edited != current else { return }
        edited.teacherEdited = true
        if edited.status == .approved {
            edited.status = .inProgress
            edited.finalizedAt = nil
        }
        review = edited
        reviewAutosave.schedule()
    }

    private func saveReview() async {
        guard !isMissing, let review else { return }
        do {
            try await app.requireDatabase().saveFinalReview(review, submissionID: id)
        } catch {
            alert = AlertMessage(title: "Final review not saved", error: error)
            reviewAutosave.discardPending()
            self.review = graph?.finalReview
        }
    }

    /// Saves pending review edits now (screen disappears, app goes to the background).
    func flushPendingEdits() async {
        await reviewAutosave.flushNow()
    }

    private func persistReview(
        _ newReview: FinalGradeReview,
        context: ActionContext,
        event: AuditEventType,
        detail: String
    ) async throws {
        reviewAutosave.discardPending()
        review = newReview
        do {
            try await context.database.saveFinalReview(newReview, submissionID: id)
        } catch {
            review = graph?.finalReview
            throw error
        }
        try await context.database.appendAudit(AuditEvent(
            assignmentID: context.setup.id, submissionID: id, eventType: event, detail: detail
        ))
    }

    // MARK: - Evidence

    /// Attaches a scanned-text line to a criterion as evidence.
    func addLineEvidence(lineID: UUID, to criterionID: UUID) async {
        guard let context = actionContext("Add evidence"), review != nil else { return }
        guard let page = context.graph.ocr?.pages.first(where: { $0.lines.contains { $0.id == lineID } }),
              let line = page.lines.first(where: { $0.id == lineID }) else {
            alert = AlertMessage(title: "Evidence not added", message: AppDatabaseError.notFound(lineID).localizedDescription)
            return
        }
        let quote = line.reviewedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !quote.isEmpty else {
            alert = AlertMessage(title: "Evidence not added", message: "This line has no text to quote.")
            return
        }
        await attachEvidence(
            EvidenceReference(
                submissionID: id, ocrLineID: line.id, pageIndex: page.pageIndex, quote: quote,
                boundingBox: line.boundingBox, sourceKind: .ocrLine, teacherConfirmed: line.teacherConfirmed
            ),
            to: criterionID,
            database: context.database
        )
    }

    /// Attaches a quote the teacher typed or selected from the reviewed text.
    func addManualEvidence(quote: String, to criterionID: UUID) async {
        guard let context = actionContext("Add evidence"), review != nil else { return }
        let cleaned = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            alert = AlertMessage(title: "Evidence not added", message: "Enter the quote to attach.")
            return
        }
        await attachEvidence(
            EvidenceReference(submissionID: id, quote: cleaned, sourceKind: .manualTeacherEntry, teacherConfirmed: true),
            to: criterionID,
            database: context.database
        )
    }

    private func attachEvidence(_ evidence: EvidenceReference, to criterionID: UUID, database: AppDatabase) async {
        guard review?.criteria.contains(where: { $0.id == criterionID }) == true else { return }
        do {
            try await database.addEvidence(evidence, submissionID: id)
        } catch {
            alert = AlertMessage(title: "Evidence not added", error: error)
            return
        }
        editCriterion(criterionID) { criterion in
            criterion.evidenceIDs.append(evidence.id)
            criterion.teacherApproved = false
        }
    }

    /// Detaches evidence from a criterion and, when no criterion uses it any more, deletes the record.
    func removeEvidence(_ evidenceID: UUID, from criterionID: UUID) async {
        guard let context = actionContext("Remove evidence") else { return }
        editCriterion(criterionID) { criterion in
            criterion.evidenceIDs.removeAll { $0 == evidenceID }
            criterion.teacherApproved = false
        }
        await reviewAutosave.flushNow()
        guard review?.criteria.contains(where: { $0.evidenceIDs.contains(evidenceID) }) == false else { return }
        do {
            try await context.database.removeEvidence(id: evidenceID, submissionID: id)
        } catch {
            alert = AlertMessage(title: "Evidence not removed", error: error)
        }
    }

    // MARK: - Approval

    /// Records the teacher-approved final grade.
    func approveFinalReview() async {
        guard let context = actionContext("Approve final grade"), var approved = review else { return }
        if let issue = readiness?.approvalIssues.first {
            alert = AlertMessage(title: "Final grade not approved", message: issue.message)
            return
        }
        do {
            approved.criteria = approved.criteria.map { criterion in
                var criterion = criterion
                criterion.teacherApproved = true
                return criterion
            }
            approved.status = .approved
            approved.packetFingerprint = try context.graph.packetFingerprint(setup: context.setup)
            approved.finalizedAt = Date()
            let maximum = approved.criteria.compactMap { AssignmentReadiness.maximumPoints(for: $0, setup: context.setup) }.reduce(0, +)
            try await persistReview(
                approved, context: context, event: .finalApproved,
                detail: "Teacher approved final grade \(GradeTotals.formatted(approved.totalScore)) / \(GradeTotals.formatted(maximum))."
            )
        } catch {
            alert = AlertMessage(title: "Final grade not approved", error: error)
        }
    }

    // MARK: - Exports

    /// Writes the export into `tmp/Exports/`, records it, and sets `preparedExport` for preview and sharing.
    /// Student reports need an approved, current final review; teacher records are authentication-gated.
    func prepareExport(_ kind: ExportKind) async {
        guard let context = actionContext("Export"), Self.exportKinds.contains(kind) else { return }
        await reviewAutosave.flushNow()
        let isStudentFacing = kind == .studentMarkdown || kind == .studentPDF
        if isStudentFacing, let issue = readiness?.studentReportIssues.first {
            alert = AlertMessage(title: "Export not created", message: issue.message)
            return
        }
        if let message = await app.services.authenticateIfRequired(for: kind) {
            alert = AlertMessage(title: "Export not created", message: message)
            return
        }
        finishSharing()
        var writtenURL: URL?
        do {
            let database = context.database
            guard let graph = try await database.submission(id: id) else { throw AppDatabaseError.notFound(id) }
            guard let setup = try await database.assignmentSetup(id: graph.submission.assignmentID) else {
                throw AppDatabaseError.notFound(graph.submission.assignmentID)
            }
            let generatedAt = Date()
            let url = try await writeExport(kind, setup: setup, graph: graph, generatedAt: generatedAt, database: database)
            writtenURL = url
            let risk = ExportRiskSummary.summary(for: kind, items: [(setup: setup, submission: graph)])
            try await database.recordExport(ExportRecord(
                assignmentID: setup.id,
                submissionID: id,
                kind: kind,
                createdAt: generatedAt,
                contentSHA256: try ContentDigest.sha256Hex(fileAt: url),
                includesPrivateTeacherNotes: risk.includesPrivateNotes,
                includesOriginalSources: risk.includesOriginalSources
            ))
            try await database.appendAudit(AuditEvent(
                assignmentID: setup.id, submissionID: id, eventType: .exportPrepared,
                detail: "\(kind.displayName) prepared for sharing."
            ))
            preparedExport = PreparedExport(
                kind: kind, url: url,
                title: "\(kind.displayName) — \(graph.student.displayName), \(setup.assignment.title)"
            )
        } catch {
            if let writtenURL { ExportFileStore.remove(writtenURL) }
            alert = AlertMessage(title: "Export not created", error: error)
        }
    }

    private func writeExport(
        _ kind: ExportKind,
        setup: AssignmentSetup,
        graph: SubmissionGraph,
        generatedAt: Date,
        database: AppDatabase
    ) async throws -> URL {
        func fileName(_ ext: String) -> String {
            ExportFilenameBuilder.filename(kind: kind, assignmentID: setup.id, extension: ext, date: generatedAt)
        }
        switch kind {
        case .studentMarkdown:
            let report = try ReportBuilder.studentReport(setup: setup, submission: graph, generatedAt: generatedAt)
            return try ExportFileStore.write(Data(MarkdownRenderer.render(report).utf8), fileName: fileName("md"))
        case .studentPDF:
            let report = try ReportBuilder.studentReport(setup: setup, submission: graph, generatedAt: generatedAt)
            return try ExportFileStore.write(try PDFRenderer.render(report), fileName: fileName("pdf"))
        case .teacherAuditMarkdown:
            let report = ReportBuilder.teacherRecord(setup: setup, submission: graph, generatedAt: generatedAt)
            return try ExportFileStore.write(Data(MarkdownRenderer.render(report).utf8), fileName: fileName("md"))
        case .teacherAuditPDF:
            let report = ReportBuilder.teacherRecord(setup: setup, submission: graph, generatedAt: generatedAt)
            return try ExportFileStore.write(try PDFRenderer.render(report), fileName: fileName("pdf"))
        case .zipArchive:
            let report = ReportBuilder.teacherRecord(setup: setup, submission: graph, generatedAt: generatedAt)
            let storageRoot = try app.requireStorageRoot()
            let classGroups = try await database.classGroups().filter { $0.id == setup.assignment.classGroupID }
            let enrollments = try await database.enrollments(inClass: setup.assignment.classGroupID)
                .filter { $0.studentID == graph.student.id }
            let snapshot = BackupSnapshot(
                classGroups: classGroups, students: [graph.student], enrollments: enrollments,
                assignments: [setup], submissions: [graph]
            )
            let sourceFiles = try graph.sources.compactMap(\.localRelativePath).map { path -> URL in
                guard let url = SourcePathSafety.resolvedLocalSourceURL(path, applicationSupportDirectory: storageRoot) else {
                    throw BackupArchiveError.archiveFailed("A source file has an unsafe location: \(path).")
                }
                return url
            }
            let destination = try ExportFileStore.exportsDirectory().appendingPathComponent(fileName("zip"))
            return try BackupArchiveService.writeTeacherRecordArchive(
                snapshot: snapshot,
                reportFiles: [
                    (name: "Teacher Record.md", data: Data(MarkdownRenderer.render(report).utf8)),
                    (name: "Teacher Record.pdf", data: try PDFRenderer.render(report))
                ],
                sourceFiles: sourceFiles,
                to: destination
            )
        default:
            throw GradeDraftError.exportFailed("\(kind.displayName) is not a single-student export.")
        }
    }

    /// Deletes the prepared file; called when the share sheet or preview finishes.
    func finishSharing() {
        if let preparedExport { ExportFileStore.remove(preparedExport.url) }
        preparedExport = nil
    }
}

/// What a submission action reads before it writes: the open store and the loaded records.
private struct ActionContext {
    let database: AppDatabase
    let graph: SubmissionGraph
    let setup: AssignmentSetup
}
