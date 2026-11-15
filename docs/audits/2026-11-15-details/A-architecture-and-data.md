# Area A — App architecture, state, data model and persistence

Reviewer scope: `GradeDraftApp.swift`, `ContentView.swift`, `AppRouting.swift`, `GradeDraftViewModel.swift` + all `GradeDraftViewModel+*.swift`, `Models/*`, `Persistence/*`, `Services/LocalJSONStore.swift`, `UI/Screens/ScreenModels.swift`, `docs/DATA_MODEL_V3.md`, `docs/ARCHITECTURE.md`, `docs/ledgers/DECISIONS_LEDGER.md` (D003, D013, D014). Repo at cd64e9d. All paths below are relative to `C:\TeachIOS\GradeDraft` unless they start with `docs/`.

## Summary in plain English

The app keeps everything in one large in-memory object (the view model). That object has a single "currently selected assignment" pointer, and almost every action reads and writes "whatever is selected right now". Screens get an assignment ID from navigation, but before every action they first move the global pointer to their ID and then call the action. That is why the "is this assignment saved?" check appears in ~60 places. The checks hide a real bug: slow work (OCR, PDF import, the on-device AI draft, feedback rewrite) remembers which assignment it started on, waits several seconds, and then writes its result into whichever assignment is selected **when it finishes**. If the teacher opens another student meanwhile, student A's scanned pages or AI draft land on student B's record and wipe B's work (A-01).

Persistence stores every assignment three ways: a full JSON copy, a normalized set of SQLite rows, and (if the database fails to open) a separate set of JSON files that the app silently switches to. Every save rewrites all three representations of **every** assignment, on the main thread. About 23 of the declared database tables are never read or written. The app has no released users yet (README:143, TestFlight not reached), so the "compatibility" and "legacy" machinery protects nobody and can be removed before first release.

The data model treats "assignment" as one student's submission. The rubric, instructions, answer key and exemplar are copied into each student's record, and classes are matched by name text rather than by their ID.

Severity counts: Critical 1, High 7, Medium 8, Low 5 (21 findings).

---

### A-01 — Critical — Slow tasks write their result into whichever assignment is selected when they finish, not the one they started on
- Area / files: `GradeDraftViewModel+DraftFinalReview.swift:69-117, 138-205`; `GradeDraftViewModel+StudentWorkImport.swift:16-51, 53-155`; `GradeDraftViewModel+AssignmentPersistence.swift:86-108, 110-122`
- What it is now and why it was probably done this way: each async action captures `currentAssignment` before the `await`, but after the `await` it calls `updateAssignment { … }` and `saveCurrentAssignment()`. Both use the **live** `selectedAssignmentID`. The pattern comes from an older single-assignment design where only one record ever existed.
- Why it is a problem: OCR of several pages, PDF import and Foundation Models drafting take seconds to tens of seconds. Nothing locks navigation during that time. `isWorking` only disables a few buttons (`StudentWorkScreen.swift:154,162,231`, `FinalReviewScreen.swift:57`). The assignment list (`AssignmentsScreen.swift:52`) and every screen's `.onAppear { viewModel.selectAssignment(assignmentID) }` (for example `FinalReviewScreen.swift:360`, `AssignmentOverviewScreen.swift:119`) move the selection. If the teacher opens student B while student A's scan is recognized, the result is:
  - B's `sourceInputs` are replaced with A's page files. Those files are stored under A's folder (`persistSourceImages(... assignmentID: currentAssignment.id)` at `StudentWorkImport.swift:26`).
  - B's OCR text becomes A's text.
  - B's `latestDraft` and `finalReview` are set to `nil`.
  - All of this is saved to disk.
  
  The same happens with an AI draft: A's draft is stored on B with A's packet fingerprint, and B's final review is deleted (`DraftFinalReview.swift:99-103`). Feedback rewrite writes A's `review` object, with A's criteria, onto B (`DraftFinalReview.swift:189-196`). In a grading tool this is a student-data mix-up and silent loss of the teacher's work.
- Evidence:
  ```swift
  // DraftFinalReview.swift:70, 92, 99
  guard let currentAssignment = currentSavedAssignmentForAction("Local draft generation") else { return }
  let result = try await gradingService.draftGrade(input: input, progress: progressHandler)
  updateAssignment { assignment in            // <- uses selectedAssignmentID *now*
      assignment.latestDraft = result
      assignment.finalReview = nil
  ```
  ```swift
  // AssignmentPersistence.swift:86-88
  func updateAssignment(_ transform: (inout AssignmentRecord) -> Void) {
      guard let selectedAssignmentID,
            let current = assignments.first(where: { $0.id == selectedAssignmentID }) else {
  ```
- Recommended fix: every mutation takes an explicit ID: `updateAssignment(id: UUID, _:)` and `save(assignmentID:)`. Async operations pass `currentAssignment.id` captured before the `await`. If that record no longer exists after the `await`, discard the result and say so. This falls out naturally from A-02 (per-screen models keyed by ID). Add a regression test: start a draft with a suspended fake `GradingServicing`, change selection, resume, and assert that the result is on the original ID only.
- Effort: S for the targeted fix (about 6 call sites), M as part of A-02. Low risk.
- Confidence: High for the code path. Medium-high that it can be reached in the UI: no navigation lock exists, but I could not run the app.

