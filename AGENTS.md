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
