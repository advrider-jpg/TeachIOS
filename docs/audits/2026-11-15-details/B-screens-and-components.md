# Area B — User interface (SwiftUI screens, design system, navigation shell, accessibility)

Reviewer scope: `GradeDraft/UI/**`, `GradeDraft/Views/**`, `GradeDraft/Content/GradeDraftCopyCatalog.swift`, `GradeDraft/Resources/Assets.xcassets`, `scripts/ci/check_native_ui_refactor.py`, plus the app shell (`GradeDraftApp.swift`, `ContentView.swift`) and the view-model methods that UI bindings call directly. Read-only, reasoned from source at commit cd64e9d (no build possible on Windows).

## Summary

The UI has two layers fighting each other. A "native UI refactor" (enforced by a token-matching CI script) wrapped every screen in `List`/`Form`, but the older "stationery" look (cream paper, tape labels, perforations, paperclips) was kept by putting each screen's whole content into one or a few giant rows with backgrounds, separators and scroll backgrounds hidden. The result keeps the costs of both: native containers that give none of the native behaviour (lazy rows, swipe actions, selection, system materials), and a custom look that has no dark mode, is copy-pasted five-plus times with different palettes, and fights iOS 26/27 Liquid Glass. Separately, several data-flow problems surface in the UI: the Rubric editor runs the whole AI-readiness pipeline and a full database save on every keystroke, the Exports tab acts on a hidden "selected" assignment, and the final-review editor can silently discard teacher edits.

Counts: 2 Critical, 5 High, 9 Medium, 4 Low (20 findings).

---

### B-01 — Critical — Dark mode is broken: dark text colours land on fixed cream "paper"
- Area / files: `UI/DesignSystem/GradeDraftColors.swift:15-26`; `UI/DesignSystem/Cards.swift:122-131`; `UI/DesignSystem/Rows.swift:181-209, 218-255`; `UI/Screens/ClassesScreen.swift:198-224`; `UI/Screens/HomeScreen.swift:45,68,107`; `UI/DesignSystem/RubricComponents.swift:4-14,167-179`; `UI/Screens/AssignmentsScreen.swift:106-118`; `UI/Screens/FinalReviewScreen.swift:469-476`; `UI/Native/GradeDraftNativeModifiers.swift:13-18`; `Resources/Assets.xcassets` (only `AppIcon.appiconset`).
- What it is now and why: The "stationery" theme defines every surface as a fixed sRGB literal (`deskBackground: Color(red: 0.976, green: 0.941, blue: 0.855)`, `paper: Color(red: 1.0, green: 0.985, blue: 0.938)`). It was designed as a light-only paper look. There is no asset-catalog colour, no dark variant, no `AccentColor`, and no light-mode lock (`preferredColorScheme`, `UIUserInterfaceStyle` — zero matches in source, Info.plist or project).
- Why it is a problem: In dark mode the system flips `.primary`/`.secondary` text to white/light grey, but the cards stay cream. Many rows draw with default system text colours on top of the fixed paper — e.g. `ClassRow` (`Rows.swift:190-197`, `.font(.headline)` with no foreground → `.primary`) inside `NotebookCard` (`Cards.swift:125` `.fill(theme.paper)`); `AssignmentRow`, `ReviewQueueRow`, `StudentRow`, `WorkAttachmentRow` the same. White-on-cream is close to 1:1 contrast — unreadable. `TextEditor` hides its own background (`RubricComponents.swift:175` `.scrollContentBackground(.hidden)`) so the rubric text the teacher types becomes white on cream. 15 rows add `Color.white.opacity(0.34)` washes. Teachers grading in the evening on a dark-mode iPad will hit this on the Home, Classes, Assignments, Rubric and Final Review screens. App Review and accessibility (Smart Invert, Increase Contrast) are also affected.
- Evidence: `GradeDraftColors.swift:16-17`; `Cards.swift:125` `.fill(theme.paper)`; `Rows.swift:190-197` text without foreground style; `HomeScreen.swift:45` `.background(Color.white.opacity(0.34), ...)`; `grep preferredColorScheme|UIUserInterfaceStyle` → 0; `Assets.xcassets` contains only `AppIcon.appiconset`.
- Recommended fix: Remove the hard-coded palette. Either (a) go native: `Color(.systemGroupedBackground)`, `Color(.secondarySystemGroupedBackground)`, `.primary`, `.secondary`, `.tint` — which also adopt Liquid Glass and Increase Contrast automatically; or (b) if a branded look is wanted, define a small set of Color Sets in `Assets.xcassets` with Any/Dark and High-Contrast variants (Xcode generates type-safe `Color(.paper)` symbols since Xcode 15) and an `AccentColor` set. Deletes ~55 `Color(red:)` literals across 7 files.
- Effort: M (touches every screen); risk is visual churn only.
- Confidence: High (mechanism is deterministic: fixed fill + adaptive foreground).