### A-02 — High — The global "selected assignment" pointer is the design flaw behind the scattered "saved-assignment preflight"
- Area / files: `GradeDraftViewModel.swift:9, 105-116`; `GradeDraftViewModel+RoutingStatus.swift:258-280`; 60 `currentSavedAssignmentForAction` call sites (DraftFinalReview 14, Export 10, OCRReviewEvidence 10, RubricCurriculumRoster 21, StudentWorkImport 4, RoutingStatus 1); ~50 `viewModel.selectAssignment(assignmentID)` calls in screens (for example `FinalReviewScreen.swift:54-199` has 17 of them); `AssignmentOverviewScreen.swift:233-262`; `RubricInstructionsScreen.swift:40`; `ExportsRestoreScreen.swift:28, 213`
- What it is now and why: routes carry an assignment ID (`AppLaunchRoute`, `AppRouting.swift:52-82`), but the view model's operations act on an implicit `selectedAssignmentID`. Screens therefore do "select, then act" on every button and every binding setter. To stop stale routes from acting on the wrong record, each operation re-checks that the selection still exists. That is the "fail-closed" rule from AGENTS.md, implemented as a guard copied into every method.
- Why it is a problem:
  1. The guard checks the wrong thing. It confirms that **some** selection exists, not that it is the route's assignment. A-01 shows the gap.
  2. The fail-closed rule is broken in several places:
     - The `assignment` getter silently falls back to the first assignment or to a brand-new blank record (`GradeDraftViewModel.swift:107-110`).
     - The overview binding falls back to `viewModel.assignment[keyPath:]` (`AssignmentOverviewScreen.swift:238`).
     - The export screens fall back to `viewModel.assignment` (`ExportsRestoreScreen.swift:28, 213`).
     - `RubricInstructionsScreen` force-unwraps (`assignment(for:)!`, line 40). A stale route there crashes instead of showing the not-found state.
  3. The cost is permanent: every new feature must remember both the select call and the guard.
- Evidence:
  ```swift
  // GradeDraftViewModel.swift:105-110
  var assignment: AssignmentRecord {
      get {
          guard let selectedAssignmentID,
                let assignment = assignments.first(where: { $0.id == selectedAssignmentID }) else {
              return assignments.first ?? AssignmentRecord()   // silent fallback
  ```
  ```swift
  // AssignmentOverviewScreen.swift:241-242 (binding setter, runs per keystroke)
  viewModel.selectAssignment(assignmentID)
  viewModel.updateAssignment { $0[keyPath: keyPath] = newValue }
  ```
- Recommended fix: make the ID part of the type, not part of the app's global state.
  - Introduce an `@Observable @MainActor final class AssignmentSession` (or `SubmissionModel`) created per route. It is built by `store.session(for: id) -> AssignmentSession?`, and the screen shows `MissingAssignmentRouteView` when that returns `nil`.
  - All per-assignment operations (OCR review, evidence, draft, final review, export) become methods on that session and operate on its own `id`. The fail-closed check happens once, at construction.
  - Delete `selectedAssignmentID`, the `assignment` computed property, `currentSavedAssignmentForAction` and all 50 `selectAssignment` calls in screens.
  - Keep a small app-level `@Observable AppModel` for lists, the class roster, backup/restore and settings.
  
  This is the standard SwiftUI pattern: value-based `NavigationStack(path:)` with `navigationDestination(for: AssignmentID.self)` building a model per destination ([Apple: Migrating to the Observable macro](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)).
- Effort: L (touches every screen). Medium risk; do it with A-12 and cover it with the existing UI smoke test.
- Confidence: High.

### A-03 — High — Each keystroke in an assignment field triggers AI readiness, model prewarm and export reset
- Area / files: `AssignmentOverviewScreen.swift:240-252`; `GradeDraftViewModel+RoutingStatus.swift:247-270`; `GradeDraftViewModel+DraftFinalReview.swift:8-26`
- What it is now: the binding setters call `selectAssignment`. That calls `clearPreparedExport()` and `refreshCapabilityStatus()`, which calls `FoundationModelGradingService.prewarmIfAvailable()` and `refreshAIReadiness()`. `refreshAIReadiness()` runs prompt budgeting, the readiness analyzer and the packet preview builder. It also overwrites `statusMessage`.
- Why it is a problem: typing a title or prompt re-runs the whole AI readiness pipeline on every character, asks the system to prewarm the on-device model on every character, and discards any prepared export. Combined with A-12 (every `@Published` change redraws every screen observing the view model), this is a typing-lag and battery problem on older iPads. It also overwrites status text the teacher was reading.
- Evidence: `RoutingStatus.swift:266-268` `selectedAssignmentID = id; clearPreparedExport(); refreshCapabilityStatus()`; `RoutingStatus.swift:251` `prewarmIfAvailable()`.
- Recommended fix: falls out of A-02 because there is no selection to set. Until then: make `selectAssignment` a no-op when the ID is unchanged. Compute readiness lazily, or debounce it with `.task(id: assignment.gradingPacketFingerprint)` on the AI Readiness screen only. Prewarm once, when the teacher opens the draft screen.
- Effort: S. Low risk.
- Confidence: High.

### A-04 — High — If the database fails to open, the app silently switches to an empty JSON store
- Area / files: `GradeDraftViewModel.swift:59-73`; `Services/LocalJSONStore.swift:58-…`; `UI/Screens/SettingsAboutLocalPrivacyScreen.swift:43`; `GradeDraftViewModel.swift:214-216`
- What it is now and why: `try? GRDBAssignmentStore(...)`. On any error (migration failure, disk full, a file-protection lock while the device is locked, a corrupt file), the app creates a `LocalJSONStore` in the same folder and carries on. `persistenceMode` records the fallback, but nothing displays it. Settings shows the constant "Stored locally on this device".
- Why it is a problem: the teacher opens the app and sees a single blank "New Assignment", because the JSON store is empty. All their classes appear to be gone. Anything they now enter goes into the JSON files, and when the database later opens again, that work is invisible: the data is split across two stores. This directly contradicts the repo rule "fail openly rather than silently faking success" (AGENTS.md). The silent `try?` also throws away the actual error.
- Evidence:
  ```swift
  } else if let dbStore = try? GRDBAssignmentStore(fileManager: fileManager) {
      resolvedStore = dbStore
  } else {
      resolvedStore = LocalJSONStore(fileManager: fileManager)
      resolvedMode = "JSON file-backed storage (GRDB unavailable)"
  ```
