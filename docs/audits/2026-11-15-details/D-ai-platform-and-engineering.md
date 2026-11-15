# Area D — Local AI, Apple platform integration, and the engineering system

Reviewer: area D. Repo: C:\TeachIOS at cd64e9d (read-only). All file:line references are to that commit. Nothing was built or run (Windows, no Xcode); conclusions are reasoned from source plus Apple documentation checked on 15 Nov 2026.

## Summary

The on-device AI path is fundamentally sound in its *shape*: typed guided generation, an app-side validator as the real correctness gate, an explicit "too large, nothing truncated" failure, and manual review that never depends on AI. What is wrong is mostly in the details and around the edges:

1. The model is never shown the field descriptions the code carefully wrote (`includeSchemaInPrompt: false` on brand-new sessions) — this is the single cheapest quality fix in the app.
2. Roughly 1,100 lines of AI code (tool layer, batch readiness, evaluation harness) are never used by the running app, and the AI Readiness screen shows a "Local tool policy — Ready" check for tools the model does not have.
3. The 21 Python "guardrails" are mostly string-pinning scripts that require specific source text to exist. They protect dead code from deletion and in one case actively block the @Observable migration, while the one product rule AGENTS.md names as Definition of Done (stale assignment routes fail closed) has no behaviour test at all.
4. Builds are not reproducible (no Package.resolved, floating Xcode selection), and the scheduled weekly CI run is guaranteed to fail.
5. Token budgeting, error classification and the 4,096-token context limit are hand-rolled where Foundation Models now provides `contextSize`, `tokenCount(for:)` and typed errors.

Count by severity: Critical 0, High 4, Medium 14, Low 5 (23 findings).

---

### D-01 — High — The model never sees the field instructions written for it
- Area / files: GradeDraft/Services/FoundationModelGradingService.swift:118-123, 177-182, 222-227, 290-295; GradeDraft/Services/FoundationModelGradeProposalSchema.swift:8-106; GradeDraft/Services/PromptBuilder.swift:132, 186, 243, 266
- What it is now and why it was probably done this way: Every generation call passes `includeSchemaInPrompt: false`. Probably copied from a sample to save tokens in the tight 4,096-token window.
- Why it is a problem: The `@Guide(description:)` text on every field ("Exact quotes from the reviewed student text… or exactly 'No supporting evidence found.'", "Do not infer effort, intent… disability, demographics", "True when evidence is missing, OCR is uncertain…") is how the model learns what each field means. With the schema excluded, constrained decoding still forces the JSON *shape*, but the model only sees bare field names. The prompt then tells it to "Return one generated GradeDraftProposal object using the app schema" — a schema it has never been shown. Every session is brand new (lines 118, 177, 222, 290), so there is no earlier turn in which the model could have seen it. Apple's documentation is explicit: "Consider using the default value of `true` for `includeSchemaInPrompt`. The exception to the rule is when the model has knowledge about the expected response format, either because it has been trained on it, or because it has seen exhaustive examples during this session." Neither exception applies. Practical effect: weaker evidence quoting, more "missing evidence" markers used wrongly, more `teacherReviewRequired` misuse, and the bias-prevention wording in the guides is invisible to the model.
- Evidence: `session.streamResponse(to: PromptBuilder.fullPacketPrompt(input: input, mode: mode), generating: FoundationModelGradeProposalSchema.GradeDraftProposal.self, includeSchemaInPrompt: false)` (FoundationModelGradingService.swift:178-182). Prompt: `"Return one generated GradeDraftProposal object using the app schema."` (PromptBuilder.swift:132).
- Recommended fix: Remove the `includeSchemaInPrompt: false` argument (default is `true`) at all five call sites. Measure the schema's token cost with `SystemLanguageModel.default.tokenCount(for:)` (D-04) and include it in the budget. Delete the "using the app schema" sentences, which mean nothing without the schema. Apple doc: https://developer.apple.com/documentation/foundationmodels/languagemodelsession/streamresponse(to:generating:includeschemainprompt:options:)
- Effort: S. Risk: the schema adds a few hundred tokens per call, so more assignments will drop to criterion-by-criterion mode. That is the correct trade.
- Confidence: High (Apple doc quoted; all sessions confirmed fresh in code).

### D-02 — High — The "local AI tools" layer is never connected to the model, yet the AI Readiness screen reports it as ready
- Area / files: GradeDraft/AI/Tools/LocalGradingToolSupport.swift (397 lines); GradeDraft/Services/LocalAIGradingTools.swift:1-180; GradeDraft/Content/GradingPacketBuilder.swift:293-298; docs/APPLE_INTELLIGENCE_IMPLEMENTATION.md:95-97; scripts/ci/check_local_ai_tools.py
- What it is now and why it was probably done this way: Two parallel tool systems — `LocalGradingToolSession`/`LocalGradingToolPolicy`/`StudentEvidenceIndex`/`LocalToolCallAudit` and an older `LocalAIGradingToolbox`/`LocalAIToolPolicy` with an enum of ten "forbidden" tool names (`sendEmail`, `readContacts`, `fetchWeb`…). Neither conforms to the Foundation Models `Tool` protocol, and no `LanguageModelSession` is created with `tools:`. A search of the app target finds no caller apart from one string: the AI Readiness check. They were built speculatively ("Direct Foundation Models tool-calling still needs Xcode 26 SDK compilation", APPLE_INTELLIGENCE_IMPLEMENTATION.md:97) and never finished.
- Why it is a problem: (a) Roughly 580 lines of shipped code do nothing at runtime. (b) The AI Readiness screen shows a check titled "Local tool policy", status `.ready`, with the text "Local AI tools are read-only, assignment-scoped, network-free…" — describing tools the model does not have. This is the kind of UI-claims-something-that-isn't-happening that AGENTS.md's "no fake behavior" rule forbids. (c) A list of "forbidden tools" that were never possible is not a safety control. (d) A guardrail script requires these files and specific strings inside them to exist (D-03), so a maintainer who deletes the dead code gets a red CI.
- Evidence: `AIReadinessCheck(id: "local-tools", title: "Local tool policy", detail: LocalAIToolPolicy.gradingSession.policySummary, status: .ready)` (GradingPacketBuilder.swift:293-298). `grep LocalGradingToolSession|LocalAIGradingToolbox` outside their own files → only GradeDraftTests/AppleIntelligenceImplementationTests.swift.
- Recommended fix: Delete both tool files, the "local-tools" readiness check, check_local_ai_tools.py, and the related tests. Tool calling is the wrong fit here anyway: the full packet already goes in the prompt, the context is small, every tool call and result uses up context, and the design rule (ARCHITECTURE.md:115) already says required grading logic must stay in app code. If a real need appears later (for example, letting the model look up a single criterion while drafting criterion by criterion), build it then as a `Tool` conformance with `GenerationOptions.ToolCallingMode` (iOS 27) — https://developer.apple.com/documentation/foundationmodels/tool
- Effort: S. Risk: none at runtime.
- Confidence: High.

