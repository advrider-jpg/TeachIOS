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

## Current validation gaps

- UI test for pasted-text flow.
- UI test for OCR block/review/unblock behavior.
- UI test for staleness transitions.
- Export/report test matrix for student and teacher-audit behavior.
- Source image persistence/inclusion checks.
- Offline behavior and local AI-unavailable UI flow tests.
- Migration, backup/restore, PDF/CSV hardening, OCR fixture depth, and source-span linkage tests.

## Validation status

- Not run in this session.
- Do not mark validation as passing unless a command was run successfully in-session or explicit repo/CI evidence is present.
