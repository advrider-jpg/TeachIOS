# GradeDraft CI

GradeDraft CI is layered so deterministic policy failures, Swift style failures, Xcode test failures, visual smoke failures, and Release build failures are diagnosed separately. The workflow lives at `.github/workflows/swift.yml` and is named `GradeDraft CI`.

## Jobs

| Job | Runner | PR required | Purpose |
| - | - | - | - |
| `static-policy` | `ubuntu-latest` | Yes | Runs repo health, no-network, export-hardening, bad implementation string, project membership, and CI contract guardrails. |
| `workflow-lint` | `ubuntu-latest` | Yes | Runs pinned `actionlint` plus the GradeDraft CI contract check. |
| `swiftlint` | `macos-26` | Yes | Selects Xcode 26+, then runs SwiftLint against `.swiftlint.yml`. |
| `xcode-unit-tests` | `macos-26` | Yes | Selects Xcode 26+ and an iOS 26+ iPhone simulator, resolves packages, and runs deterministic XCTest coverage while skipping screenshot tests. |
| `screenshot-smoke` | `macos-26` | No for ordinary PRs | Runs only `GradeDraftScreenshotTests` and uploads PNGs plus `.xcresult`. It runs on `main`, scheduled/manual runs, and PRs labeled `visual-check`. |
| `release-build` | `macos-26` | No for ordinary PRs | Builds Release for generic iOS with code signing disabled. It runs on `main`, scheduled, and manual runs. |
| `ci-summary` | `ubuntu-latest` | Optional | Writes a combined job-result summary and fails if any PR-required job failed. |

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
  clean test
```

Run screenshot smoke coverage:

```bash
bash scripts/ci/select_xcode.sh
DESTINATION="$(python3 scripts/ci/select_ios_simulator.py --print-destination)"
xcodebuild \
  -project GradeDraft.xcodeproj \
  -scheme GradeDraft \
  -destination "$DESTINATION" \
  -derivedDataPath /tmp/GradeDraftScreenshotDerivedData \
  -resultBundlePath /tmp/GradeDraftScreenshotTests.xcresult \
  -only-testing:GradeDraftTests/GradeDraftScreenshotTests \
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

`screenshot-smoke` uploads `xcode-screenshot-smoke-output` and `gradedraft-screenshots`. The screenshot tests write stable PNG names:

- `01-new-assignment.png`
- `02-ready-to-grade.png`
- `03-draft-generated.png`
- `04-approved-final-review.png`
- `05-class-gradebook.png`
- `06-manual-final-review.png`

`release-build` uploads `xcode-release-build-output`.

To inspect an `.xcresult` locally on macOS, download the artifact and run:

```bash
xcrun xcresulttool get --path GradeDraftUnitTests.xcresult --format json
open GradeDraftUnitTests.xcresult
```

## Adding Swift Files

Add new Swift files to the Xcode project target when adding them to `GradeDraft/` or `GradeDraftTests/`. `scripts/ci/check_xcode_project_membership.py` fails if a Swift filename exists on disk but is absent from `GradeDraft.xcodeproj/project.pbxproj`.

## CI Contract

`scripts/ci/check_ci_contract.py` intentionally fails if the workflow loses required properties: explicit `macos-26` runners, minimal permissions, concurrency, job timeouts, direct no-network and export-hardening guardrails, Xcode/simulator selector scripts, screenshot separation, release build verification, and artifact uploads.

When CI fails, do not delete tests, mark deterministic tests as allowed failures, switch back to `macos-latest`, remove local-first guardrails, or move screenshot tests back into the deterministic job. Fix the implementation or the contract deliberately.

## Branch Protection

Required before merging ordinary PRs:

- `static-policy`
- `workflow-lint`
- `swiftlint`
- `xcode-unit-tests`

Recommended for pre-release, release tags, and manual release confidence:

- all PR-required jobs
- `screenshot-smoke`
- `release-build`
- `ci-summary`

`screenshot-smoke` can be made PR-required later if its runtime and visual stability stay acceptable.