### D-03 — High — Most Python guardrails pin source text: they protect dead code, block modernisation, and leave the real rules untested
- Area / files: scripts/repo_health.py:11-25, 52-63; scripts/ci/check_route_and_export_truthfulness.py:10-101; check_ai_batch_readiness.py:11-29; check_local_ai_tools.py:12-36; check_ai_prompt_safety.py:13-40; check_native_ui_refactor.py:10-98; check_app_intents_safety.py; check_ci_contract.py; bad_string_scan.py:11-16
- What it is now and why it was probably done this way: 21 scripts (table below). Most check that particular strings or identifiers *exist* in particular files (`"@Published var preparedExportArtifact"`, `"never creates drafts"`, `"currentSavedAssignmentForAction(\"Roster preview\")"`, `"final class LocalGradingToolSession"`) or *do not* exist. They were written by coding agents to stop later agents from quietly removing behaviour — a substitute for tests the agents could not run on Windows.
- Why it is a problem:
  - **They freeze implementation, not behaviour.** check_route_and_export_truthfulness.py:75 requires `@Published var preparedExportArtifact`; migrating the view model from `ObservableObject` to `@Observable` (GradeDraftViewModel.swift:7) fails CI even if behaviour is identical. Renaming a log string such as `"Roster preview"` fails CI.
  - **They protect dead code.** check_ai_batch_readiness.py requires that `AIBatchReadiness.swift` exists and contains the comment text "never creates drafts" — the file has no caller in the app (D-11). check_local_ai_tools.py does the same for D-02.
  - **They give false assurance.** A file can contain the string "MissingAssignmentRouteView" and still fall back to the selected assignment. The AGENTS.md Definition-of-Done rule ("Routed assignment IDs must fail closed…") is protected *only* by this string scan: no test in GradeDraftTests drives a stale route and checks for the not-found state (search for `MissingAssignmentRoute|route` in tests finds only a source-text test, GradeDraftUILanguageTests.swift:70).
  - **bad_string_scan.py bans the words "mock" and "placeholder"** in app and test code, which pushes code to avoid honest names (SwiftUI's own `.redacted(reason: .placeholder)` would fail it).
  - **check_ci_contract.py** prevents edits to the CI workflow itself; branch-protection required checks are the native way to do that.
  - Six unit tests also read Swift source text from disk at runtime via `#filePath` (for example GradeDraftUILanguageTests.swift:56-60), the same anti-pattern inside XCTest.
- Evidence: see table. Example: `REQUIRED_GLOB_SNIPPETS = {"GradeDraft/GradeDraftViewModel*.swift": ["@Published var preparedExportArtifact", …` (check_route_and_export_truthfulness.py:73-75).
- Recommended fix: Replace with three real mechanisms and delete the rest:
  1. **Behaviour tests** for the rules that matter: stale route → not-found and no mutation; student-facing export blocked without approved final review; low-confidence OCR line blocks "reviewed"; App Intents never call `draftGrade`/export (unit-test the `AppLaunchAction` handler).
  2. **SwiftLint `custom_rules`** (SwiftLint 0.65.1, https://github.com/realm/SwiftLint) for genuine "never write this" bans: `URLSession`, `NWConnection`, `PrivateCloudComputeLanguageModel` (D-10), raw `.joined(separator: ",")` outside CSVCodec, plus the built-in `todo` rule.
  3. **Xcode synchronized folders** to remove the project-membership script (D-17).
  Keep only the curriculum generator check and validator (real data checks) and a slimmed release checklist.
- Effort: M (writing about six behaviour tests; deleting about 1,400 lines of Python). Risk: low; behaviour tests are stronger than what they replace.
- Confidence: High.

Guardrail verdict table (all 21):

| Script | What it really checks | Verdict |
|---|---|---|
| repo_health.py | 13 files exist, then runs 10 other scripts | Delete. The compiler already fails on missing files |
| no_network_scan.py | Regex for URLSession, `https?://`, "Analytics"… in Swift/plist/json/yml | Replace with SwiftLint custom rule for Swift; add `PrivateCloudComputeLanguageModel`. Modest real value (iOS has no "deny network" entitlement), so keep the rule |
| export_hardening_scan.py | No `.joined(separator: ",")`; parses `studentMarkdown` body for banned words | CSV rule → SwiftLint; Markdown check is already covered by ExportHardeningTests.swift:5-18 → delete |
| bad_string_scan.py | TODO/FIXME/"placeholder"/"mock" | Replace with SwiftLint `todo`; drop the placeholder/mock bans |
| check_native_ui_refactor.py | Screens contain `List {`/`Form {`, no `ScrollView`, etc. | Delete (design review, not CI) |
| check_route_and_export_truthfulness.py | ~40 required/forbidden source strings | Delete after adding behaviour tests |
| check_xcode_project_membership.py | Every .swift file is in pbxproj | Replace with synchronized folder groups |
| check_ci_contract.py | Workflow still has named jobs and steps | Delete; use branch protection |
| check_release_readiness_static.py | Release files, Package.resolved, plist keys, icon size | Keep as release checklist; fix (D-15, D-19) |
| check_curriculum_catalog.py | Validates bundled curriculum data | Keep |
| curriculum/build_acara_curriculum_catalog.py `--check` | Regenerates catalog and diffs | Keep (real generator) |
| check_ai_batch_readiness.py | Dead file contains comment strings | Delete with D-11 |
| check_ai_evaluation_fixtures.py | Fixture JSON shape | Fold into the Swift fixture test |
| check_ai_packet_preview_screen.py | Screen file contains strings | Delete |
| check_ai_prompt_safety.py | PromptBuilder contains authority sentences | Delete; a unit test on the production prompt covers it (D-07) |
| check_app_intents_safety.py | Intent names and bodies avoid words like "Approve" | Replace with one unit test over the launch-action handler |
| check_local_ai_tools.py | Dead tool files contain strings | Delete with D-02 |
| ci/select_xcode.sh | Picks newest Xcode_26* | Replace with a pinned path (D-15) |
| ci/select_ios_simulator.py | Parses simctl JSON to pick an iPhone | Replace with `-destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'` |
| create_placeholder_app_icon.py | Writes a placeholder icon | Delete (referenced nowhere) |

### D-04 — Medium — Token counts are guessed (characters ÷ 3.2) and the context size is hard-coded at 4,096
- Area / files: GradeDraft/Services/GradingPromptBudgeter.swift:39, 358-363; FoundationModelGradingService.swift:69-80; AI/Evaluation/AIEvaluation.swift:148
- What it is now and why it was probably done this way: `estimateTokenCount` = `ceil(text.count / 3.2)`; `defaultContextSizeTokens = 4096`. The comment says "Conservative approximation used before the official token counter is available." In iOS 26.0 there was no counter.
- Why it is a problem: Since iOS 26.4 (February 2026) Foundation Models provides `SystemLanguageModel.contextSize` and `tokenCount(for:)` (instructions, prompt, or whole transcript). The estimate ignores the schema (which D-01 adds), mis-counts non-English text, and the hard-coded 4,096 will be wrong for the iOS 27 model (Apple's WWDC26 session 241 sample prints `contextSize // 8192`; not independently confirmed — read it at runtime). A wrong estimate either pushes work into slower criterion-by-criterion mode or relies on the string-matched runtime retry (D-05). The evaluation harness also plans with 8,192 while the app uses 4,096 (AIEvaluation.swift:148), so "evaluation" planning does not match production.
- Evidence: `private static func estimateTokenCount(_ text: String) -> Int { max(1, Int(ceil(Double(text.count) / 3.2))) }` (GradingPromptBudgeter.swift:361-363).
- Recommended fix: Behind `if #available(iOS 26.4, *)`, use `SystemLanguageModel.default.contextSize` and `try await SystemLanguageModel.default.tokenCount(for: …)` for instructions + prompt (+ schema). Keep the ÷3.2 estimate only as the fallback for 26.0–26.3 (or drop it if the minimum becomes 26.4, see D-18). Make the evaluation planner use the same budgeter. Docs: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/tokencount(for:) and https://developer.apple.com/documentation/updates/foundationmodels
- Effort: S–M (`tokenCount` is async; `makePlan` is already called from async code). Risk: low.
- Confidence: High for the API's existence (Apple updates page); Medium for the exact iOS 27 context size.

### D-05 — Medium — Model errors are classified by searching the error's text
- Area / files: GradeDraft/Services/FoundationModelErrorMapper.swift:8-36; FoundationModelGradingService.swift:74
- What it is now and why it was probably done this way: `isContextWindowError` lowercases `String(describing: error)` and looks for "exceededcontextwindowsize", "context window" or "too many tokens"; safety refusals are detected by "safety", "guardrail" or "refus". Probably written without access to the SDK headers.
- Why it is a problem: Error descriptions are not API; a wording change silently breaks the context-overflow retry and refusal handling. Apple ships typed errors: `LanguageModelSession.GenerationError` cases (`exceededContextWindowSize`, `guardrailViolation`, `refusal`, `unsupportedLanguageOrLocale`, `assetsUnavailable`, `rateLimited`, `concurrentRequests`…) on iOS 26, and iOS 27 split them into `LanguageModelError`, `SystemLanguageModel.Error` and `LanguageModelSession.Error`. Cases with real teacher-facing meaning are currently lumped into "could not complete the draft": unsupported language (an EAL student response in another language), model assets still downloading, rate limiting. The mapper has no tests.
- Evidence: `return combined.contains("exceededcontextwindowsize") || combined.contains("context window") || combined.contains("too many tokens")` (FoundationModelErrorMapper.swift:11-13).
- Recommended fix: `switch` on the typed error (iOS 26 `LanguageModelSession.GenerationError`; on the iOS 27 SDK the new error types). Add a teacher message for unsupported language ("The on-device model can't read this language; use manual review") and check `SystemLanguageModel.default.supportsLocale(_:)` in AI Readiness. Docs: https://developer.apple.com/documentation/updates/foundationmodels (June 2026, "improved error types").
- Effort: S. Risk: low.
- Confidence: High for typed errors existing; Medium on exact iOS 27 case names (beta docs).

### D-06 — Medium — The real Foundation Models orchestration has no tests
- Area / files: FoundationModelGradingService.swift:33-306; GradeDraftTests/AppleIntelligenceImplementationTests.swift:533-542; GradeDraftTests/GradeDraftTests.swift:133-207
- What it is now and why it was probably done this way: `LanguageModelSession` is created inline in four private methods, so the service cannot be exercised without a device. Tests replace the *whole* service with fakes (`SlowCancellableGradingService` etc.), which tests the view model but never the service's logic: mode switching, the context-overflow retry, criterion-by-criterion assembly, the deterministic summary fallback, totals. The only test of the real service has `case .available: XCTAssertTrue(true)` — it passes whatever happens.
- Why it is a problem: The most complex AI logic in the app (the recovery path at lines 71-92, summing per-criterion totals at 261-262) ships untested.
- Evidence: `case .available: XCTAssertTrue(true)` (AppleIntelligenceImplementationTests.swift:537-538).
- Recommended fix: Add a small internal seam — `protocol DraftGenerating { func generate<T: Generable>(_: T.Type, instructions: String, prompt: String) async throws -> T }` — with a production implementation wrapping `LanguageModelSession.respond(to:generating:)` and a test double that returns canned values or throws a context-overflow error. `@Generable` types can be built directly in tests. Then test: a context-overflow error on the full packet retries as compact; a second overflow goes criterion by criterion; cancellation produces no draft; totals equal the per-criterion sum.
- Effort: M. Risk: low.
- Confidence: High.

### D-07 — Medium — Prompt-safety tests test a prompt that production no longer sends
- Area / files: PromptBuilder.swift:30-87 (`gradingPrompt`); GradeDraft/Content/GradeDraftCopyCatalog.swift:235 (`canonicalPromptTemplate`); FoundationModelGradingService.swift:398-437 (`JSONExtractor`); GradeDraftTests/PromptBuilderHardeningTests.swift:7-60; GradeDraftContentCatalogTests.swift:242-269; GradeDraftTests+RubricValidation.swift:294-323
- What it is now and why it was probably done this way: When typed generation replaced the old JSON prompt (Decision D008), the old template, `gradingPrompt(...)` and `JSONExtractor` were kept "as compatibility/debug material". Production uses `gradingInstructionsText`/`fullPacketPromptText`/`singleCriterionPromptText`. `gradingPrompt` and `JSONExtractor` have no caller in the app target.
- Why it is a problem: PromptBuilderHardeningTests (answer key, exemplar, custom instructions, curriculum, OCR warning included) and several content-catalog tests assert against the legacy prompt. If the production prompt dropped the answer key, those tests would still pass. Two prompt templates is also two places to keep the safety wording in step.
- Evidence: `let prompt = PromptBuilder.gradingPrompt(input: input)` in each test (PromptBuilderHardeningTests.swift:10-59); production uses `PromptBuilder.fullPacketPrompt(...)` (FoundationModelGradingService.swift:179).
- Recommended fix: Delete `gradingPrompt`, `PromptTemplateRenderer`, `canonicalPromptTemplate` and `JSONExtractor`; repoint the tests at `fullPacketPromptText` and `singleCriterionPromptText`. Update Decision D008 to say the legacy path is gone.
- Effort: S. Risk: none.
- Confidence: High.

### D-08 — Medium — "Streaming" is collected and thrown away; the progress text says it is streaming
- Area / files: FoundationModelGradingService.swift:105, 119-124, 170, 178-183, 215, 223-228, 286, 291-296
- What it is now and why it was probably done this way: Every call uses `streamResponse(...)` immediately followed by `try await stream.collect()`, while progress messages say "Streaming one typed local draft…". Probably chosen so progress could be shown later.
- Why it is a problem: No partial output reaches the teacher, so it is the same as `respond(...)` with extra machinery, and the on-screen text describes something that is not visible. Apple notes streaming in the background raises the chance of `rateLimited` errors.
- Evidence: `let stream = session.streamResponse(...); let response = try await stream.collect()` (lines 178-183).
- Recommended fix: Either (a) use `respond(to:generating:)` and change the copy to "Drafting…", or (b) actually show the streamed `PartiallyGenerated` snapshots (for example, criterion cards filling in during the per-criterion pass). (a) is the right v1 choice.
- Effort: S. Risk: none.
- Confidence: High.

### D-09 — Low — Missing generation options and wasted schema fields
- Area / files: FoundationModelGradingService.swift (no `GenerationOptions` anywhere); FoundationModelGradeProposalSchema.swift:31-44; PromptBuilder.swift:310; GradingService.swift:115, 221; FoundationModelGradingService.swift:134-141
- What it is now: (a) No `GenerationOptions`, so sampling is random — the same essay can get different draft marks on each run, which is hard to defend to a parent. (b) The model is asked to output `criterionId`, `criterion` title and `maxPoints`, all of which the app already knows; the validator overwrites `maxPoints` with the rubric value (GradingService.swift:115, 221). (c) The assignment UUID is sent in every prompt (PromptBuilder.swift:310), which costs tokens and has no grading value. (d) `prewarmIfAvailable` prewarms a throwaway session that is then discarded (lines 134-141).
- Recommended fix: Pass `GenerationOptions(sampling: .greedy)` for drafts (deterministic for a given model version; record it in the audit). Drop `maxPoints` (and the title) from `CriterionDraft` and fill them in from the rubric. Remove the UUID line. Keep prewarm (it loads model assets) but call it on the session that will be used, or drop it.
- Effort: S. Risk: greedy decoding can repeat itself on long outputs; test on device.
- Confidence: High for (b)–(d); Medium for (a)'s quality effect.

### D-10 — Medium — iOS 27 changes: what to adopt, and the new one-line route to cloud models
- Area / files: FoundationModelGradingService.swift:17, 118-296; GradeDraftFoundationModels.swift:26-32; scripts/no_network_scan.py:16-28
- What it is now: Built against the iOS 26 SDK only. Prompt versions are recorded (`GradeDraftPromptVersion`) — good.
- Why it matters (from Apple's Foundation Models updates page, June 2026):
  - **New on-device model in iOS 27.** Apple: "Because the model changes when a person updates to iOS 27… test your prompts with the new model." Teachers updating their iPad will get different drafts from the same prompt. The audit record (GradeDraftFoundationModels.swift:41-60) does not store the OS or model version, so it cannot explain why two drafts differ.
  - **`LanguageModel` protocol and `PrivateCloudComputeLanguageModel`.** The same `LanguageModelSession` API can now be backed by Apple's server model or any cloud provider. Breaking the "no cloud fallback" product rule is now a one-line change that no_network_scan.py cannot see (no `URLSession`, no `https://`).
  - **Image input plus Vision `OCRTool`.** Tempting, but feeding page images to the model skips the teacher's line-by-line scanned-text review, which is the app's central trust rule. Do not adopt it for grading.
  - **Updated Foundation Models instrument** (prompts, output, token use) and `GenerationOptions.ToolCallingMode`.
- Recommended fix: (1) Add a SwiftLint custom rule that fails on `PrivateCloudComputeLanguageModel` and on any `LanguageModelSession(model:` other than `SystemLanguageModel`. (2) Store OS build and model version in `LocalModelDraftAudit`. (3) Re-run the prompts on iOS 27 devices using the evaluation set (D-11) and the Instruments template. (4) When the minimum is raised (D-18), adopt the iOS 27 typed errors (D-05). Docs: https://developer.apple.com/documentation/updates/foundationmodels
- Effort: S–M. Risk: none.
- Confidence: High (Apple page); exact beta symbol shapes Medium.

### D-11 — Medium — The "evaluation fixtures" never evaluate the model, and two AI modules are dead code shipped in the app
- Area / files: GradeDraft/AI/Evaluation/AIEvaluation.swift:130-390; GradeDraft/AI/Batch/AIBatchReadiness.swift (117 lines); GradeDraftTests/Fixtures/AIEvaluation/*.json; GradeDraftTests/AIEvaluationFixtureTests.swift; scripts/ci/check_ai_evaluation_fixtures.py
- What it is now: Ten fixture files of grading scenarios (strict answer key, EAL/D-sensitive, prompt injection…). `deterministicPreflight` checks only app-side gates (validator, budget plan, readiness flags) — the same things AppleIntelligenceImplementationTests already cover. `runModelCase`, the only path that calls a model, is never invoked anywhere. Both the evaluation code and `AIBatchReadinessAnalyzer` are compiled into the production app target and used only by tests.
- Why it is a problem: The fixtures are the right idea — a fixed set of student responses with expected properties is exactly how on-device prompt changes should be judged — but nothing runs them against the model, so prompt changes (D-01, D-09) and the iOS 27 model change (D-10) cannot be measured. Test-only code in the shipping binary adds size and review surface.
- Evidence: `func runModelCase(...)` at AIEvaluation.swift:357; `grep runModelCase` → definition only.
- Recommended fix: Move AIEvaluation.swift into the test target. Add one device-only test (skipped with `XCTSkip` / Swift Testing `.enabled(if: SystemLanguageModel.default.isAvailable)`) that runs every fixture through the real service and writes the anonymised Markdown report as a test attachment; run it on an Apple Intelligence Mac or iPad before each release and after OS updates. Apple's Foundation Models SDK for Python (https://github.com/apple/python-apple-fm-sdk, March 2026) is an alternative for batch-running fixtures on a Mac. Delete AIBatchReadiness.swift and its guardrail (ARCHITECTURE.md:117 describes a batch queue that does not exist in the UI; confirm with area C/UI before deleting).
- Effort: M. Risk: none.
- Confidence: High.

### D-12 — Medium — App Intents are over-built for v1, and pass data through a hand-rolled mailbox
- Area / files: GradeDraft/AppIntents/GradeDraftAppIntents.swift:6-436; GradeDraft/AppRouting.swift:83-130
- What it is now and why it was probably done this way: 9 intents and 9 App Shortcuts. Four of them (`OpenGradeDraftDestinationIntent`, `OpenAIReadinessIntent`, `OpenLatestDraftIntent`, `PrepareLocalAIPacketPreviewIntent`) do the same thing — save a launch request for a screen. Every intent also has an `assignmentIDText: String?` parameter asking users to type a UUID. Each `perform()` writes an `AppLaunchRequest` to UserDefaults (pasted student work goes to a protected file with a 15-minute expiry), and the app reads it once at launch. Queries call `AssignmentIntentResolver.loadAssignments()`, which opens a *second* GRDB store, loads every assignment graph, and silently falls back to the JSON store if GRDB fails to open (lines 125-133).
- Why it is a problem: Nine Siri phrases is a lot of surface to keep working and localise for features most teachers will reach by tapping. The mailbox duplicates what the framework does: intents with `openAppWhenRun = true` already run in the app's process. Loading full graphs for a title picker is wasteful. The JSON fallback can show a different (stale) set of assignments from the one the app shows. `#if canImport(AppIntents)` is always true on iOS 16+. The staging itself is carefully done (file protection, expiry), so this is over-engineering, not a defect.
- Recommended fix: Keep 3 intents for v1: **Open Assignment** (an `OpenIntent` with `target: AssignmentEntity` and an optional destination enum), **Add Pasted Student Work**, and **Create Assignment**. Deliver them through `AppDependencyManager.shared.add { router }` plus `@Dependency` in `perform()`, or the iOS 26 `TargetContentProvidingIntent` + SwiftUI `.onAppIntentExecution` — either removes `AppLaunchRequestStore`'s UserDefaults/file staging. Remove `assignmentIDText`. Give `AssignmentEntityQuery` a titles-only store query. Make Search return `[AssignmentEntity]` (`ReturnsValue`) instead of a dialog string. Docs: https://developer.apple.com/documentation/appintents/targetcontentprovidingintent, https://developer.apple.com/documentation/appintents/appintent/supportedmodes
- Effort: M. Risk: re-test Shortcuts on a device; keep the "no grading/export from intents" behaviour test (D-03).
- Confidence: High on duplication and loading; Medium on the exact iOS 26 open-intent wiring (third-party write-ups confirm the pattern; Apple's reference pages exist).

### D-13 — Medium — The "snapshot tests" aren't snapshots, and the snapshot library is linked but never used
- Area / files: GradeDraftTests/NativeUIRefactorSnapshotTests.swift:103-230; GradeDraftTests/__Snapshots__/NativeUIRefactorSnapshotTests/*.txt; GradeDraftTests/GradeDraftSnapshotTests.swift:1-40; GradeDraft.xcodeproj/project.pbxproj:61, 1166-1170
- What it is now: The "snapshot" for each screen is a text file listing whether any UIKit class name contains "CollectionView", "List", "ScrollView" or "Navigation" (for example, testHomeScreenNativeListSnapshot.1.txt is ten lines of that). `swift-snapshot-testing` is a package dependency of the test target, but `import SnapshotTesting` and `assertSnapshot` appear nowhere. `GradeDraftSnapshotTests.swift` says "Snapshot testing was removed because no reference images were committed" and contains tests such as building a `LocalCapabilityBanner(status: .available, message: "…")` and asserting `banner.message` equals what was just passed in.
- Why it is a problem: These tests would pass if every label, button and section on every screen were wrong, as long as it sat in a `List`. Tests that check a struct stores its own initialiser arguments mirror the implementation and test nothing. An unused dependency still has to be resolved on every CI run.
- Recommended fix: Choose one: (a) adopt real image snapshots with swift-snapshot-testing 1.19.7 (`assertSnapshot(of: vc, as: .image(on: .iPhone13))`) on one pinned simulator and OS, with references committed — useful for this form-heavy UI; or (b) remove the package, delete the class-name "snapshots" and banner mirror tests, and rely on the screenshot job plus behaviour tests. (a) is better value. https://github.com/pointfreeco/swift-snapshot-testing
- Effort: S for (b), M for (a). Risk: image snapshots are sensitive to OS and simulator versions; pin both.
- Confidence: High.

### D-14 — Low — All 561 tests use XCTest; Swift Testing would shrink the hardening suites
- Area / files: GradeDraftTests/*.swift (10,451 lines, 0 files `import Testing`)
- What it is now: XCTest throughout, including 195 tests in 15 "*HardeningTests" files, many of which repeat the same assertion over enum cases (EnumDisplayNameTests.swift:6-30).
- Why it is a problem: Not a defect — XCTest is still supported, and UI tests must stay XCTest/XCUITest. Swift Testing (Xcode 16+) gives parameterised `@Test(arguments:)`, `#expect` with readable failure output, parallel-by-default execution, and `.enabled(if:)` traits that fit the device-only AI tests (D-11).
- Recommended fix: Write new tests in Swift Testing; migrate opportunistically, starting with the table-driven hardening files. The repo already vendors a migration skill (.agents/skills/test-modernizer). Do not mass-convert for its own sake. https://developer.apple.com/documentation/testing
- Effort: M if done incrementally. Risk: shared static fixtures may expose parallel-execution bugs; use `.serialized` where needed.
- Confidence: High.

### D-15 — High — Builds are not reproducible, and the weekly scheduled CI run always fails
- Area / files: GradeDraft.xcodeproj/project.pbxproj:1146-1170; GradeDraft.xcodeproj/project.xcworkspace (empty); docs/release/PACKAGE_RESOLUTION_PENDING.md; .github/workflows/swift.yml:9-10, 66-68, 186-193, 615-624; scripts/ci/select_xcode.sh:24-41; scripts/ci/check_release_readiness_static.py:64-66
- What it is now: No `Package.resolved` is committed (it was written on Windows, where Xcode could not create one). Every CI job deletes all SwiftPM caches and resolves the newest version allowed by "up to next major" — for example GRDB anything in 6.x, swift-snapshot-testing anything in 1.x. `select_xcode.sh` picks the newest `/Applications/Xcode_26*.app` on the runner, so the Xcode version also drifts. On the Monday cron run, `check_release_readiness_static.py` runs inside the `static-policy` job and fails unconditionally while no Package.resolved exists ("No Package.resolved found…"); `ci-summary` requires `static-policy` to succeed, so the scheduled run is red every week.
- Why it is a problem: The 13 June green run proves nothing about what builds today: a dependency patch release or a runner image update can break, or silently change, behaviour without any commit. A release build cannot be reproduced. A CI run that is always red trains everyone to ignore red.
- Evidence: `resolved_candidates = list(ROOT.glob("**/Package.resolved")); if not resolved_candidates: fail(...)` (check_release_readiness_static.py:64-66); `if: github.event_name == 'workflow_dispatch' || github.event_name == 'schedule'` (swift.yml:67).
- Recommended fix: On a Mac with Xcode, resolve once and commit `GradeDraft.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`; add `-disableAutomaticPackageResolution` to every `xcodebuild` in CI so a stale lock fails loudly. Pin Xcode explicitly (`sudo xcode-select -s /Applications/Xcode_26.6.app`, or `maxim-lobanov/setup-xcode` with `xcode-version: '26.6'`). Remove the cache-deletion steps and cache `SourcePackages` keyed on the hash of Package.resolved. Package upgrades (GRDB 7 etc.) are area C's call.
- Effort: S. Risk: none.
- Confidence: High.

### D-16 — Medium — CI rebuilds the app from scratch six or more times per run, with duplicated jobs and outdated actions
- Area / files: .github/workflows/swift.yml:123-585; .github/workflows/core-page-screenshots.yml:1-80+
- What it is now: On a PR to main, separate macOS jobs each check out, wipe caches, resolve packages and build from clean: swiftlint, xcode-unit-tests (`clean test`), ui-smoke, plus the separate core-page-screenshots workflow on *every* PR — the same `GradeDraftScreenshotTests` that swift.yml's `screenshot-smoke` already runs on main or by label. On main, add screenshot-smoke, release-build and unsigned-archive-validation (an archive *is* a Release build, so release-build is redundant). SwiftLint runs on a macOS runner (about 10x the cost of Linux). Actions are `checkout@v4` and `upload-artifact@v4` (current v7.0.1 / v7.0.2). Every job writes a custom step summary that repeats its command.
- Why it is a problem: Slow feedback and high macOS-minute cost for a single-developer project, plus duplicate screenshot jobs that can disagree.
- Recommended fix: One macOS job runs `xcodebuild build-for-testing` once, then `test-without-building` for unit tests and UI smoke (or uploads the `.xctestrun` bundle to parallel jobs). Delete core-page-screenshots.yml (keep screenshot-smoke). Delete release-build (keep the archive). Run SwiftLint on ubuntu with the official SwiftLint Docker image or binary. Bump actions to v7. Add a non-blocking Xcode 27.1 job on the macOS 27 runner image now: the repo's own vendored Apple skill (.agents/skills/swiftui-whats-new-27/SKILL.md) warns that `@State` became a macro in SDK 27 and some `@State` initialisation patterns stop compiling, so find out before the switch is forced. Use branch protection for required checks instead of the `ci-summary` loop.
- Effort: M. Risk: low.
- Confidence: High on duplication; versions as given in the shared brief.

### D-17 — Medium — Build settings: dated project format, hand-edited project file, and Swift 6.0 mode
- Area / files: project.pbxproj:5 (`objectVersion = 56`), 1249-1411; Config/Shared.xcconfig; scripts/ci/check_xcode_project_membership.py; docs/ledgers/VALIDATION_LEDGER.md:7-9
- What it is now: Project format 56 (Xcode 14 era) with every file listed by hand. The validation ledger records agents "normalizing hand-authored project object IDs" and fixing "dangling references" — the project file is being edited by hand on Windows, which is why a 183-line membership checker exists. `SWIFT_VERSION = 6.0` (strict concurrency already on, which is good), with no `SWIFT_DEFAULT_ACTOR_ISOLATION` or approachable-concurrency settings. `SWIFT_VERSION` and `IPHONEOS_DEPLOYMENT_TARGET` are set in both Shared.xcconfig and every target's build settings, so changing one place does nothing.
- Why it is a problem: Hand-editing project files is the top cause of the CI breaks recorded in the ledgers. Duplicated build settings drift.
- Recommended fix: Convert to Xcode 16+ synchronized folder groups (`PBXFileSystemSynchronizedRootGroup`, objectVersion 77; Xcode: right-click a group → "Convert to Folder"). Files on disk then belong to the target automatically; delete check_xcode_project_membership.py. Remove the duplicated target-level settings so Config/*.xcconfig is the one source. When moving to Xcode 27, set the Swift language version to the current 6.x and consider `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` for the app target (most of the code is UI and view model) — check against the 2 `nonisolated(unsafe)` formatters (CSVExportService.swift:133, Database.swift:897).
- Effort: M (conversion needs a Mac). Risk: one-off project churn; do it on its own branch.
- Confidence: High.

### D-18 — Medium — iOS 17 is the minimum, but nothing below iOS 26 is ever tested
- Area / files: Config/Shared.xcconfig (`IPHONEOS_DEPLOYMENT_TARGET = 17.0`); .github/workflows/swift.yml:22 (`IOS_MIN_MAJOR: "26"`); scripts/ci/select_ios_simulator.py; FoundationModelGradingService.swift:15-30, 44-98 (13 `canImport` / 14 `available` checks across 6 files)
- What it is now: The app claims iOS 17+, CI only ever selects an iOS 26+ simulator, and Foundation Models needs 26 (26.4 for D-04's token APIs).
- Why it is a problem: The code cost of availability branching is actually small (about 27 checks). The real cost is that the iOS 17–25 experience — no AI at all, plus any SwiftUI behaviour differences — ships without ever being run. The `#if canImport(FoundationModels)` / `canImport(AppIntents)` / `canImport(LocalAuthentication)` branches are always true with the required Xcode 26+ SDK, so their "compiled without the framework" paths are unreachable dead code.
- Recommended fix: Product decision (see Questions). Either raise the minimum to iOS 26.4, which deletes the dead branches and lets D-04/D-05 drop their fallbacks — iOS 26 runs on the same iPhones as iOS 18 (iPhone 11 and later), so very few teachers lose access — or keep 17/18 and add an iOS 18 simulator run to CI. Remove the `canImport` guards either way.
- Effort: S. Risk: excludes teachers on devices stuck below 26 (pre-2019 hardware).
- Confidence: High on the testing gap; device-support statement is general knowledge, not re-verified.

### D-19 — Low — Info.plist and export-authentication details
- Area / files: GradeDraft/Resources/Info.plist; UI/Screens/StudentWorkScreen.swift:68, 150; scripts/ci/check_release_readiness_static.py:73; GradeDraft/Services/ExportAuthenticationService.swift:17-44
- What it is now: (a) `NSPhotoLibraryUsageDescription` is declared, and the release script *requires* it, but the app only uses `PhotosPicker`, which runs out of process and needs no photo-library permission. (b) Face ID or passcode is required for sensitive exports but allowed through when the device has no passcode, while the whole app, including all student data, opens without any authentication.
- Why it is a problem: (a) An unnecessary permission string can prompt App Review questions. (b) The gate is inconsistent: anyone holding the unlocked iPad can read everything but needs Face ID to export it. It is mild friction, not protection.
- Recommended fix: (a) Remove the key and the release-script requirement. (b) Keep the export confirmation, and decide whether you want an optional app-level lock (see Questions) instead of authenticating per export.
- Effort: S. Confidence: High for (a); (b) is a product judgement.

### D-20 — Medium — Documentation sprawl: session logs, stale prompts and duplicated release kits obscure the few docs that matter
- Area / files: docs/ (about 290 KB of top-level Markdown plus ledgers); docs/ledgers/WORKLOG.md (38 KB), VALIDATION_LEDGER.md (36 KB); docs/CODEX_NEXT_PROMPT.md; docs/V2_IMPLEMENTATION_NOTES.md; docs/CORE_RULES.md (a 208-byte pointer); ridiculously-close-repo-audit.md (92 KB, repo root); MARKFORME_RELEASE_PACKAGE_README.md; docs/release/markforme_release_package/ (1.9 MB, which duplicates docs/release/*.md and support_site); docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md (105 KB)
- What it is now: Six ledgers, of which WORKLOG and VALIDATION_LEDGER are running logs of agent sessions ("PR #44 first reported these failures on commit 5d0b93c…"). CODEX_NEXT_PROMPT.md tells the reader to apply `GradeDraft_all_features_completion_v3.patch`, a file that no longer exists. Release copy exists twice. GradeDraftContentCatalog.swift:7 says `generatedFrom = "docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md"`, but there is no generator — the Swift catalogs are hand-copied, so the "source of truth" can drift from the code with nothing to catch it. Correction to the shared brief: `tmp_latest_ci.log` is **not** in the repository — it is untracked and ignored by `*.log` in .gitignore; it exists only in this working copy.
- Why it is a problem: Agents are told by AGENTS.md to read README, ARCHITECTURE, OFFLINE_CAPABILITY, TEST_PLAN and CORE_RULES first; the useful content is diluted by logs that git history already holds, and stale instructions (the patch prompt) can mislead an agent.
- Recommended fix: Keep README, ARCHITECTURE, OFFLINE_CAPABILITY, TEST_PLAN, CORE_RULES, DECISIONS_LEDGER, DATA_MODEL and the docs/release set (one copy). Delete CODEX_NEXT_PROMPT, the V2/V3 notes, the docs/CORE_RULES.md pointer, WORKLOG and VALIDATION_LEDGER (git log and CI results are the record — update AGENTS.md's ledger rules to match), and the root audit file (move any still-open items into issues). Either generate the Swift content catalogs from the Markdown with a script plus a CI `--check`, the same pattern as the curriculum generator, or make the Swift catalogs the source and delete the Markdown.
- Effort: S (deletions) / M (catalog generator). Risk: none; history stays in git.
- Confidence: High.

### D-21 — Low — Repo-local agent skills: some useful, some irrelevant, provenance unverifiable
- Area / files: .agents/skills/* (12 skills, 76 KB); skills-lock.json; AGENTS.md:41-108
- What it is now: Seven vendored skills locked to `wisdom-in-a-nutshell/agents` (which, per the brief, now returns 404), plus five project skills. `c-bounds-safety` (C `-fbounds-safety`) and `uikit-app-modernization` (UIKit scene migration) do not apply — the app has no C code and is SwiftUI. `swiftui-whats-new-27` and `test-modernizer` are directly useful (D-16, D-14). AGENTS.md ranks five *external* skills (gh-fix-ci, XcodeBuildMCP…) that are not installed, and requires XcodeBuildMCP, while the repo's own `gradedraft-xcode-verify` skill tells agents to run raw `xcodebuild`/`simctl` and points them back at `repo_health.py` and `no_network_scan.py` (D-03).
- Why it is a problem: Irrelevant skills cost agent context and can trigger wrongly; conflicting verification instructions; the hashes in skills-lock.json cannot be re-checked against a source that no longer exists.
- Recommended fix: Delete `c-bounds-safety` and `uikit-app-modernization`. Keep `swiftui-whats-new-27`, `swiftui-specialist`, `test-modernizer` and `device-interaction`, and re-source them from a live origin, or drop skills-lock.json and treat them as vendored files. Make `gradedraft-xcode-verify` match AGENTS.md, and update both after D-03. Trim the AGENTS.md install-instructions table to what is actually used.
- Effort: S. Confidence: High (404 status taken from the brief, not re-checked).

### D-22 — Low — SwiftLint is configured to do almost nothing
- Area / files: .swiftlint.yml
- What it is now: Default rules minus the length rules, four opt-in rules, no `custom_rules`, no analyzer rules; `GradeDraftUITests` is not linted.
- Why it is a problem: Lint is the natural home for the "never write X" bans now done badly in Python (D-03), and for useful opt-in rules.
- Recommended fix: Add `custom_rules` (URLSession/NW*, `PrivateCloudComputeLanguageModel`, CSV joins outside CSVCodec), enable `todo` as an error, add opt-ins such as `force_unwrapping` (the scripts currently ban `assignmentID!` by string), `unused_declaration`/`unused_import` via `swiftlint analyze`, and include the UI test folder. https://realm.github.io/SwiftLint/rule-directory.html
- Effort: S. Confidence: High.

### D-23 — Medium — The AI Readiness and packet surfaces are deterministic and honest, apart from the two exceptions above
- Area / files: GradingPacketBuilder.swift:230-330; FoundationModelGradingService.swift:14-31
- Note: Apart from the false "Local tool policy: Ready" check (D-02) and the "Streaming" copy (D-08), the readiness screen reports real state: availability reasons are mapped from `SystemLanguageModel.Availability.UnavailableReason`, and prompt-injection and custom-instruction warnings come from real text scans. Listed as Medium only because those two exceptions sit on the same screen, which teachers will use to decide whether to trust the AI. Fixing D-02 and D-08 closes this; no separate work.
- Confidence: High.

---

## Keep (good as is)
- **Typed guided generation plus an app-side validator** (`GradeDraftValidator.normalizeAndValidate`) as the correctness gate; the model's output is never trusted directly (FoundationModelGradingService.swift:196, 270).
- **No silent truncation**: full → compact → criterion-by-criterion → explicit "too large, nothing sent to cloud" message (GradingPromptBudgeter.swift:255-346, 365). This is the right policy; only the token counting changes (D-04).
- **Availability reasons mapped to plain teacher messages** (FoundationModelGradingService.swift:309-320) and manual review always available.
- **Instructions-level prompt-injection boundary** (PromptBuilder.swift:99-106) and keeping identity data out of the prompt to reduce bias (GradingPacketBuilder.swift:67-153). The rationale holds even though the model is on-device: the point is fairness, not data leaving the phone.
- **Cancellation checks** between every stage, and no draft stored on cancel.
- **Sensitive EAL/D and adjustment constraint templates manual-only** (Decision D010; GradingConstraintTemplates.swift).
- **Prompt, schema and validator version stamps** in `LocalModelDraftAudit`. Add OS and model version (D-10).
- **Shortcut payload staging hygiene** (protected file, 15-minute expiry, delete on read) — careful work, even though D-12 recommends removing the need for it.
- **Curriculum generator `--check` and catalog validator** — real data validation.
- **The PR-required app-driving UI smoke test** (GradeDraftCoreLaneUITests, Decision D015) — real end-to-end coverage. Add accessibility identifiers (0 in the app today) so it stops depending on visible text.
- **Strict concurrency already on** (Swift 6 mode), with only 2 `nonisolated(unsafe)` and 1 `@unchecked Sendable` in the app, each justified.

## Out of area
- GRDB is capped at 6.x by "up to next major from 6.0.0"; 7.12.0 is current (area C / persistence).
- `GradeDraftViewModel` is still `ObservableObject` (GradeDraftViewModel.swift:7); note that check_route_and_export_truthfulness.py currently blocks moving it to `@Observable` (D-03).
- `curriculum_catalog_acara_v9.json` is bundled alongside the shard files that are meant to replace it — possible duplicate bundle weight (content area).
- The Info.plist has no `UISupportedInterfaceOrientations` with `GENERATE_INFOPLIST_FILE = NO`; check with Organizer "Validate App" for iPad multitasking requirements before submission (Medium confidence).

## Questions for the owner
1. **Minimum iOS version:** raise to iOS 26.4 (AI available wherever the device supports it, simpler code, nearly the same device list as iOS 18), or keep iOS 17 and pay for testing the no-AI experience on old systems?
2. **Shortcuts for v1:** is three shortcuts (Open Assignment, Add Pasted Student Work, Create Assignment) enough, or do teachers really need Siri phrases for AI Readiness, Packet Preview, Latest Draft and AI Constraints?
3. **Deterministic drafts:** should the same essay always get the same draft marks on the same device (greedy sampling, D-09), accepting slightly less varied feedback wording?
4. **Device lock:** keep Face ID only on export, add an optional "lock MarkForMe" setting for the whole app, or drop authentication entirely?
5. **Image snapshots:** invest in real screen image snapshots (D-13 option a), or rely on the screenshot artifacts plus behaviour tests?

Sources checked: Apple Foundation Models updates — https://developer.apple.com/documentation/updates/foundationmodels ; `streamResponse(…includeSchemaInPrompt…)` — https://developer.apple.com/documentation/foundationmodels/languagemodelsession/streamresponse(to:generating:includeschemainprompt:options:) ; InfoQ on contextSize/tokenCount — https://infoq.com/news/2026/03/apple-foundation-models-context ; WWDC26 session 241 — https://developer.apple.com/videos/play/wwdc2026/241/ ; App Intents `supportedModes` — https://developer.apple.com/documentation/appintents/appintent/supportedmodes ; `TargetContentProvidingIntent` — https://developer.apple.com/documentation/appintents/targetcontentprovidingintent ; iOS 26 open-intent pattern — https://swiftjectivec.com/Open-Intent-Additions-iOS26-In-AppIntents/
