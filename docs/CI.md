# Mark My Work CI

Mark My Work CI is layered so deterministic policy failures, Swift style failures, Xcode test failures, visual smoke failures, and Release build failures are diagnosed separately. The primary workflow lives at `.github/workflows/swift.yml` and is named `GradeDraft CI`. A separate visual workflow lives at `.github/workflows/core-page-screenshots.yml` and is named `GradeDraft Core Page Screenshots`.

## Jobs

| Job | Runner | PR required | Purpose |
| - | - | - | - |
| `static-policy` | `ubuntu-latest` | Yes | Runs repo health, no-network, export-hardening, bad implementation string, project membership, and CI contract guardrails. |
| `workflow-lint` | `ubuntu-latest` | Yes | Runs pinned `actionlint` plus the Mark My Work CI contract check. |
| `swiftlint` | `macos-26` | Yes | Selects Xcode 26+, then runs SwiftLint against `.swiftlint.yml`. |
| `xcode-unit-tests` | `macos-26` | Yes | Selects Xcode 26+ and an iOS 26+ iPhone simulator, resolves packages, and runs deterministic XCTest coverage while skipping screenshot tests. |
| `screenshot-smoke` | `macos-26` | No for ordinary PRs | Runs only `GradeDraftScreenshotTests` and uploads PNGs plus `.xcresult`. It runs on `main`, scheduled/manual runs, and PRs labeled `visual-check`. |
| `release-build` | `macos-26` | No for ordinary PRs | Builds Release for generic iOS with code signing disabled. It runs on `main`, scheduled, and manual runs. |
| `ci-summary` | `ubuntu-latest` | Optional | Writes a combined job-result summary and fails if any PR-required job failed. |

## Separate Screenshot Workflow

`GradeDraft Core Page Screenshots` runs on ordinary pull requests, pushes to `main`, and manual dispatch. Its `core-page-screenshots` job selects Xcode 26+ and an iOS 26+ iPhone simulator, runs only `GradeDraftTests/GradeDraftScreenshotTests`, verifies the complete expected PNG set, then uploads:

- `xcode-core-page-screenshots-output`
- `gradedraft-core-page-screenshots`

The XCTest screenshot manifest compares against `GradeDraft/UI/Screens/*Screen.swift`, excluding only `ScreenModels.swift`, so every core app page must have an explicit screenshot case.

## Toolchain Selection

`scripts/ci/select_xcode.sh` is the supported CI Xcode selector. It prefers `GRADE_DRAFT_XCODE_PATH`, then the highest installed `/Applications/Xcode_26*.app`, then `/Applications/Xcode.app` only if that app reports Xcode 26 or newer. It fails openly if Xcode 26+ is not available.

`scripts/ci/select_ios_simulator.py` reads `xcrun simctl list devices available --json`, selects an available iPhone simulator with iOS 26 or newer, writes an arm64 simulator destination to `$GITHUB_OUTPUT` in CI, and supports `--print-destination` for local command substitution.

## Local Reproduction

Run static policy checks from the repo root:

```bash
python3 scripts/repo_health.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
```

Run workflow lint when `actionlint` is available:

```bash
actionlint .github/workflows/*.yml
```

Run SwiftLint on a macOS/Xcode machine:

```bash
bash scripts/ci/select_xcode.sh
swiftlint lint --config .swiftlint.yml --reporter github-actions-logging
```

Run deterministic XCTest coverage:

```bash
bash scripts/ci/select_xcode.sh
DESTINATION="$(python3 scripts/ci/select_ios_simulator.py --print-destination)"
xcodebuild \
  -project GradeDraft.xcodeproj \
  -scheme GradeDraft \
  -destination "$DESTINATION" \
  -derivedDataPath /tmp/GradeDraftDerivedData \
  -resultBundlePath /tmp/GradeDraftUnitTests.xcresult \
  -skip-testing:GradeDraftTests/GradeDraftScreenshotTests \
  ARCHS=arm64 \
  clean test
```

Run core page screenshot coverage:

```bash
bash scripts/ci/select_xcode.sh
DESTINATION="$(python3 scripts/ci/select_ios_simulator.py --print-destination)"
xcodebuild \
  -project GradeDraft.xcodeproj \
  -scheme GradeDraft \
  -destination "$DESTINATION" \
  -derivedDataPath /tmp/GradeDraftCorePageScreenshotDerivedData \
  -resultBundlePath /tmp/GradeDraftCorePageScreenshots.xcresult \
  -only-testing:GradeDraftTests/GradeDraftScreenshotTests \
  ARCHS=arm64 \
  test
```

Run the unsigned Release build:

```bash
bash scripts/ci/select_xcode.sh
xcodebuild \
  -project GradeDraft.xcodeproj \
  -scheme GradeDraft \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath /tmp/GradeDraftReleaseDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Artifacts

`xcode-unit-tests` uploads `xcode-unit-tests-output`, including the unit `.xcresult` and Xcode logs.

`screenshot-smoke` uploads `xcode-screenshot-smoke-output` and `gradedraft-screenshots`. The separate `core-page-screenshots` job uploads `xcode-core-page-screenshots-output` and `gradedraft-core-page-screenshots`. The screenshot tests write stable PNG names:

- `01-home.png`
- `02-classes.png`
- `03-class-detail-roster.png`
- `04-assignments.png`
- `05-assignment-overview.png`
- `06-student-work.png`
- `07-review.png`
- `08-review-scanned-text.png`
- `09-final-review.png`
- `10-exports-restore.png`
- `11-settings-local-privacy.png`
- `12-rubric-instructions.png`

`release-build` uploads `xcode-release-build-output`.

To inspect an `.xcresult` locally on macOS, download the artifact and run:

```bash
xcrun xcresulttool get --path GradeDraftUnitTests.xcresult --format json
open GradeDraftUnitTests.xcresult
```

## Adding Swift Files

Add new Swift files to the Xcode project target when adding them to `GradeDraft/` or `GradeDraftTests/`. `scripts/ci/check_xcode_project_membership.py` fails if a Swift filename exists on disk but is absent from `GradeDraft.xcodeproj/project.pbxproj`.

## CI Contract

`scripts/ci/check_ci_contract.py` intentionally fails if the workflows lose required properties: explicit `macos-26` runners, minimal permissions, concurrency, job timeouts, direct no-network and export-hardening guardrails, Xcode/simulator selector scripts, screenshot separation, core page screenshot verification, release build verification, and artifact uploads.

When CI fails, do not delete tests, mark deterministic tests as allowed failures, switch back to `macos-latest`, remove local-first guardrails, or move screenshot tests back into the deterministic job. Fix the implementation or the contract deliberately.

## Branch Protection

Required before merging ordinary PRs:

- `static-policy`
- `workflow-lint`
- `swiftlint`
- `xcode-unit-tests`

Recommended for pre-release, release tags, and manual release confidence:

- all PR-required jobs
- `core-page-screenshots`
- `screenshot-smoke`
- `release-build`
- `ci-summary`

`screenshot-smoke` can be made PR-required later if its runtime and visual stability stay acceptable.
