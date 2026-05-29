# Validation Ledger

## Known validation commands

- `python3 scripts/no_network_scan.py`
- `python3 scripts/repo_health.py`
- `xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft`
- `swiftlint lint --config .swiftlint.yml`
- `xcodebuild test -project GradeDraft.xcodeproj -scheme GradeDraft -destination 'platform=iPhone Simulator,name=<available iPhone simulator destination>'`

## CI-equivalent gate

Repository checks are expected in this sequence:

- no-network + repo health guardrails
- package resolution
- SwiftLint
- Xcode build/test on available iPhone simulator

## No-network guardrail details

`scripts/no_network_scan.py` checks Swift/PLIST/Privacy/project config files for:

- `URLSession`, `NSURLConnection`, `Network`, `NWConnection`, `NWPathMonitor`
- `http://` / `https://`
- Firebase, Amplitude, Mixpanel, Sentry, and other common analytics strings

This is static pattern scanning for obvious network/off-device patterns.

## Source-level test coverage already present

- deterministic draft totals
- final totals from teacher-final points
- missing rubric validation
- missing student text validation
- unreviewed OCR gating
- JSON extraction handling
- OCR quality warning tests
- rubric parsing
- score clamping
- missing-evidence teacher-review flags
- structured-criterion completeness
- student export excluding private notes
- teacher-audit inclusion of private notes
- GRDB round-trip including delete and injected root
- assignment prompt persistence and backward-compatible decode
- built-in rubric template IDs, totals, and evidence safeguards in instructions
- PromptBuilder safety rules and prompt field usage
- prohibited UI label test (no auto-grade, no accept-AI-grade language)
- local AI unavailable message contains no-cloud-fallback copy
- final-review approval gate (unapproved criteria, stale review, out-of-range scores)
- answer key / exemplar as valid grading standard
- **Manual final review** — start without AI draft; block without reviewed text; block with OCR needsReview/blocked; block without grading standard
- **Manual final review** — parsed rubric creates matching criteria; answer-key-only creates teacher-review-required criterion
- **Manual final review** — cannot be approved until all criteria are approved; approved review enables student export; GRDB round trip
- **Criterion management** — add criterion; delete criterion; approval blocked after adding unapproved; totals recalculate after deletion
- **Export flow** — student report blocked without approved final review; student report blocked when stale; student report excludes raw model response; teacher audit includes private notes, OCR status, packet fingerprint
- **CSV status matrix** — no final review (pending), approved, stale
- **Local AI unavailability** — disables draft button; does not disable manual final review
- **OCR** — scanned input sets needsReview; markOCRReviewed sets reviewed; draft blocked before OCR review; manual review available after OCR reviewed
- Source file cleanup on assignment delete (ViewModel logic; actual file removal subject to filesystem)

## Current validation gaps

- UI test for pasted-text flow (requires iOS simulator).
- UI test for OCR block/review/unblock behavior (requires iOS simulator).
- UI test for staleness transitions (requires iOS simulator).
- xcodebuild compile and link test (unavailable in current Windows environment).
- SwiftLint check (unavailable in current Windows environment).
- Package.resolved not generated (xcodebuild unavailable in current Windows environment).
- Migration, backup/restore, OCR fixture depth, and source-span linkage tests.
- Side-by-side OCR review UI implemented with source previews, editable OCR lines, line confirmation/rejection, and evidence reference linking.

## Validation status

### 2026-05-28 — Monster slice / MVP completion pass

- `python3 scripts/no_network_scan.py` — **passed** (run in-session).
- `python3 scripts/repo_health.py` — **passed** (run in-session).
- `xcodebuild -resolvePackageDependencies` — **blocked**: xcodebuild unavailable in Windows environment.
- `swiftlint lint` — **blocked**: SwiftLint unavailable in Windows environment.
- `xcodebuild test` — **blocked**: xcodebuild unavailable in Windows environment.
- Simulator smoke test — **blocked**: iOS simulator unavailable in Windows environment.
- Do not mark Xcode build/test as passing — it has not been run in this environment.