### B-02 — Critical — "Native List/Form" screens are a facade: whole screens live in one giant row
- Area / files: `UI/Screens/AssignmentsScreen.swift:11-65`; `UI/Screens/HomeScreen.swift:7-115`; `UI/Screens/ClassesScreen.swift:8-59`; `UI/Screens/ClassDetailRosterScreen.swift:123,214`; `UI/Screens/RubricInstructionsScreen.swift:61-87`; `UI/Screens/FinalReviewScreen.swift:13-348`; `scripts/ci/check_native_ui_refactor.py:28-57`.
- What it is now and why: The CI script requires the literal tokens `List {`/`Form {` and `.searchable`, and forbids the token `ScrollView`. Screens satisfied it by wrapping the old stationery `ScrollView` content in a `List`/`Form` — but each card (containing a `LazyVStack` of every item) is a single row. `AssignmentsScreen` is one `List` row: a `PaperStack` card holding a `LazyVStack` of every assignment (`35-59`). `RubricInstructionsScreen` is a `Form` with one `Section` holding one row containing the entire eight-section page and all its text editors (`61-87`). `FinalReviewScreen` puts the whole final-review editor (all criteria, two `TextEditor`s) in one row (`153-214`) with `.listRowBackground(Color.clear)` and `.listRowSeparator(.hidden)` on every section.
- Why it is a problem: (1) No laziness — a `LazyVStack` inside one List cell is laid out in full, and the List can't recycle anything; a class with hundreds of assignments renders them all. (2) No native row behaviour: no `.swipeActions` (0 in codebase), no edit mode/delete, no `List(selection:)`, no row highlight, no keyboard focus navigation on iPad. (3) Typing in a `TextEditor` inside a giant cell forces the whole cell to re-measure on every keystroke, and keyboard avoidance/scroll-to-caret inside a single huge cell is unreliable. (4) The Rubric "Setup Checklist — tap a row to jump" feature calls `proxy.scrollTo(item.section)` (`RubricInstructionsScreen.swift:371`) on `.id`s that are nested inside the single row (`277-294`); List's scroll proxy targets rows, so the jump most likely cannot land on a section (Medium confidence — not runnable here). (5) The guardrail is satisfied in letter while defeated in intent (see B-15).
- Evidence: `AssignmentsScreen.swift:18` `PaperStack(...) {` … `35` `LazyVStack(spacing: 10) { ForEach(filteredAssignments)`; `RubricInstructionsScreen.swift:61-63` `Form { Section { RubricStationeryPage(`; `FinalReviewScreen.swift:24-26` repeated on each section.
- Recommended fix: Real rows. Example: `List { Section("Needs action") { ForEach(items) { item in NavigationLink(value: Route.assignment(item.id)) { AssignmentRow(item) } .swipeActions { … } } } }`. Rubric screen: one `Section(isExpanded:)` (iOS 17) per part, each field its own row (`TextField(axis: .vertical)` or `TextEditor` row), `LabeledContent` for read-only values. Final review: one `Section` per criterion with `Stepper`/`TextField` rows. `ContentUnavailableView` as `.overlay` when empty.
- Effort: L; risk: screenshot/UI tests keyed on text will need updating.
- Confidence: High for structure and loss of native behaviour; Medium for the scroll-to-section failure.

### B-03 — High — Every keystroke in the Rubric editor runs the AI readiness pipeline and saves all assignments
- Area / files: `UI/Screens/RubricInstructionsScreen.swift:819-837`; `GradeDraftViewModel+RoutingStatus.swift:63-86`; `GradeDraftViewModel+DraftFinalReview.swift:8-23`; `GradeDraftViewModel+RubricCurriculumRoster.swift:215-223`; `GradeDraftViewModel+AssignmentPersistence.swift:86-133`.
- What it is now and why: The text editors bind straight to view-model mutators so edits are "never lost". `rubricTextBinding.set` calls `selectAssignment` then `updateRubricText` on every character.
- Why it is a problem: per keystroke the chain is: `selectAssignment` → `clearPreparedExport()` + `refreshCapabilityStatus()` → Foundation Models `prewarmIfAvailable()` + `refreshAIReadiness()` → prompt budget plan + `AIReadinessAnalyzer.report` + `AIPacketPreviewBuilder.preview`; then `updateAssignment` computes both packet fingerprints twice, and if a draft exists **appends a `draftMarkedStale` audit event per keystroke** (`AssignmentPersistence.swift:97-100` — no "already stale" guard), re-sorts the whole array, then `persistOrSurfaceError()` → `store.saveAssignments(assignments)` with the entire array. On a real device with a long rubric this is visible typing lag, battery drain, and an audit trail polluted with hundreds of identical events per edit. The architecture doc says OCR edits are staged and committed on save/focus loss (`docs/ARCHITECTURE.md:80`), so the app already knows the right pattern; the rubric, instruction, answer-key and wizard fields don't use it (`binding(_:)` `819-827`, `GradeWizardView.swift:462-479`).
- Evidence: `RubricInstructionsScreen.swift:833-835` `set: { newText in viewModel.selectAssignment(assignmentID); viewModel.updateRubricText(newText) }`; `RoutingStatus.swift:84` `refreshCapabilityStatus()`; `RoutingStatus.swift:67,71`; `RubricCurriculumRoster.swift:222` `persistOrSurfaceError()`; `AssignmentPersistence.swift:117` `try store.saveAssignments(assignments)`.
- Recommended fix: Edit a local `@State` draft string; commit on `@FocusState` loss / `onSubmit` / leaving the screen, or debounce with `.task(id: draftText) { try? await Task.sleep(for: .milliseconds(600)); commit() }`. Make `selectAssignment` not trigger readiness/prewarm; compute readiness lazily when the readiness card is shown. Save only the changed assignment (persistence area). Only append the stale audit event on the transition to stale.
- Effort: M; risk: must still flush on background (`scenePhase`) so nothing is lost.
- Confidence: High (call chain read end to end).

