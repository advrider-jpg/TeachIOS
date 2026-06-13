# AGENTS for TeachIOS

Read this first before any substantial repo work:

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/OFFLINE_CAPABILITY.md`
- `docs/TEST_PLAN.md`
- `docs/ledgers/CORE_RULES.md`
- Relevant `.agents/skills/*` guidance for the task at hand.

## Project identity

- GradeDraft is local-first for iOS/iPadOS.
- It is not an autonomous grader.
- The app provides local rubric suggestions, then teacher-level editing/finalization.
- Scope is text-based student work in the documented core lane:
  `scan/import/paste -> local OCR -> explicit teacher OCR review -> local draft -> teacher final review -> local export`.
- No cloud fallback, no backend service in core path, no analytics, no account/login flow.

## Hard fake-state / fake-completion guardrail

No stateless crap. No fake behavior. No placeholder logic dressed up as working functionality. No UI that pretends the app works when it does not. Fail openly rather than silently faking success.

## PR-review discipline

If the user provides a PR link after a prompt was drafted, review the live PR against the prompt in maximum depth.

- Review every requirement, each claimed deliverable, each affected file, each omitted file, and likely side effects.
- Inspect the live GitHub PR and repo state. Do not answer from memory, stale summaries, prior context, or assumptions.
- If any defect, omission, scope drift, fake completion, or partial compliance exists, immediately draft a full-completion fix prompt.
- Do not give the implementing AI phased follow-up or optional cleanup.
- Use a strict, hard completion standard.

## iOS CI Debugging Rules

When CI fails, first use `gh-fix-ci` to inspect the failing GitHub Actions run and retrieve the exact failing log section. Do not infer the failure from file names or recent edits alone.

For local iOS reproduction, use XcodeBuildMCP rather than hand-written `xcodebuild`, `xcrun`, or `simctl` commands unless XcodeBuildMCP cannot produce complete logs. Always identify the workspace/project, scheme, destination simulator, and failing test target before changing code.

After each fix, rerun the narrowest relevant build or test command first. Only run the full suite after the targeted failure is resolved.

## iOS CI and iOS/Codex debugging skill stack (ranked)

For this repo’s CI/debugging workflow, use this order:

| Rank | Skill / repo                                                      | GitHub signal | Why it matters for your iOS CI work |
| ---: | ----------------------------------------------------------------- | ------------- | ---------------------------------- |
|    1 | **OpenAI `gh-fix-ci`** (inside `openai/skills`)                    | Check upstream live when needed. | Uses `gh` to inspect PR checks, fetch logs, identify failing jobs, summarize failures, and propose a fix plan. |
|    2 | **`getsentry/XcodeBuildMCP`** (`xcodebuildmcp` skill)             | Check upstream live when needed. | Best iOS-specific debugging companion with build, test, run, simulator, log capture, LLDB, screenshots, view hierarchy, and automation workflows. |
|    3 | **twostraws/SwiftUI-Agent-Skill**                                 | Check upstream live when needed. | Targets common SwiftUI mistakes (deprecated API, accessibility, performance) when CI failures are SwiftUI-subtle. |
|    4 | **Dimillian/Skills** (`ios-debugger-agent`)                         | Check upstream live when needed. | Builds on XcodeBuildMCP for simulator launch, inspection, and log capture when local runtime differs from CI behavior. |
|    5 | **AvdLee/SwiftUI-Agent-Skill**                                    | Check upstream live when needed. | Useful second-pass SwiftUI/code quality review for state management and composition issues. |

Practical first-line setup:

```bash
# In Codex, install the official CI fixer:
skill-installer gh-fix-ci
```

```bash
# Install XcodeBuildMCP:
brew tap getsentry/xcodebuildmcp
brew install xcodebuildmcp

# Or:
npm install -g xcodebuildmcp@latest

# Then initialize agent skills:
xcodebuildmcp init
```

Broad Swift coverage (secondary):

```bash
npx skills add dpearson2699/swift-ios-skills --all
```

Suggested invocation for a failing PR:

```text
Use the gh-fix-ci skill first. Inspect the failing GitHub Actions checks for the current PR using gh, pull the failing job logs, identify the exact failing command and error, and produce a concise root-cause analysis.

Then use XcodeBuildMCP to reproduce the closest equivalent build/test locally for the relevant scheme, simulator, and test target. Do not guess. Compare the CI failure against the local XcodeBuildMCP result. Make the smallest production-quality fix that addresses the actual failure, then rerun the targeted build/test command and summarize the diff and remaining risks.
```

GitHub references:
- https://github.com/openai/skills
- https://github.com/getsentry/XcodeBuildMCP
- https://github.com/twostraws/SwiftUI-Agent-Skill
- https://github.com/Dimillian/Skills
- https://github.com/AvdLee/SwiftUI-Agent-Skill
- https://github.com/dpearson2699/swift-ios-skills

## Validation commands

- `python3 scripts/no_network_scan.py`
- `python3 scripts/repo_health.py`
- `xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft`
- `swiftlint lint --config .swiftlint.yml`
- `xcodebuild test -project GradeDraft.xcodeproj -scheme GradeDraft -destination 'platform=iPhone Simulator,name=<available iPhone simulator destination>'`

## Definition of Done

- No core rule violations.
- No cloud/network path added to core behavior.
- No fake local AI/OCR/export/grading states.
- Routed assignment IDs must fail closed. A stale or invalid assignment route must show an explicit not-found state and must not display, mutate, export, or grade the currently selected assignment as a fallback.
- Low-confidence OCR lines require explicit teacher line-level action before scanned text can be marked reviewed.
- If source code adds or keeps an Apple required-reason API such as `UserDefaults`, update `GradeDraft/Resources/PrivacyInfo.xcprivacy` and static checks in the same change.
- Relevant validation evidence captured or explicitly marked unavailable.
- Validation commands run where possible; if not run, report exactly what was not run and why.
- Never claim validation passed unless it actually passed in this session or explicit repo evidence exists.

## Ledger update discipline

For routine changes, add only a short `docs/ledgers/WORKLOG.md` entry.

Update `PROJECT_LEDGER.md` only when phase status, scope, deliverables, or durable project posture changes.

Update `DATA_LEDGER.md` only when source packages, schemas, datasets, migrations, generated artifacts, counts, or provenance assumptions change.

Update `DECISIONS_LEDGER.md` only when an architectural, product, data, testing, or process decision is made, changed, or superseded.

Update `VALIDATION_LEDGER.md` only when validation gates, test commands, test evidence, release criteria, or known validation status changes.

Update `CORE_RULES.md` only when a foundational repo invariant is identified, changed, superseded, or expressly removed by the user.

If no durable repo state changed, do not update ledgers.