- Recommended fix: remove `LocalJSONStore` as a runtime store. On database open or migration failure, show a blocking "Your local records could not be opened" screen with the real error, a retry option and "Export a copy of the database file". Do not continue with an empty store. Keep an in-memory GRDB `DatabaseQueue()` for tests and previews instead of a second persistence implementation. GRDB supports in-memory queues, so the 591-line JSON store and its sidecar rollback logic (`LocalJSONStore.swift:137-148, 186-207`) can be deleted. Move `MarkdownReportBuilder` (which lives in the same file, line 266 onward) to `Export/`.
- Effort: M. Low risk, because no users exist yet.
- Confidence: High.

### A-05 — High — Every save rewrites every assignment twice (JSON copy plus normalized rows), on the main thread
- Area / files: `Persistence/Database.swift:69-90, 198-218, 334-367`; `GradeDraftViewModel+AssignmentPersistence.swift:110-122`; `docs/ledgers/DECISIONS_LEDGER.md` D003
- What it is now and why: `saveCurrentAssignment()` calls `store.saveAssignments(assignments)` with the **whole** array. For each assignment, the database encodes the full record to pretty-printed, sorted-key JSON and upserts it into `grade_draft_assignment_records`. Then `saveNormalizedAssignment` deletes every child row of that assignment from 12 tables and re-inserts them all. D003 justifies keeping the JSON copy as "a lossless escape hatch during migration".
- Why it is a problem:
  - **Cost:** a teacher with 6 classes × 28 students has about 170 assignment records. Confirming one OCR line rewrites about 170 JSON documents and thousands of rows, synchronously on the main actor (the view model is `@MainActor` and `GradeDraftDatabase` is called directly). 46 call sites save.
  - **Two sources of truth:** load prefers normalized rows whenever any exist (`Database.swift:60-66`). The per-entity APIs (`saveFinalReview`, `saveOCRDocument`, `saveEvidenceReferences`, `saveSourceInputs`, lines 220-247) update rows **without** updating the JSON copy, so the "lossless escape hatch" diverges as soon as they are used. Today only tests call them (see A-17).
  - **The rationale has expired:** there is no released schema to migrate from (README:143 lists TestFlight as a future gate), so the escape hatch protects no data.
- Evidence:
  ```swift
  // Database.swift:79-89, inside a loop over ALL assignments
  let payload = try jsonEncoder.encode(assignment)
  … INSERT INTO grade_draft_assignment_records … ON CONFLICT(id) DO UPDATE …
  try saveNormalizedAssignment(assignment, in: db)   // DELETE + re-INSERT 12 tables
  ```
- Recommended fix: pick one representation and save only what changed. For this app I recommend:
  - **(a) Normalized GRDB records.** Each table gets a `Codable` struct conforming to `FetchableRecord, PersistableRecord`, foreign keys use `ON DELETE CASCADE`, and an edit writes only the affected row(s) (for example a single `OCRLine.update(db)`).
  - **(b) Simpler alternative if the team wants minimal code:** one `submissions` table holding a JSON document per submission plus a few indexed columns (class ID, student ID, status, updatedAt), and write only the edited submission.
  
  Either way, delete the second representation and the `migrateLegacyPayloads` machinery. Update D003 in the decisions ledger to record the reversal.
- Effort: M–L. Medium risk; the existing round-trip tests help.
- Confidence: High.

### A-06 — Medium — About 23 database tables are created but never used, and the docs present them as the schema
- Area / files: `Persistence/Database.swift:830-865` (`createProductTables`); `docs/DATA_MODEL_V3.md:93-107`; `docs/ARCHITECTURE.md` "Persistence posture"
- What it is now: `createProductTables` creates `student_work, source_inputs, pdf_sources, ocr_lines, ocr_line_revisions, rubrics, rubric_criteria, rubric_levels, teacher_instructions, answer_keys, expected_elements, exemplars, curriculum_items, curriculum_mappings, grading_packets, grade_proposals, grade_proposal_criteria, teacher_reviews, final_reviews, final_review_criteria, evidence_references, export_records, audit_events, backup_restore_events`. A grep for `INSERT INTO`/`FROM` in the app shows **none of these are ever read or written**. Only `class_groups, students, class_students, assignment_roster_entries, ocr_documents, ocr_pages` and the `grade_draft_*` tables are live.
- Why it is a problem: this is "theatre". The schema looks fully normalized (rubrics, criteria, levels, grading packets, line revisions), but the real data lives elsewhere: rubric as `rubric_text` plus a JSON column, OCR lines in `grade_draft_ocr_lines`. DATA_MODEL_V3 lists the dead tables as the normalized schema. It also says the `grade_draft_` tables "preserve legacy assignment payloads", which is backwards: they are the live tables. Future developers or agents will write to the wrong tables. `ocr_line_revisions` suggests an OCR correction history exists; none is recorded.
- Evidence: `grep -o "INSERT INTO [a-z_]*\|FROM [a-z_]*" Persistence/Database.swift` lists only the live tables (output captured during review).
- Recommended fix: drop the unused tables (pre-release, so squash into a new v1 schema; see A-07). Rewrite DATA_MODEL_V3 to describe the actual tables. If a real OCR correction history is wanted, that is a product decision (see Questions).
- Effort: S. Low risk.
- Confidence: High.