### B-04 — High — The Exports tab exports whichever assignment was last touched, without saying which
- Area / files: `UI/Screens/ExportsRestoreScreen.swift:26-58, 212-213, 291-297`; `GradeDraftViewModel.swift:105-112`; `GradeDraftViewModel+Export.swift:27-49`.
- What it is now and why: The Exports tab root has no `assignmentID`. It uses `selectedAssignment ?? viewModel.assignment`, and `viewModel.assignment` returns the hidden `selectedAssignmentID` record, else `assignments.first`, else a blank `AssignmentRecord()`. The export itself runs on `selectedAssignmentID`. The screen never displays the target assignment's title or student.
- Why it is a problem: A teacher who last opened Student A's final review, then opens the Exports tab and taps "Student Report PDF", gets Student A's report — with nothing on screen telling them so. If nothing is selected, the confirmation sheet previews `assignments.first` (`213`) while the export guard rejects the action — preview and action disagree. For a privacy-focused app this is a wrong-student disclosure risk, and it sits awkwardly with the repo rule that routes must not act on "the currently selected assignment as a fallback" (AGENTS.md Definition of Done).
- Evidence: `ExportsRestoreScreen.swift:28` `let assignment = selectedAssignment ?? viewModel.assignment`; `GradeDraftViewModel.swift:107-109` `return assignments.first ?? AssignmentRecord()`; `ExportsRestoreScreen.swift:292-296` only re-selects when `assignmentID` is non-nil.
- Recommended fix: Make the Exports tab assignment-explicit: a list of export-ready assignments (rows with student + status) that push `ExportsRestoreScreen(assignmentID:)`, plus the all-assignment exports (gradebook, full backup) in their own section. Delete the `var assignment` fallback getter. Show the assignment title/student in the confirmation sheet header.
- Effort: M.
- Confidence: High.

### B-05 — High — Final review can silently discard the teacher's unsaved edits; four different save models
- Area / files: `Views/GradeResultView.swift:128-270`; `UI/Screens/FinalReviewScreen.swift:156-205`; contrast `RubricInstructionsScreen.swift:829-837`, `GradeWizardView.swift:462-489`, `ReviewScannedTextScreen.swift:102-118`.
- What it is now and why: `FinalGradeReviewView` copies the review into `@State workingReview`; teacher edits to feedback, notes and points stay local until "Save Teacher Edits". It also has `.onChange(of: review) { workingReview = newValue }` so external changes show up.
- Why it is a problem: The per-criterion buttons (accept/reject suggestion, add/remove/clear evidence, add/delete criterion) call the view model, which saves a new `review`; the `onChange` then **replaces `workingReview` wholesale**, wiping any typed-but-unsaved student feedback or private note. Leaving the screen (Back, tab switch, "Next student") also drops unsaved edits with no warning. Across the app a teacher meets four different models: rubric autosaves per keystroke (B-03), wizard Setup edits memory only until "Save" (`GradeWizardView.swift:462-470` vs `482-489`), OCR stages and commits on focus loss, final review needs an explicit button. Teachers cannot predict which edits are safe.
- Evidence: `GradeResultView.swift:268-270` `.onChange(of: review) { _, newValue in workingReview = newValue }`; `256-261` "Save Teacher Edits"; `FinalReviewScreen.swift:187-194` accept/reject call view-model mutators.
- Recommended fix: One editing model app-wide: edit view-model-owned state directly (with `@Observable` + `@Bindable`, B-07) and debounce persistence, as in B-03. If an explicit save is kept for final review, merge external changes per field instead of overwriting, and block leaving with unsaved changes (confirmation dialog on Back; `.interactiveDismissDisabled` in sheets).
- Effort: M.
- Confidence: High on the overwrite mechanism (the accept/reject paths mutate the stored review, which changes the `review` input).

### B-06 — High — The scanned page image is read from disk and decoded inside `body`, on every render
- Area / files: `UI/Screens/ReviewScannedTextScreen.swift:53-62, 270`; `GradeDraftViewModel+StudentWorkImport.swift:157-162, 225-231`; `UI/DesignSystem/OCRComponents.swift:41-84`.
- What it is now and why: `body` calls `viewModel.sourceImage(for:)`, which does `Data(contentsOf:)` + `UIImage(data:)` synchronously; `workPreviewFooter` does it again (`270`). Images are stored as full-resolution PNGs from the scanner (`pngData()`).
- Why it is a problem: The OCR review screen re-renders on every keystroke (staged corrections are `@State`, `pendingOCRCorrections`), on line selection, and on any view-model publish. Each render re-reads and decodes a multi-megabyte PNG twice on the main thread — exactly while the teacher is typing corrections. Expect stutter and memory spikes on older iPads. The preview is also capped at 420pt high with no zoom (`OCRComponents.swift:76`), which makes checking handwriting against OCR hard on iPhone.
- Evidence: `ReviewScannedTextScreen.swift:57` `let image = source.flatMap { viewModel.sourceImage(for: $0) }`; `StudentWorkImport.swift:160-161`.
- Recommended fix: Load once per page with `.task(id: page.id)` off the main actor, downsample via ImageIO `CGImageSourceCreateThumbnailAtIndex` to the display size, keep it in `@State`. Add pinch-zoom (`MagnifyGesture`, iOS 17) or present the page with SwiftUI `.quickLookPreview(_:)` for full-size inspection. Keep `ScaledImageRectMapper` (it is correct and tested).
- Effort: S.
- Confidence: High.

