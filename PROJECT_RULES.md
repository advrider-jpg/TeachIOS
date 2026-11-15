# MarkForMe project rules

Install as `PROJECT_RULES.md` at the repository root. Read with `AGENTS.md`. These are product requirements, not a record of past tasks. There are no exceptions to the shared core rules.

## Product and local data

- MarkForMe (Xcode project and targets: `GradeDraft`) is a local-first iOS/iPadOS teacher-controlled grading assistant for text-based student work. It is not an autonomous grader: it offers local rubric suggestions, and the teacher edits and finalizes every grade.
- The core lane is `scan/import/paste -> local OCR -> explicit teacher OCR review -> local draft -> teacher final review -> local export`. Handwriting, posters, physical models, diagrams, symbolic math, LMS sync, cloud backup, accounts and subscriptions stay out of scope.
- No cloud fallback, no backend service in the core path, no analytics, no account or login flow. Do not add a cloud or network path to core behavior.
- MarkForMe is fully AI-enabled, using Apple's on-device model (Foundation Models `SystemLanguageModel`) only. Do not use Private Cloud Compute, any server-backed `LanguageModel`, or any third-party model.
- Do not show fake local AI, OCR, export or grading states. When Foundation Models is unavailable, show the local-unavailable state and refuse to draft; manual final review remains available.
- Keep source input, scanned text, teacher-reviewed text, grading packet, AI draft, teacher final review, export and audit events as separate records. AI draft points and teacher final points stay separate.
- Grade only teacher-reviewed text, never raw OCR or source images. Do not silently truncate reviewed text or grading materials: draft the full packet, a compact packet or criterion by criterion, or fail with an explicit too-large message.
- Each AI-proposed criterion score cites evidence from the student's work or is marked for teacher review. Totals are calculated from stored criterion points, never taken from model-written totals.
- AI drafts and final reviews become stale when any grading input changes; stale results cannot produce student-facing exports.
- The app must not infer language background, disability, support needs, adjustment status, effort or intent. EAL/D-sensitive and adjustment-context AI constraint templates are selected only by the teacher, never automatically.
- Student-facing reports omit private teacher notes, model output, audit metadata, file paths, other students' data and bounding-box coordinates. Teacher records, archives and backups are teacher-only and warning-gated.
- Curriculum references are offline, labelled with their source, and never claim endorsement or reporting approval.
- Backup restore never silently overwrites local work: assignment conflicts are resolved by explicit teacher choice (keep local, replace local, or restore as a copy).
- Routed assignment IDs fail closed. A stale or invalid assignment route shows an explicit not-found state and must not display, mutate, export or grade the currently selected assignment as a fallback.
- Low-confidence OCR lines require explicit teacher line-level action before scanned text can be marked reviewed.
- If source code adds or keeps an Apple required-reason API such as `UserDefaults`, update `GradeDraft/Resources/PrivacyInfo.xcprivacy` and the static checks in the same change.
- Consult `docs/ARCHITECTURE.md`, `docs/OFFLINE_CAPABILITY.md`, `docs/TEST_PLAN.md` and the relevant `.agents/skills/*` guidance for the affected contract.

## Verification

Validation commands, run where possible; report exactly what was not run and why:

- `python3 scripts/no_network_scan.py`
- `python3 scripts/repo_health.py`
- `xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft`
- `swiftlint lint --config .swiftlint.yml`
- `xcodebuild test -project GradeDraft.xcodeproj -scheme GradeDraft -destination 'platform=iPhone Simulator,name=<available iPhone simulator destination>'`

## PR review

If the user provides a PR link after a prompt was drafted, review the live PR against the prompt in maximum depth: every requirement, each claimed deliverable, each affected and omitted file, and likely side effects. Inspect the live GitHub PR and repository state, not memory or prior summaries. If any defect, omission, scope drift, fake completion or partial compliance exists, immediately draft a full-completion fix prompt, with no phased follow-up or optional cleanup.

## iOS CI debugging

- When CI fails, first use `gh-fix-ci` to inspect the failing GitHub Actions run and retrieve the exact failing log section. Do not infer the failure from file names or recent edits alone.
- For local iOS reproduction, use XcodeBuildMCP rather than hand-written `xcodebuild`, `xcrun` or `simctl` commands unless it cannot produce complete logs. Identify the project, scheme, destination simulator and failing test target before changing code.
- After each fix, rerun the narrowest relevant build or test first; run the full suite only after the targeted failure is resolved.
- Skill order for CI and debugging work:
  1. [OpenAI `gh-fix-ci`](https://github.com/openai/skills): inspects PR checks, fetches logs, identifies failing jobs and proposes a fix plan. Install in Codex with `skill-installer gh-fix-ci`.
  2. [`getsentry/XcodeBuildMCP`](https://github.com/getsentry/XcodeBuildMCP): build, test, run, simulator, log capture, LLDB, screenshots and view hierarchy. Install with `brew tap getsentry/xcodebuildmcp && brew install xcodebuildmcp` or `npm install -g xcodebuildmcp@latest`, then `xcodebuildmcp init`.
  3. [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill): common SwiftUI mistakes (deprecated API, accessibility, performance).
  4. [Dimillian/Skills](https://github.com/Dimillian/Skills) (`ios-debugger-agent`): simulator launch, inspection and log capture when local runtime differs from CI.
  5. [AvdLee/SwiftUI-Agent-Skill](https://github.com/AvdLee/SwiftUI-Agent-Skill): second-pass SwiftUI state and composition review.
  - Secondary broad Swift coverage: `npx skills add dpearson2699/swift-ios-skills --all` ([repo](https://github.com/dpearson2699/swift-ios-skills)).