### A-07 — Medium — The migration history can't be relied on, and the schema has no foreign keys or indexes
- Area / files: `Persistence/Database.swift:756-797` (migrations), `799-865` (table builders), `873-883` (`migrateLegacyPayloads`)
- What it is now: migrations 001, 002, 003, 006, 007 and 008 each call the **current** `createCoreTables` / `createProductTables` functions with `CREATE TABLE IF NOT EXISTS`, then patch columns with `addColumnIfNeeded`. Migrations 006, 007 and 008 each re-run `migrateLegacyPayloads`, which decodes with today's `AssignmentRecord` decoder and silently skips failures (`if let assignment = try? …`). Tables use TEXT UUIDs and ISO-8601 TEXT dates, with no `FOREIGN KEY`, no `ON DELETE CASCADE`, and no index on any `assignment_id` column. Cascades are hand-written as delete lists (`deleteAssignmentRows`, `deleteLocalDataGraph`, lines 738-754 and 323-333).
- Why it is a problem:
  - GRDB's model is that a registered migration is an immutable snapshot. Here, editing `createCoreTables` silently changes what "migration 001" means for a fresh install versus an upgraded one, so the two can end up with different schemas.
  - Silent `try?` in the legacy migration loses records without telling anyone.
  - Without foreign keys, orphan rows are possible. The codebase already had to fix "orphan roster rows after student deletion" (commit 9b3552b).
  - Without indexes, every per-assignment child query is a full table scan. Combined with the per-assignment N+1 load (A-13), launch time grows quadratically with data.
- Evidence: `migrator.registerMigration("006_all_features_completion_v3") { db in try self.createCoreTables(in: db); try self.createProductTables(in: db); … try self.migrateLegacyPayloads(in: db) }`.
- Recommended fix: before first release, replace all migrations with one `"v1"` migration written with GRDB's schema DSL (`db.create(table:) { t in t.belongsTo("submission", onDelete: .cascade) … }`, which adds the foreign key and index). Freeze it, and append new migrations only. Turn on `Configuration.foreignKeysEnabled` (the default) and set `migrator.eraseDatabaseOnSchemaChange = true` in DEBUG builds only. Docs: [GRDB Migrations](https://swiftpackageindex.com/groue/grdb.swift/documentation/grdb/migrations).
- Effort: M. Low risk pre-release.
- Confidence: High.

### A-08 — High — Bad or unreadable stored values are silently replaced with defaults, some of which skip the scanned-text review gate
- Area / files: `Persistence/Database.swift:887-919` (row helpers), `466-517` (assignment load), `550-640`; `Models/GradeDraftClassroomModels.swift:129-165`
- What it is now and why: the loaders use forgiving helpers so that loads never throw:
  - `uuid(row,col)` returns a **new random UUID** if the stored text is bad (line 909).
  - `date()` returns **now** (line 911).
  - Assignment `ocr_review_status` falls back to `.notNeeded` (line 498).
  - `FinalReviewStatus` falls back to `.inProgress`, `ExportKind` to `.teacherAuditMarkdown`, and `AuditEventType` to `.inputChanged`.
  - `decodeJSONString` returns empty arrays on any decode error (line 892).
  
  The hand-written `AssignmentRecord.init(from:)` uses `(try? …) ?? []` for `exportRecords`, `auditEvents`, `evidenceReferences`, `curriculumMappings`, `sourceInputs` and `appliedTemplates`. One bad element empties the whole list.
- Why it is a problem:
  - (1) Falling back to `.notNeeded` is fail-open on a core rule: an assignment whose stored status can't be read becomes grade-ready without scanned-text review (AGENTS.md Definition of Done: low-confidence OCR lines require teacher action).
  - (2) A random replacement UUID breaks the link between OCR lines and evidence, so evidence silently points at nothing.
  - (3) Dropped arrays are written back on the next save (A-05 rewrites everything), so a single decode problem permanently deletes the audit trail and export history. This contradicts the repo rule to fail openly.
- Evidence:
  ```swift
  // Database.swift:498
  ocrReviewStatus: OCRReviewStatus(rawValue: text(row, "ocr_review_status")) ?? .notNeeded,
  // Database.swift:909
  private func uuid(_ row: Row, _ column: String) -> UUID { UUID(uuidString: text(row, column)) ?? UUID() }
  // GradeDraftClassroomModels.swift:157
  auditEvents = (try? container.decode([AuditEvent].self, forKey: .auditEvents)) ?? []
  ```
- Recommended fix: throw `GradeDraftDatabaseError.dataCorrupted` and surface the blocking error screen from A-04. Using GRDB `Codable` records (A-05) does this automatically: a bad enum raw value throws. If tolerance is truly wanted for an enum, decode unknown values to a conservative state: `.needsReview` for OCR, `.stale` for final review. Pre-release, delete the hand-written `Codable` (about 75 lines) and use the synthesized one; the "backward-compatible prompt field" comment protects no stored data.
- Effort: S–M. Low risk.
- Confidence: High.

### A-09 — High — Backup restore can delete the teacher's original files and then report a full rollback
- Area / files: `Export/BundleExportService.swift:437-451`; `GradeDraftViewModel+BackupRestore.swift:134-225`; `GradeDraftViewModel+StudentWorkImport.swift:294-300`
- What it is now: with "Replace local", the archive's source files are extracted over the live `Sources/<assignmentID>/…` files (`removeItem` on the existing file, then `extract`) **before** the database snapshot commits. If `store.replaceLocalDataSnapshot` then throws, the catch block calls `cleanupRestoredSourceFiles`, which deletes the newly restored files. The teacher's original files were already removed, so they are gone. The database is rolled back and still points at them. The status message then says everything was rolled back.
- Why it is a problem: decision D013 promises coherent restore. The database part is atomic (one GRDB write transaction), but the file part is not, and the message to the teacher is false. That is fake completion on a data-loss path.
- Evidence:
  ```swift
  // BundleExportService.swift:441-442
  if fileManager.fileExists(atPath: item.destination.path) { try fileManager.removeItem(at: item.destination) }
  _ = try archive.extract(item.entry, to: item.destination)
  // BackupRestore.swift:221-224
  cleanupRestoredSourceFiles(restoredSourceRelativePaths)
  reloadFromStoreAfterPersistenceFailure()
  statusMessage = "Restore failed. Local data and original files were rolled back to their previous state."
  ```