### B-07 — High — One `ObservableObject` view model with 31 `@Published` properties drives every screen
- Area / files: `GradeDraftViewModel.swift:7-40`; 17 `@ObservedObject var viewModel` across `UI/` and `Views/`; `ContentView.swift:4-7`.
- What it is now and why: Legacy Combine-style observation (pre-iOS 17 pattern). Every screen takes the whole view model.
- Why it is a problem: Any change to any of the 31 published properties (status message, `isWorking`, progress, export URL…) invalidates every visible screen's `body`, including the heavy ones (B-02, B-06). Combined with B-03 this is why per-keystroke work is so expensive. The deployment target is iOS 17, so the Observation framework (`@Observable`) is available and tracks only the properties each view actually reads. (Overlaps area A — the view-model design itself.)
- Evidence: `GradeDraftViewModel.swift:7` `final class GradeDraftViewModel: ObservableObject`; `grep -c @Published` → 31; `grep @Observable` → 0.
- Recommended fix: Migrate to `@Observable` (Observation, iOS 17+), hold it with `@State` in the App/ContentView, pass with `.environment(...)`, use `@Bindable` for bindings; split into feature models (assignment editing, export, restore, AI drafting) so a progress tick doesn't redraw the roster.
- Effort: M–L; risk: behaviour change in update timing — needs the UI test lane.
- Confidence: High.

