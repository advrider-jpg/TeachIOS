# Validation Ledger

This ledger records source-level validation expectations for the all-features completion patch.

## 2026-05-31 — Separate core page screenshot workflow

The repository now has a separate GitHub Actions workflow at `.github/workflows/core-page-screenshots.yml` (`GradeDraft Core Page Screenshots`) with one job:

- `core-page-screenshots`

It runs on pull requests, pushes to `main`, and manual dispatch. The job selects Xcode 26+ and an iOS 26+ iPhone simulator, runs only `GradeDraftTests/GradeDraftScreenshotTests`, verifies the complete expected PNG set, and uploads `xcode-core-page-screenshots-output` plus `gradedraft-core-page-screenshots`.

The screenshot XCTest manifest must match the concrete core page files in `GradeDraft/UI/Screens/*Screen.swift`, excluding only `ScreenModels.swift`.

Local reproduction on macOS/Xcode 26+:

```bash
bash scripts/ci/select_xcode.sh
DESTINATION="$(python3 scripts/ci/select_ios_simulator.py --print-destination)"
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -destination "$DESTINATION" -derivedDataPath /tmp/GradeDraftCorePageScreenshotDerivedData -resultBundlePath /tmp/GradeDraftCorePageScreenshots.xcresult -only-testing:GradeDraftTests/GradeDraftScreenshotTests ARCHS=arm64 test
```

## 2026-05-31 — Production CI gates

The primary GitHub Actions workflow is now `.github/workflows/swift.yml` (`GradeDraft CI`) with these PR-required checks:

- `static-policy`
- `workflow-lint`
- `swiftlint`
- `xcode-unit-tests`

Deeper validation runs on `main`, schedule, manual dispatch, or visual-check PRs:

- `screenshot-smoke`
- `release-build`
- `ci-summary`

Local static reproduction:

```bash
python3 scripts/repo_health.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
```

Apple SDK validation still requires macOS/Xcode 26+:

```bash
bash scripts/ci/select_xcode.sh
DESTINATION="$(python3 scripts/ci/select_ios_simulator.py --print-destination)"
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -destination "$DESTINATION" -derivedDataPath /tmp/GradeDraftDerivedData -resultBundlePath /tmp/GradeDraftUnitTests.xcresult -skip-testing:GradeDraftTests/GradeDraftScreenshotTests clean test
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -destination "$DESTINATION" -derivedDataPath /tmp/GradeDraftScreenshotDerivedData -resultBundlePath /tmp/GradeDraftScreenshotTests.xcresult -only-testing:GradeDraftTests/GradeDraftScreenshotTests test
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -configuration Release -destination "generic/platform=iOS" -derivedDataPath /tmp/GradeDraftReleaseDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Static validation to run after patch generation

Run from a clean copy of the uploaded ZIP after applying `GradeDraft_all_features_completion_v3.patch`:

```bash
patch -p1 < GradeDraft_all_features_completion_v3.patch
python3 scripts/repo_health.py
python3 scripts/no_network_scan.py
```

Also inspect the source tree for unresolved completion-language matches, verify that new Swift files are present in `GradeDraft.xcodeproj/project.pbxproj`, and confirm that no `.orig`, `.rej`, temporary patch file, build artifact, or generated junk file is included.

## Unit-test coverage added in source

The patch adds or updates tests for:

- Student and teacher PDF export file creation and export gating.
- Teacher ZIP archive, assignment gradebook archive, full backup archive, manifests, safe archive paths, backup round-trip, conflict handling, and source-file restoration.
- PDF import metadata construction and OCR-review gating.
- OCR page/line selection, edit, confirm, reject, document review state, reviewed-text updates, and grading gates.
- OCR-line evidence, manual evidence, evidence removal/clearing, source-reference alignment, bounding-box persistence, student-report privacy, and teacher-audit traceability.
- Markdown rubric heading/list/table parsing, level/band extraction, duplicate detection, stable IDs, warnings, and preview confirmation behavior.
- Curriculum catalog load/filter/map, prompt inclusion, audit-report provenance, persistence, and policy-claim guardrails.
- Roster CSV preview, duplicate detection, rejected rows, class/student/enrollment/assignment roster behavior, status matrix, and gradebook CSV.
- Normalized GRDB save/load, compatibility payload removal, legacy JSON migration, child record persistence, and roster/curriculum persistence.

## Runtime validation still required

Xcode or equivalent Apple SDK tooling must validate app/test target compilation, XCTest execution, UIKit/PDFKit PDF rendering and import, Vision/VisionKit OCR capture, Foundation Models API compatibility, SwiftUI file import/share-sheet behavior, and simulator/device smoke flows.

## 2026-05-30 — Apple Intelligence typed grading patch validation

Available in this environment:

```bash
python3 scripts/no_network_scan.py
python3 scripts/repo_health.py
```

Required outside this environment:

```bash
xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft
swiftlint lint --config .swiftlint.yml
xcodebuild test -project GradeDraft.xcodeproj -scheme GradeDraft -destination 'platform=iPhone Simulator,name=<available iPhone simulator destination>'
RUN_FOUNDATION_MODEL_DEVICE_TESTS=1 xcodebuild test -project GradeDraft.xcodeproj -scheme GradeDraft -destination 'platform=iOS,name=<connected Apple Intelligence device name>'
```

Xcode, simulator, and real-device Foundation Models validation were not run in this environment (Windows).