- Recommended fix: extract into a staging folder (`Sources-restore-<uuid>`). Commit the database transaction. Then move files into place with `FileManager.replaceItemAt(_:withItemAt:backupItemName:options:)`, which keeps a backup until the swap succeeds. On a database failure, delete only the staging folder. Change the message so it is only shown when the claim is true.
- Effort: M. Low risk.
- Confidence: High (code path). The failure is rare: it needs a database write error after extraction.

### A-10 — Medium — The data model has no class-level assignment: every student's record carries its own copy of the rubric, and classes are matched by name text
- Area / files: `Models/GradeDraftClassroomModels.swift:6-42`; `GradeDraftViewModel+RubricCurriculumRoster.swift:377-470` (roster creation copies the template), `166-176`; `UI/Screens/ScreenModels.swift:75-81, 97-110`
- What it is now and why: `AssignmentRecord` is really "one student's submission". It holds the student (`studentID`, `studentDisplayName`), the class (`classGroupID`, **and** `className` text), and the full grading setup (`rubricText`, `confirmedParsedRubric`, `customInstructions`, `answerKeyText`, `exemplarText`, `selectedInstructionTemplateIDs`). Roster import clones the current record once per student (`var copy = template`, line 409). Class pages group records by `className` text (`ClassSummary.id = name.lowercased()`; `classAssignments(for className:)`), even though `ClassGroupRecord` has a UUID. Student names are stored in three places: `StudentRecord.displayName`, `AssignmentRecord.studentDisplayName` and `AssignmentRosterEntry.studentDisplayName`. The app most likely began as a single-student scratchpad, and roster features were bolted on later.
- Why it is a problem:
  - Fixing a rubric typo after creating 28 roster copies means editing 28 records. Each edit marks drafts stale and re-fingerprints.
  - Renaming a class or student leaves the old name on existing records. Two classes with the same name in different years merge on the Classes screen.
  - `reconciledRosterEntries` (about 50 lines, `RubricCurriculumRoster.swift:588-636`) and the restore merge logic exist largely to keep these copies consistent.
- Evidence: `RubricCurriculumRoster.swift:409-421` (`var copy = template; copy.id = UUID(); copy.className = classGroup.name; copy.studentDisplayName = savedStudent.displayName`).
- Recommended fix: introduce the domain shape teachers already use:
  - `ClassGroup(id)` 1—* `Enrollment` *—1 `Student(id)`
  - `ClassGroup` 1—* `Assignment(id, classGroupID, title, prompt, rubric, instructions, answerKey, exemplar, constraints)`
  - `Assignment` 1—* `Submission(id, assignmentID, studentID, sources, ocrDocument, reviewedText, draft, finalReview, evidence, exports, audit)`
  
  Display names are joined at read time. Roster status becomes a computed property of a submission, not a stored table. The grading-packet fingerprint combines the assignment's setup with the submission's reviewed text.
- Effort: L. This is the biggest structural change; it is cheap only before release.
- Confidence: High.

### A-11 — Medium — The same facts are stored in two or three places and kept in step by hand
- Area / files: `Models/GradeDraftClassroomModels.swift:29-33` vs `Models/GradeDraftOCRModels.swift:106-141`; `GradeDraftViewModel+OCRReviewEvidence.swift:28-43, 273-277`; `Models/GradeDraftGradingModels.swift:97-105, 193-202`; `Models/GradeDraftClassroomModels.swift:840-850`; `GradeDraftViewModel+RoutingStatus.swift:232-245`
- What it is now:
  - The scanned-text review status and review time live on both `AssignmentRecord` (`ocrReviewStatus`, `ocrReviewedAt`) and `OCRDocument` (`reviewStatus`, `reviewedAt`).
  - `reviewedStudentText` is a stored copy of `ocrDocument.combinedText`. `applyOCRReviewState` exists to copy one onto the other.
  - Roster status is stored in `assignment_roster_entries.status`, but it is also derivable at any time from the record (`assignmentRosterStatus(for:)`).
  - Evidence is represented three ways: `EvidenceReference` objects on the assignment, `evidence: [String]` quotes on each criterion, and `evidenceSourceRefs: [String]?` strings that embed `"evidence:<uuid>"` and are parsed back with a regex (`evidenceID(in:)`). `sourceKind` is a free `String`, not an enum.
- Why it is a problem: every mutation path must update all copies. One missed update gives contradictory state: for example the document reviewed but the assignment still "needs review", or a criterion quoting evidence that was removed. Index-based removal (`removeEvidenceFromFinalReview(criterionID:evidenceIndex:)`) over parallel arrays is fragile.
- Recommended fix: store each fact once and compute the rest:
  - The review status lives on `OCRDocument`. For pasted text with no document, use an explicit `.notNeeded` case.
  - `reviewedStudentText` is computed from the document, and stored only for pasted text.
  - Roster status is computed.
  - A criterion holds `evidenceIDs: [EvidenceReference.ID]`, a typed relation (a join table in the database), and `sourceKind` becomes an enum.
- Effort: M. Covered by the round-trip tests.
- Confidence: High.