### B-08 — Medium — Views must re-select the assignment before every action (69 call sites)
- Area / files: 69 `selectAssignment(` calls in `UI/` and `Views/` (e.g. `FinalReviewScreen.swift:54-193`, `RubricInstructionsScreen.swift:94-130, 822-835`, `GradeWizardView.swift:157,438,466,476,484,493`); `GradeDraftViewModel+AssignmentPersistence.swift:86-91`.
- What it is now and why: View-model mutators operate on the implicit `selectedAssignmentID`, so each screen calls `viewModel.selectAssignment(assignmentID)` in `onAppear` and before every closure.
- Why it is a problem: Any missed call acts on the wrong assignment. One is already missed: the scanner completion `Task { await viewModel.applyScannedImages(images) }` (`StudentWorkScreen.swift:239-240`) does not re-select, unlike the photo and PDF paths (`250, 260`). `onAppear` selection also mutates published state (and triggers B-03's readiness work) on every appearance, including when popping back.
- Evidence: `FinalReviewScreen.swift:160-161` `viewModel.selectAssignment(assignmentID); viewModel.updateFinalReview($0)`; `StudentWorkScreen.swift:239-241`.
- Recommended fix: ID-parameterised APIs (`updateRubricText(_:for:)`, `applyScannedImages(_:to:)`), or a per-assignment model object (`AssignmentEditor(id:)`) passed to each screen. Delete `selectedAssignmentID` as a mutation target.
- Effort: M.
- Confidence: High.

### B-09 — Medium — The stationery design system is copy-pasted at least six times, with dead parts
- Area / files: `GradeDraftColors.swift:15-26` (`StationeryTheme.gradeDraft`); `AssignmentsScreen.swift:106-118` (`AssignmentWorkflowStationery`); `RubricComponents.swift:4-14` (`RubricStationeryPalette`); `ExportComponents.swift` (`.exportPrivacy`, 10 literals); `FinalReviewScreen.swift:469-943` (`FinalReviewPaperStyle`, `FinalReviewPaperCard`, `FinalReviewTapeLabel`, `FinalReviewPerforation`); `ReviewScannedTextScreen.swift:307-460` (`ScannedTextPaperCard`, `ScannedTextTapeLabel`, `ScannedTextPerforation`); `ReviewScreen.swift` (5 literals); `HomeScreen.swift:130-167` vs `ClassesScreen.swift:246-283` (identical structs).
- What it is now and why: Each screen added its own paper palette and private card/tape/perforation copies instead of using `NotebookCard`/`TapeLabel`/`PerforatedPaperEdge`.
- Why it is a problem: Four different accent colours (green `0.18,0.45,0.28`; two browns; system `.blue` hard-coded in `Rows.swift:222,243,346,369`), inconsistent visuals, and ~1,500 lines of decoration to maintain. Dead or near-dead code: `StationeryScreen`, `DeskEdgeDecoration` (`Cards.swift:3-24, 352-372`) and `CriterionSummaryRow` (`RubricComponents.swift:249`) have zero uses; `GradeResultView` is `@available(*, deprecated)` and used only by tests (`GradeResultView.swift:3-5`); `ExportConfirmationStep.finalConfirm` is never assigned (`ExportComponents.swift:322, 516` — only `.preview` is set at `574`); `ReviewGateBanner`, `RubricIconBubble`, `RubricHandwrittenNote`, `RubricStationeryStatusChip`, `WorkflowProgressRail` are one-line wrappers. `WorkflowProgressRail` even takes an array of *views* (`[WorkflowStepRow]`) as data (`ProgressComponents.swift:227-233`).
- Evidence: as listed; `grep -c "Color(red"` → 55 across 7 files.
- Recommended fix: Decide the visual direction (see Questions). If native: delete `Cards.swift` decorations, the per-screen paper copies and palettes. If branded: one token set in the asset catalog (B-01), one card modifier, no per-screen copies. Delete the dead items above in either case (pre-production, no compatibility needed).
- Effort: M–L.
- Confidence: High.

### B-10 — Medium — Hand-built components duplicate native SwiftUI and fight Liquid Glass
- Area / files: see table.
- What it is now and why: Built before the native refactor, kept for the paper look.
- Why it is a problem: More code, weaker accessibility, and no automatic adoption of iOS 26/27 system design. Custom opaque fills, drop shadows, `scrollContentBackground(.hidden)` and a custom `ButtonStyle` override the system materials that Xcode 26 builds get for free (Liquid Glass bars, `.glass`/`.glassProminent` button styles, tab bar minimise). The clearest case: `AssignmentsScreen` shows **two search fields bound to the same text** — the custom `StationerySearchBar` (`17`) and the native `.searchable` (`67`).

| Custom component (file:line) | Native replacement |
|---|---|
| `StationerySearchBar` (`Rows.swift:3-55`) | `.searchable` (already present — delete the custom one) |
| `RubricCollapsibleCard` (`RubricComponents.swift:373-457`) | `Section(isExpanded:)` (iOS 17) or `DisclosureGroup` |
| `StationeryButtonStyle`, `PrimaryActionButton`, `SecondaryActionButton` (`Buttons.swift`) | `.buttonStyle(.borderedProminent/.bordered)`; `.glassProminent/.glass` on iOS 26+; `.controlSize(.large)` |
| `StationeryRow`, `ClassRow`, `AssignmentRow`, `StudentRow`, `ReviewQueueRow`, `WorkAttachmentRow` (`Rows.swift`) | List rows: `Label` + `LabeledContent`/`.badge`, with real `NavigationLink(value:)` |
| `StationeryMetric`/`MetricStrip` (`ProgressComponents.swift:3-185`) | `LabeledContent` rows or `Grid`; `Gauge` for ratios |
| `WarningBanner`/`BlockingIssueRow` (`Cards.swift:374-405`, `ProgressComponents.swift:236-271`) | `Section` with `Label(..., systemImage:)` + `.foregroundStyle(.orange)`; `ContentUnavailableView` for blocking states |
| iPad sidebar of `Button`s with manual highlight (`AppTabShell.swift:66-79`) | `List(selection:)` in `NavigationSplitView`, or `TabView` + `Tab` + `.tabViewStyle(.sidebarAdaptable)` (iOS 18) |
| Tape labels, perforations, paperclips, ruled lines (`Cards.swift:134-295`) | none needed (decoration) |
| `ExportConfirmationSheet` 3-step state machine in a `ScrollView` (`ExportComponents.swift:344-603`) | `Form` sheet with `Toggle` rows; see B-17 for preview |

  Keep: `RubricFlowLayout` (`RubricComponents.swift:290-340`) — a small, correct `Layout` implementation with no native equivalent I could confirm; `ContentUnavailableView`, `LabeledContent`, `ShareLink`, `PhotosPicker`, `fileImporter`, `confirmationDialog` uses (already native).
- Evidence: per table.
- Recommended fix: Replace per table as part of B-02.
- Effort: L (do together with B-02/B-09).
- Confidence: High.

### B-11 — Medium — Navigation: no route model, odd iPad sidebar, recursive "Next student" stack
- Area / files: `UI/AppShell/AppTabShell.swift:63-174`; `UI/Screens/FinalReviewScreen.swift:308-333, 354-359`; 18 destination-closure `NavigationLink`s across screens.
- What it is now and why: Five tab stacks on iPhone; on iPad a `NavigationSplitView` whose sidebar is plain `Button`s with a hand-drawn selection background. Navigation uses closure `NavigationLink { Destination() }` everywhere; App Intent routing pushes via one `launchRoute` binding.
- Why it is a problem: (1) The same `.navigationDestination(item: $launchRoute)` is attached to all five stacks and placed *on* the `NavigationStack` rather than inside its content (`AppTabShell.swift:90-95` etc.). SwiftUI documents the modifier as belonging inside the stack; outside, it is typically ignored with a runtime warning, and five stacks sharing one binding can conflict (Medium confidence — cannot run; the UI test lane does not exercise launch routes). (2) No `NavigationPath`/route enum → no state restoration (`@SceneStorage`), no programmatic pop-to-root, no deep links beyond the intent hack. (3) "Next student" pushes another `FinalReviewScreen` on top of the current one (`354-356`), so grading a class of 30 builds a 30-deep stack and Back walks through every previous student. (4) iPad sidebar lacks keyboard/focus navigation and native selection; `selectedRootScreen` swaps roots inside one persistent `NavigationStack`, so pushed screens can survive a sidebar switch.
- Evidence: `AppTabShell.swift:69-76` `Button { selectedTab = tab } ... .listRowBackground(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)`; `FinalReviewScreen.swift:354-356` `.navigationDestination(item: $gradingTarget) { target in FinalReviewScreen(...) }`.
- Recommended fix: `enum Route: Hashable, Codable { case assignment(UUID), finalReview(UUID), ocrReview(UUID), … }`; per-tab `@State var path: [Route]` with one `navigationDestination(for: Route.self)` at each stack root; "Next student" replaces the last element (`path[path.count - 1] = .finalReview(next.id)`); App Intents set the path. iPad: `List(selection: $selectedTab)` in the sidebar, or on an iOS 18+ target `TabView { Tab(...) }.tabViewStyle(.sidebarAdaptable)`, which gives both layouts from one declaration.
- Effort: M.
- Confidence: High for (2)-(4); Medium for (1).

### B-12 — Medium — Guided grading contradicts the assignment timeline and is mostly a hub of the same screens
- Area / files: `Views/GradeWizardView.swift:4-101, 412-428, 462-489`; `UI/Screens/AssignmentOverviewScreen.swift:52, 171-180`; entry points `AssignmentsScreen.swift:50-57`, `AssignmentOverviewScreen.swift:121`, `ClassDetailRosterScreen.swift:233`.
- What it is now and why: A full-screen 6-step wizard added for guidance. Setup and Export are inline; the other four steps are buttons that push the existing screens inside the wizard's own `NavigationStack`.
- Why it is a problem: The wizard and the Assignment Overview timeline show the same six step names with different rules. Wizard "Setup" = title and student entered (`GradeWizardView.swift:52-53`); Overview "Setup" = grading standard saved (`AssignmentOverviewScreen.swift:173`), and Overview steps 1 and 4 test the identical condition (`hasGradingStandard`). A teacher can see "Setup ✓" in one and "Setup — not started" in the other. The wizard adds a second navigation tree to the same screens, and its Setup fields are not persisted until "Save" while every other screen autosaves (B-05). It is discoverable only through a long-press context menu on list rows or a button on the overview.
- Evidence: as cited.
- Recommended fix: One step model (`GradeWizardProgress` is already pure and tested — 21 test references) used by both the wizard and the overview timeline; consider replacing the wizard with the overview screen itself acting as the stepper (sections for each step, current step expanded). Persist Setup fields the same way as other edits.
- Effort: M.
- Confidence: High.

### B-13 — Medium — Gating rules and user-facing copy live in views, duplicated and inconsistent; the copy catalog is mostly unused
- Area / files: `UI/Screens/FinalReviewScreen.swift:386-446`; `Views/GradeWizardView.swift:49-101`; `UI/Screens/AssignmentOverviewScreen.swift:171-180, 220`; `UI/Screens/RubricInstructionsScreen.swift:72-80, 307-358`; `GradeDraftViewModel.swift:144, 259`; `Content/GradingPacketBuilder.swift:242, 473`; `Content/GradeDraftCopyCatalog.swift:77-210`.
- What it is now and why: Each screen re-derives "can draft / can start manual review / what blocks export" from raw fields and writes its own message.
- Why it is a problem: The "missing grading standard" message exists in at least six wordings (e.g. "Add a rubric, answer key, exemplar, or grading criteria before drafting feedback." vs "Add a rubric, answer key, or exemplar before generating draft feedback." in the catalog). Rules can drift between screens (a button enabled on one screen, blocked on another). `GradeDraftCopyCatalog` presents itself as the central copy source, but outside its own file only `Labels.prohibited` (`GradeDraftContentValidator.swift:58`) and `SourceOfTruth.canonicalPromptTemplate` (`PromptBuilder.swift:84`) are referenced — `Readiness`, `ReviewWorkflow`, `OCRReview`, `ReadinessCopy`, `TeacherReview`, etc. are unused by any view. There is no String Catalog (`.xcstrings`), and most labels pass through `String` parameters (e.g. `StationeryRow(title: String)`), so they would not be extracted for localisation even though `SWIFT_EMIT_LOC_STRINGS = YES`.
- Evidence: `FinalReviewScreen.swift:402` and `437`; `GradeDraftCopyCatalog.swift:80`; grep for `GradeDraftCopyCatalog.` → 2 external references.
- Recommended fix: A single readiness type in the model layer (e.g. `AssignmentReadiness(assignment, aiStatus) -> [ReadinessIssue]` with typed cases) that every screen renders; messages defined once (a String Catalog `Localizable.xcstrings`, Xcode 15+). Delete unused catalog sections or wire them in.
- Effort: M.
- Confidence: High.

### B-14 — Medium — Accessibility work is real but uneven; several regressions at large text sizes
- Area / files: `UI/DesignSystem/StatusChip.swift:151-165` (good); `Rows.swift:122,184,221,273,317,368`; `HomeScreen.swift:94-100`; `ExportsRestoreScreen.swift:122-128`; `FinalReviewScreen.swift:533-557, 858-859`; `Cards.swift:258-271`; `ProgressComponents.swift:22-23`.
- What it is now and why: Good intent: status chips carry a full spoken consequence, chips collapse to icon-only at accessibility sizes, decorative art is hidden from VoiceOver, 44pt minimum tap targets are used on buttons.
- Why it is a problem: 72 `lineLimit` calls truncate content teachers need — export and assignment names cut to one line (`HomeScreen.swift:96,100`; `ExportsRestoreScreen.swift:124,128`). Six row icons use fixed `.font(.system(size: 19-21))` that ignore Dynamic Type. Final-review metric pills shrink text with `.minimumScaleFactor(0.75)` in a three-across `HStack` (`FinalReviewScreen.swift:504-508, 541-544`). Every status element is announced with the label "Status" (chip, bubble, row icon), so VoiceOver users hear "Status, Status, Status". `DraftCriterionReviewCard` overrides the label of a container that holds buttons (`858-859`). Rotated tape text with `minimumScaleFactor(0.8)` (`Cards.swift:263,271`). Fixed palettes ignore Increase Contrast/Reduce Transparency (B-01). No `accessibilityIdentifier`s (0), so UI tests are keyed on English labels. No automated audit.
- Evidence: as cited.
- Recommended fix: Remove `lineLimit` on content text; `@ScaledMetric` for icon sizes (or use `Label` with text styles); `ViewThatFits`/`AnyLayout` to stack pills vertically at accessibility sizes; give status elements meaningful labels ("Approval status"); add `try app.performAccessibilityAudit()` (XCTest, iOS 17+) to the existing UI test lane.
- Effort: S–M.
- Confidence: High.

### B-15 — Medium — The UI guardrail script and "snapshot" tests are theatre
- Area / files: `scripts/ci/check_native_ui_refactor.py:1-103`; `GradeDraftTests/NativeUIRefactorSnapshotTests.swift:102-245`; `GradeDraftTests/__Snapshots__/NativeUIRefactorSnapshotTests/*.txt`.
- What it is now and why: Written to stop regressions back to the stationery `ScrollView` screens.
- Why it is a problem: The script checks for text tokens (`List {`, `.searchable`, `ContentUnavailableView` "somewhere in UI layer", absence of the word `ScrollView`, absence of `chevron.right` in `Rows.swift` only — while `RubricComponents.swift:479` draws one). The "snapshot" tests host each screen and record which UIKit class names appear; the stored reference for Assignments is just "CollectionView, List, ScrollView, Navigation". Neither would catch B-01 (dark mode), B-02 (one-row lists), the duplicate search field, truncation, or layout breakage. The swift-snapshot-testing package is a project dependency but no test imports `SnapshotTesting` (grep → 0).
- Evidence: `check_native_ui_refactor.py:39-48`; snapshot file content above.
- Recommended fix: Replace with real image snapshots using swift-snapshot-testing 1.19.7 (https://github.com/pointfreeco/swift-snapshot-testing) — `assertSnapshot(of: vc, as: .image(on: .iPhone13, traits: .init(userInterfaceStyle: .dark)))`, plus an accessibility-XXXL and an iPad variant — and `performAccessibilityAudit()` in UI tests. Delete the token script once real checks exist, or remove the dependency if image snapshots are not wanted.
- Effort: M.
- Confidence: High.

### B-16 — Medium — Export "preview" for PDFs shows Markdown text, not the file being exported
- Area / files: `UI/DesignSystem/ExportComponents.swift:386-399, 501-514`; `UI/Screens/ExportsRestoreScreen.swift:136-141`.
- What it is now and why: The confirmation sheet shows `MarkdownReportBuilder` output in monospaced text for both Markdown and PDF kinds, and an inventory summary for archives, before the file is generated.
- Why it is a problem: The teacher ticks "I reviewed this export preview" for a PDF they have not seen; layout, page breaks and content rendering in the PDF are not what was previewed. This is a trust gate in the core lane (teacher final review → export) that doesn't check what it claims to.
- Evidence: `ExportComponents.swift:388-391` `case .studentReportMarkdown, .studentReportPDF: return MarkdownReportBuilder.studentMarkdown(for: assignment)`.
- Recommended fix: Generate the artifact to a temporary local URL first, preview it with SwiftUI `.quickLookPreview($url)` (QuickLook, iOS 14+; renders PDF/Markdown/CSV natively, offline), then enable `ShareLink`. Also removes the unreachable `.finalConfirm` step.
- Effort: S–M.
- Confidence: High.

### B-17 — Low — No `#Preview`s anywhere; test fixtures ship in the production app
- Area / files: all of `UI/`, `Views/` (`#Preview` → 0, `PreviewProvider` → 0); `GradeDraftApp.swift:7-80`.
- What it is now and why: Development relied on CI screenshots and UI tests.
- Why it is a problem: No fast visual iteration in Xcode for 17 screens and ~60 components; this is how B-01 and B-02 went unnoticed. UI-test fixture data (fake students, notes) is compiled into the release app behind launch arguments.
- Evidence: grep counts; `GradeDraftApp.swift:23-80`.
- Recommended fix: Add `#Preview` blocks for each screen in light/dark and large Dynamic Type using a shared in-memory fixture (`PreviewModifier`, iOS 18 SDK, for shared preview context). Move fixtures to a Preview Content folder (`DEVELOPMENT_ASSET_PATHS`) or test target; gate launch-argument fixtures with `#if DEBUG`.
- Effort: S.
- Confidence: High.

### B-18 — Low — `RubricInstructionsScreen` force-unwraps the assignment inside long-lived bindings
- Area / files: `UI/Screens/RubricInstructionsScreen.swift:40, 98, 819-837`.
- What it is now and why: `private var assignment: AssignmentRecord { viewModel.assignment(for: assignmentID)! }`, guarded only by a check at the top of `body`.
- Why it is a problem: Binding getters, `onChange(of: assignment.assignmentType)` and template helpers evaluate `assignment` outside that check; if the assignment is removed while the screen is alive (restore with replace, deletion elsewhere on iPad split view), the app crashes instead of showing the not-found state the routing rule requires.
- Evidence: line 40.
- Recommended fix: Pass a non-optional `AssignmentRecord`/model into a child view after the guard (as `FinalReviewScreen` does with `if let`), and make bindings no-op when missing.
- Effort: S.
- Confidence: Medium (crash requires a removal while the screen is on screen).

### B-19 — Low — Scanner bridge is still needed, but its dismissal fights SwiftUI's sheet state; photo import is single-image
- Area / files: `Views/DocumentScannerView.swift:35-58`; `UI/Screens/StudentWorkScreen.swift:150, 238-246`.
- What it is now and why: `VNDocumentCameraViewController` wrapped in `UIViewControllerRepresentable` and shown in `.sheet(isPresented: $showingScanner)`. There is still no SwiftUI-native document camera (I found no first-party SwiftUI scanner as of iOS 26; VisionKit is still the API), so the bridge itself is justified — keep it.
- Why it is a problem: The coordinator calls `controller.dismiss(animated:)` itself, and none of the callbacks set `showingScanner = false`, so UIKit dismisses the sheet behind SwiftUI's back; the binding can stay `true` (next tap may not re-present; Medium confidence). The completion path also skips `selectAssignment` (B-08). `PhotosPicker` allows one image (`150`), so multi-page work from the photo library needs repeated imports. Third-party reports note VisionKit scanner UI glitches on iPadOS 26 (cancel button missing) — worth a device check.
- Evidence: `DocumentScannerView.swift:38` `controller.dismiss(animated: true) { self.onComplete(images) }`; `StudentWorkScreen.swift:239-245`.
- Recommended fix: Let SwiftUI dismiss: callbacks set `showingScanner = false` and do not call `controller.dismiss`; present with `.fullScreenCover` (the camera expects full screen). `PhotosPicker(selection: $items, maxSelectionCount: 20, matching: .images)` with ordered import.
- Effort: S.
- Confidence: Medium (dismissal desync); High (single-image picker).

### B-20 — Low — Attachment rows show a misleading "Not started" status
- Area / files: `UI/DesignSystem/Rows.swift:386`.
- What it is now and why: `StatusChip(source.teacherIncludedInExport ? .teacherOnly : .notStarted, compact: true)`.
- Why it is a problem: A saved scan that is simply not included in exports is labelled "Not started", which reads as "this work hasn't been processed". Teachers may re-scan.
- Evidence: line 386.
- Recommended fix: Show the real meaning ("Kept on device" / "Included in archive") with `Label`, or drop the chip.
- Effort: S.
- Confidence: High.

---

## Keep (good as is)
- `ScaledImageRectMapper` + `TextLineHighlightOverlay` (`OCRComponents.swift:86-156`): correct Vision lower-left → SwiftUI top-left mapping, aspect-fit aware, unit-tested.
- `GradeWizardProgress` (`GradeWizardView.swift:49-101`): pure, testable step gating — a good base for the single step model in B-12.
- Fail-closed routed screens (`MissingAssignmentRouteView`, `FinalReviewScreen.swift:334-347`): the right behaviour; extend it to the Exports tab (B-04).
- Use of native pieces where present: `ContentUnavailableView` (including `.search(text:)`), `LabeledContent`, `ShareLink` gated behind an explicit warning, `PhotosPicker`, `fileImporter`, `confirmationDialog` for destructive choices, `.searchable`.
- `StatusChip` accessibility (full spoken consequence, icon-only fallback at accessibility sizes) — keep the idea, render with native `Label`.
- `RubricFlowLayout`: small, correct `Layout` conformance.
- `DocumentScannerView` as a bridge (still required), with the dismissal fix in B-19.

## Out of area
- Area A (view model / persistence): `updateAssignment` appends a stale audit event on every change once stale (no transition guard) and `saveCurrentAssignment` passes the whole assignments array to `store.saveAssignments` (`GradeDraftViewModel+AssignmentPersistence.swift:97-117`); `selectAssignment` triggers model prewarm and readiness rebuild (`RoutingStatus.swift:63-86`).
- Tests: swift-snapshot-testing is declared but never imported by any test.
- `ClassSummary.id` is `name.lowercased()` (`ScreenModels.swift:76`) — classes are identified by name, so renames and same-name classes collide.

## Questions for the owner
1. Visual direction: keep a branded "paper/stationery" look (then it must be rebuilt as one asset-catalog token set with dark and high-contrast variants), or go fully native iOS 26/27 (Liquid Glass, system colours) and delete the stationery layer? The native option removes the most code and fixes dark mode and accessibility for free.
2. Deployment target: raising the minimum from iOS 17 to iOS 18 (or 26) unlocks `TabView`/`Tab` with `.sidebarAdaptable` for one iPhone/iPad navigation declaration, `PreviewModifier`, and lets the app use Liquid Glass APIs without availability checks. Is iOS 17 support required for your target schools' devices?
3. Guided grading: keep it as a separate full-screen wizard, or fold it into the Assignment Overview as the single step-by-step view?
