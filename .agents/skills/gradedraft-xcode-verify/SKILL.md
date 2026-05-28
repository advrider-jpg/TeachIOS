---
name: gradedraft-xcode-verify
description: Validate GradeDraft Swift changes with local and CI-equivalent checks before claiming completion.
---

Use this skill after any code change that affects build, tests, lint, or Xcode-facing behavior.

Verification baseline:
- Run from repo root: `python3 scripts/no_network_scan.py`.
- Run from repo root: `python3 scripts/repo_health.py`.
- Compare against `.github/workflows/swift.yml` because CI uses this exact gate.

Compile-and-test sequence:
1. `xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft`.
2. Run `swiftlint lint --config .swiftlint.yml` (or note if intentionally unavailable).
3. Discover simulator device:
   - `xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print "id=" $2; exit }'`
4. Use that ID in:
   - `xcodebuild test -project GradeDraft.xcodeproj -scheme GradeDraft -destination id=<destination>`.

If any command fails, do not claim green status. Stop and report the first failing command plus concrete output.

SDK and Foundation Models checks:
- Do not assume Foundation Models symbols compile.
- Confirm current Apple SDK API names in `GradeDraft/Services/FoundationModelGradingService.swift`.
- Confirm compilation against `GradeDraft/Services/GradingService.swift` and app call sites.
- If APIs changed by SDK, align implementation with exact project-compatible symbols and keep fallback paths explicit.

Release-confidence rule:
- Do not modify `.github/workflows/swift.yml` for local convenience without preserving CI intent.
- If a full run is not possible in the environment, state this explicitly and provide exact commands with their current status.