### A-12 — Medium — A 30-property ObservableObject observed by every screen; use @Observable (available at iOS 17)
- Area / files: `GradeDraftViewModel.swift:6-46`; `ContentView.swift:3-8`; 19 files using `@ObservedObject`/`@StateObject`
- What it is now: `@MainActor final class GradeDraftViewModel: ObservableObject` with 30 `@Published` properties, split across 9 extensions (about 2,900 lines in total). Every screen holds `@ObservedObject var viewModel`. `ContentView.init(viewModel: GradeDraftViewModel = GradeDraftViewModel())` evaluates the default argument eagerly at each call. The `StateObject` autoclosure only protects the wrapped value, so each time `GradeDraftApp.body` is re-evaluated, a throwaway view model is built: it opens the database, runs the migrator and loads every assignment.
- Why it is a problem:
  - With `ObservableObject`, any `@Published` change (for example `statusMessage`, which changes on almost every action, or `aiGenerationProgress` during a draft) redraws every view observing the object, across all tabs in the stack.
  - The deployment target is iOS 17, so the Observation framework is available. `@Observable` tracks the individual properties each view reads.
  - A single "god object" spread across extensions is not modular. Extensions share all state, so nothing enforces boundaries, and tests must construct the whole thing.
- Evidence: `GradeDraftViewModel.swift:7` `final class GradeDraftViewModel: ObservableObject {`; `ContentView.swift:6` `init(viewModel: GradeDraftViewModel = GradeDraftViewModel())`.
- Recommended fix:
  - Migrate to `@Observable` with `@State` ownership in `GradeDraftApp`: create the model once in an `@State` on the `App`. Use `@Bindable` in views ([Apple migration guide](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)).
  - Split by feature:
    - `AppModel`: lists, selection-free navigation, settings and device-backup policy.
    - `AssignmentSession` per route (A-02).
    - `RosterModel`: classes, students and roster import.
    - `BackupRestoreModel`: staging, preview, confirm.
    - `CurriculumBrowserModel`: the 7 curriculum filter properties currently on the main view model.
  - Inject the store and services through the environment.
- Effort: L, together with A-02. Medium risk.
- Confidence: High.

### A-13 — Medium — All database work runs synchronously on the main thread, using GRDB 6 (capped below the current major version)
- Area / files: `Persistence/Database.swift:28-49, 60-66, 466-517`; project requirement `GRDB.swift upToNextMajorVersion 6.0.0` (`GradeDraft.xcodeproj/project.pbxproj:1149`)
- What it is now: a single `DatabaseQueue`, called synchronously from the `@MainActor` view model. Launch loads every assignment with about 9 queries per assignment (sources, OCR document, pages, lines, draft and its criteria, final review and its criteria, evidence, mappings, exports, audit), an N+1 pattern with no indexes (A-07). The package is pinned to 6.x.
- Why it is a problem: launch time and save time grow with the teacher's data and block the UI. GRDB 7 (latest v7.12.0) needs Swift 6 and Xcode 16 or later, which the project already uses. It adds:
  - full Swift 6 concurrency annotations;
  - async `read`/`write` that respect task cancellation and roll back cleanly;
  - IMMEDIATE write transactions by default;
  - `ValueObservation` that delivers on the main actor by default.
  
  Source: [GRDB 7 migration guide](https://github.com/groue/GRDB.swift/blob/master/Documentation/GRDB7MigrationGuide.md). The breaking changes that affect this code are small: no `Record` subclasses are used, and `CSQLite` is not referenced.
- Recommended fix:
  - Bump the requirement to `from: "7.0.0"` and commit `Package.resolved`.
  - Switch to `DatabasePool` (WAL mode, concurrent reads).
  - Make store methods `async` and call `try await dbPool.write { … }` from the model.
  - Load lists with one query per table (`WHERE submission_id IN (…)`) or GRDB associations (`including(all:)`).
  - Optionally drive list screens with `ValueObservation`, or with [GRDBQuery](https://github.com/groue/GRDBQuery) (latest 0.11.0) `@Query`, so the UI updates after restore or import without manual array syncing (`reloadFromStoreAfterPersistenceFailure`).
- Effort: M. Low–medium risk.
- Confidence: High for the facts. The size of the speed gain is not measured.

### A-14 — Medium — Staleness fingerprints are recomputed by JSON-encoding whole records, repeatedly, inside list rendering
- Area / files: `Content/GradingPacketBuilder.swift:866-883`; `Models/GradeDraftClassroomModels.swift:230-250`; `GradeDraftViewModel+RoutingStatus.swift:232-245`; `UI/Screens/ScreenModels.swift` (`v6Status`, `reviewItems`)
- What it is now: `gradingPacketFingerprint` builds the full grading packet, JSON-encodes it with sorted keys and hashes it, on every access. `finalReviewIsStale` copies the entire record, clears its evidence and fingerprints the copy. `latestDraftIsStale`, `finalReviewIsStale`, `isStudentFacingExportReady` and `assignmentRosterStatus` call these, and they run for **every row** of the Home, Review, Assignments and Class lists on every redraw (and with A-12, redraws are frequent). `updateAssignment` computes two fingerprints before and two after every mutation.
- Why it is a problem: this is CPU work proportional to students × redraws, including re-parsing the rubric (`parsedRubric` calls `RubricParser.parse` in `.automatic` mode). Also, `(try? encoder.encode(gradingPacket)) ?? Data()` means that any encode failure gives every record the same "empty" fingerprint. Staleness would then silently read as "not stale".
- Recommended fix: compute the fingerprint once per mutation and store it, using the existing `grading_packet_fingerprint` column. Compute `isStale` by comparing stored strings. Make the encode throw instead of returning empty data.
- Effort: S–M. Low risk.
- Confidence: High for the mechanism. The scale of the cost is not measured.

### A-15 — Medium — Shortcuts run while the app is already open are not handled until the next cold launch
- Area / files: `AppRouting.swift:83-156`; `UI/AppShell/AppTabShell.swift:52, 176-181`; `AppIntents/GradeDraftAppIntents.swift:139-280` (`openAppWhenRun = true`)
- What it is now: each intent writes a request to `UserDefaults` (payload text goes to a protected file with a 15-minute time limit). The app reads it once, in `AppTabShell`'s `.task`, which runs only when that view first appears.
- Why it is a problem: if MarkForMe is already running in the background, running "Open final review" from Shortcuts brings the app forward, but `.task` does not run again, so nothing happens. The request stays pending and fires at some later cold launch, possibly hours later. The 15-minute limit covers only the payload file, not the request itself. A later surprise action (for example "create assignment shell") is the opposite of fail-closed.
- Recommended fix: deliver intents directly instead of polling.
  - On iOS 26 and later, adopt `TargetContentProvidingIntent` and handle the intent with SwiftUI's `.onAppIntentExecution(_:perform:)` ([Apple: Directing app intents to your app's scenes](https://developer.apple.com/documentation/appintents/directing-app-intents-to-your-apps-scenes)). Confirm the exact availability annotation in Xcode.
  - For the iOS 17–25 range (deployment target 17.0), mark `perform()` `@MainActor` and call a navigator registered with `AppDependencyManager.shared.add { navigator }` / `@Dependency`, or at minimum re-run `consumePendingLaunchRequest()` on `scenePhase == .active`.
  - Add an expiry to the request itself.
- Effort: S–M. Low risk.
- Confidence: High for the `.task` behaviour; the API availability needs checking in Xcode as noted.

### A-16 — Low — A fake blank "New Assignment" is created when there is no data, and "saved" checks only test memory
- Area / files: `GradeDraftViewModel.swift:79, 84`; `GradeDraftViewModel+AssignmentPersistence.swift:42-44, 171`; `GradeDraftViewModel+RoutingStatus.swift:258-280`
- What it is now: on first launch, on load failure, after deleting the last assignment, and on reload, the app inserts an unsaved `AssignmentRecord()` placeholder. On load failure the placeholder also hides the failure. `currentSavedAssignmentForAction` and `selectAssignment` report "not saved on this device" based only on in-memory array membership, so the placeholder passes as "saved".
- Why it is a problem: the error messages claim to have checked persistence when they didn't. A placeholder that looks like real data is the kind of fake state the repo's guardrail forbids.
- Recommended fix: show an empty state (`ContentUnavailableView("No assignments yet", …)` with a "New assignment" button) instead of inventing a record. Rename the check to describe what it actually checks. A-02 removes it anyway.
- Effort: S.
- Confidence: High.

### A-17 — Low — The storage interface has 20 methods, and half of them are used only by tests
- Area / files: `Services/LocalJSONStore.swift:22-42`; `Persistence/GRDBAssignmentStore.swift:26-52`; `Persistence/Database.swift:220-269`
- What it is now: the app uses only `loadAssignments`, `saveAssignments`, `loadClassGroups`, `loadStudents`, `loadAssignmentRosterSnapshot`, `replaceLocalDataSnapshot` and `applicationSupportDirectory`. These are used only from tests: `saveSourceInputs`, `saveOCRDocument`, `saveFinalReview`, `saveEvidenceReferences`, `loadFullAssignmentGraph`, `saveClassGroup`, `saveStudent`, `deleteAssignment`, `deleteStudent`, `deleteClassGroup`, `loadAssignmentRoster`, `replaceAssignmentRosterSnapshot`. `preflightAuditBundle` and `readBackupDescriptor` are used nowhere. The test-only per-entity methods also bypass the JSON copy (A-05).
- Why it is a problem: tests exercise code paths the app never takes, so a passing test proves nothing about the shipped behaviour. Each implementation must maintain double the surface.
- Recommended fix: shrink the protocol to what the app calls, or better, redesign it around the operations from A-02 and A-05 (`submission(id:)`, `save(_ submission:)`, `replaceAll(_ snapshot:)`). Delete the unused methods and their tests.
- Effort: S.
- Confidence: High (grep counts captured during review).

### A-18 — Low — Error handling is one string slot, with misleading types and string-matching
- Area / files: `GradeDraftViewModel.swift:12`; `GradeDraftViewModel+Utilities.swift:358, 363`; `GradeDraftViewModel+DraftFinalReview.swift:120`; `GradeDraftViewModel+AssignmentPersistence.swift:167-183`
- What it is now:
  - One `errorMessage: String?` drives a single global alert, so a second error overwrites the first.
  - `GradeDraftError.persistenceFailed` is used for non-persistence failures, such as reading a curriculum file or an XLSX (Utilities:358, 363).
  - Cancellation is detected with `error.localizedDescription.localizedCaseInsensitiveContains("cancel")`. That breaks under localization and misreads any error whose text contains "cancel".
  - After any failed save, `reloadFromStoreAfterPersistenceFailure()` reloads **everything** from disk. That discards unsaved in-memory edits on all assignments, for example typed but unsaved overview fields, even when the failed save was an unrelated class edit.
- Recommended fix: use typed errors per feature, `catch is CancellationError` (GRDB 7 and Foundation Models both throw it), and per-screen error state. With A-05's per-row writes, roll back only the failed entity.
- Effort: S–M.
- Confidence: High.

### A-19 — Low — UI-test fixture data and launch-argument switches ship in the release app
- Area / files: `GradeDraftApp.swift:7-16, 23-80`
- What it is now: the `--ui-core-lane-test` and `--ui-smoke-test` arguments swap in fixture records, including a fake approved review, in every build.
- Why it is a problem: it is low risk, because launch arguments can't be set on a user's device without tooling. But test scaffolding inside the production entry point is avoidable, and the fixture includes a pre-approved final review.
- Recommended fix: wrap the switches and fixtures in `#if DEBUG`, or move them into the UI-test target using a launch-environment-selected in-memory store.
- Effort: S.
- Confidence: High.

### A-20 — Low — The assignment list re-sorts on every edit, so rows jump while the teacher works
- Area / files: `GradeDraftViewModel+AssignmentPersistence.swift:124-133`
- What it is now: `upsertAssignment` sets `updatedAt = Date()` (even when nothing changed) and re-sorts the whole array by `updatedAt` on every mutation, including per-keystroke binding writes.
- Why it is a problem: the record being edited jumps to the top of lists. The sort also costs O(n log n) per keystroke, and `updatedAt` stops meaning "last real change".
- Recommended fix: only bump `updatedAt` when the record actually differs. Sort in the view, or in the database query, with `SortDescriptor`.
- Effort: S.
- Confidence: High.

### A-21 — Low — Hand-written XLSX reading strips XML tags with a regex
- Area / files: `GradeDraftViewModel+Utilities.swift:349-379`
- What it is now: for curriculum and reference imports, the app opens the XLSX with ZIPFoundation, concatenates **every** `.xml` part (styles, theme, docProps and so on), regex-removes tags and decodes 4 entities.
- Why it is a problem: the result mixes cell text with style and metadata noise and loses cell and row structure. Numeric and inline-string cells are wrong. This is parsing logic that does not belong in a view model.
- Recommended fix: if XLSX import is kept, use [CoreXLSX](https://github.com/CoreOffice/CoreXLSX) (latest 0.14.2, MIT; note it has a low release cadence). It reads `sharedStrings` and worksheets properly. Alternatively drop XLSX and accept CSV only, using the existing `CSVCodec`. Either way, move the code out of the view model.
- Effort: S.
- Confidence: Medium. I confirmed the package and version exist; I did not review how teachers actually use this import.

---

## SwiftData vs GRDB for this app (honest judgement)

**Keep GRDB and upgrade it to v7. SwiftData would be worse here.** Reasons specific to MarkForMe:
- **Restore has to be all-or-nothing** (D013): "replace everything, or nothing". GRDB gives an explicit SQLite transaction (`dbPool.write { … }`). SwiftData's `ModelContext.save()` covers the context, but bulk replace-all with conflict remapping, and running it against a temporary store for preview, is awkward. Its history of migration and crash issues across iOS 17 and 18 makes it riskier for a teacher's only copy of their grades.
- **The JSON audit records need exact control** of how they are encoded and fingerprinted. That is easier with explicit `Codable` records than with `@Model` classes.
- **Existing logic expects value types.** The grading pipeline (fingerprints, validators, "copy and compare" staleness) is built around structs. SwiftData models are reference types, which would force rewriting that logic.
- **SwiftData's main advantage doesn't apply.** Its strength is automatic SwiftUI `@Query` updating and CloudKit sync, and CloudKit sync is forbidden by product rule. GRDB's `ValueObservation`/GRDBQuery gives the same live-query benefit.
- **The current design problems are not GRDB's fault.** They are the triple storage, the dead tables and the hand-rolled SQL. Fix them inside GRDB with `Codable` records (`FetchableRecord & PersistableRecord`).

## Is one view model split across extensions the right architecture?

No. The extensions are cosmetic: they share one bag of state and one implicit "selected assignment". The modern shape for this app:
- an `@Observable` `AppModel` for app-level lists and navigation;
- per-route `@Observable` feature models keyed by an ID (submission review, final review, export, backup/restore, curriculum browser, roster);
- an `async` store protocol backed by GRDB 7, injected through the environment.

Services already sit behind protocols (`OCRServicing`, `GradingServicing: Sendable`, `ExportAuthenticationServicing`). That part is good and makes the new models easy to test. Swift 6 language mode is on (`SWIFT_VERSION = 6.0`) and the `@MainActor` annotations are consistent. The concurrency gap is that I/O runs *on* the main actor, not that the code is unsafe.

## Keep (good as is)
- **Service protocols and injection** in the view model's init (`GradeDraftViewModel.swift:48-55`), and `GradingServicing: Sendable` plus the `@MainActor @Sendable` progress handler type (`Services/GradingService.swift:12-17`). Clean and testable.
- **Snapshot-style atomic database writes** for destructive operations (`replaceLocalDataSnapshot` in one GRDB transaction, D013), and write-before-publish ordering (persist, then assign `@Published`) in roster, delete and restore. Keep the principle when moving to per-row writes.
- **The staleness concept** (stored packet fingerprint on the draft and the final review, with student-facing export blocked when stale). It is the right product rule; only its computation needs caching (A-14).
- **The restore preview, fingerprint re-check before confirm** (`BackupRestore.swift:72-86`), and the safe source-path resolution.
- **`MissingAssignmentRouteView`** using `ContentUnavailableView` (`ScreenModels.swift:3-15`). It is the correct native component for the not-found state.
- **File protection and backup exclusion** applied to the database, WAL and SHM files (`Database.swift:44-48`).

## Out of area
- The test suite is 100% XCTest (37 `XCTestCase` files, 0 using `import Testing`). Swift Testing is the current framework (Area D or tests reviewer).
- PDF page rendering and digital-text extraction run on the main actor inside the view model extension (`GradeDraftViewModel+StudentWorkImport.swift:247-290`). That belongs in a background service (import/OCR reviewer).
- `MarkdownReportBuilder` is a hand-built Markdown string builder living inside `LocalJSONStore.swift:266+` (export reviewer).
- `AppTabShell` duplicates `.navigationDestination(item: $launchRoute)` on 6 stacks, and one `launchRoute` state is shared across all tabs (`AppTabShell.swift:81-131`) (UI reviewer).

## Questions for the owner
1. **Is the app definitely pre-release, with no teacher data on any device?** If yes, I recommend squashing all migrations into one v1 schema, deleting the JSON copy and the JSON fallback store, and deleting the legacy-JSON restore path. If any pilot teacher has data, a one-time import is needed instead.
2. **Should an assignment be class-level, with one rubric shared by every student's submission (A-10)?** Or do you want teachers to tailor the rubric and instructions per student? This decides the shape of the new model.
3. **Do you want a real history of scanned-text corrections** (each teacher edit to a line kept, with time)? The unused `ocr_line_revisions` table implies it was intended, but nothing records it today.
