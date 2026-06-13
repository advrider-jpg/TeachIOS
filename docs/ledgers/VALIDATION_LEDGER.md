# Validation Ledger

This ledger records source-level validation expectations for the all-features completion patch.

## 2026-06-13 — PR CI repair validation

GitHub PR #44 first reported these failures on commit `5d0b93c`: `static-policy` failed because `repo_health.py` included release-readiness blockers, and `core-page-screenshots` failed during `xcodebuild -resolvePackageDependencies` because the Xcode project contained dangling references for the split model files.

Follow-up local validation passed in this Windows checkout after adding the missing model file references, strengthening Xcode project membership checks, and splitting release readiness from ordinary PR static health:

```bash
git diff --check
python3 scripts/repo_health.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

`python3 scripts/ci/check_release_readiness_static.py` still fails correctly with unresolved release blockers: no `Package.resolved`, support/contact not configured in `APP_STORE_METADATA.md` or `APP_REVIEW_NOTES.md`, and unrun simulator/device manual QA. That gate is now explicit manual/scheduled release validation rather than an ordinary PR merge gate.

## 2026-06-13 — Audit leftovers validation state

Available validation run on Windows after the structural split, split curriculum resources, rendered-only native UI snapshots, page-level OCR batch persistence, and stable workflow timeline identity work:

```bash
git diff --check
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

All commands above passed.

Aggregate repo health and release static readiness were run and still fail only on externally gated release evidence:

```bash
python3 scripts/ci/check_release_readiness_static.py
python3 scripts/repo_health.py
```

Current reported blockers:

- No `Package.resolved` exists; requires Xcode package resolution on macOS/Xcode.
- Release support/contact values are still intentionally marked not configured in `docs/release/APP_STORE_METADATA.md` and `docs/release/APP_REVIEW_NOTES.md` because no release-owner-controlled contact details were available in this environment.
- `docs/release/MANUAL_QA_RESULTS.md` records unrun simulator/device manual QA.

XcodeBuildMCP validation was attempted. `session_show_defaults` reported no configured project, scheme, or simulator, and `list_sims` failed with `spawn xcrun ENOENT`. Direct command probes also failed because this Windows host has no `xcodebuild`, `xcrun`, or `swiftlint`.

## 2026-06-12 — Ridiculously close audit validation state

Available static validation run on Windows in this session:

```bash
git diff --check
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

All commands above passed.

Release static readiness was run and intentionally failed open:

```bash
python3 scripts/ci/check_release_readiness_static.py
python3 scripts/repo_health.py
```

Current blockers reported by both release-readiness and aggregate repo health:

- No `Package.resolved` exists; run Xcode package resolution on macOS/Xcode and commit the generated lockfile before release readiness can pass.
- `docs/release/APP_STORE_METADATA.md` says release support/contact is not configured.
- `docs/release/APP_REVIEW_NOTES.md` says release support/contact is not configured.
- `docs/release/MANUAL_QA_RESULTS.md` records unrun simulator/device manual QA.

XcodeBuildMCP validation was attempted first. `session_show_defaults` reported no configured project, scheme, or simulator. `list_schemes` failed with `spawn xcodebuild ENOENT`; `list_sims` failed with `spawn xcrun ENOENT`. Shell checks also found no `xcodebuild`, `xcrun`, `swift`, or `swiftlint` on this Windows host.

Required outside this environment:

```bash
xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft
swiftlint lint --config .swiftlint.yml
DESTINATION="$(python3 scripts/ci/select_ios_simulator.py --print-destination)"
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -destination "$DESTINATION" -derivedDataPath /tmp/GradeDraftDerivedData -resultBundlePath /tmp/GradeDraftUnitTests.xcresult -skip-testing:GradeDraftTests/GradeDraftScreenshotTests ARCHS=arm64 clean test
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -destination "$DESTINATION" -derivedDataPath /tmp/GradeDraftScreenshotDerivedData -resultBundlePath /tmp/GradeDraftScreenshotTests.xcresult -only-testing:GradeDraftTests/GradeDraftScreenshotTests ARCHS=arm64 test
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -destination "$DESTINATION" -derivedDataPath /tmp/GradeDraftUISmokeDerivedData -resultBundlePath /tmp/GradeDraftUISmoke.xcresult -only-testing:GradeDraftUITests/GradeDraftCoreLaneUITests ARCHS=arm64 test
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -configuration Release -destination "generic/platform=iOS" -derivedDataPath /tmp/GradeDraftReleaseDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -configuration Release -destination "generic/platform=iOS" -archivePath /tmp/GradeDraft.xcarchive CODE_SIGNING_ALLOWED=NO archive
```

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
- `ui-smoke`

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

## 2026-05-31 — Mega production-readiness patch validation scope

Available in this non-Xcode implementation environment:

```bash
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
python3 scripts/repo_health.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_release_readiness_static.py
```

Required outside this environment:

```bash
xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft
xcodebuild test -project GradeDraft.xcodeproj -scheme GradeDraft -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)'
xcodebuild build -project GradeDraft.xcodeproj -scheme GradeDraft -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild archive -project GradeDraft.xcodeproj -scheme GradeDraft -configuration Release -archivePath build/GradeDraft.xcarchive
```

Manual physical-device validation is still required for camera OCR, LocalAuthentication export gates, share sheets, backup restore, Airplane Mode, and Foundation Models on Apple Intelligence-capable hardware.

## 2026-06-10 — Full audit hardening patch static validation

Available in this non-Xcode implementation environment after the hardening patch:

```bash
python3 scripts/repo_health.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_release_readiness_static.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

Required outside this non-Xcode implementation environment:

```bash
xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft
swiftlint lint --config .swiftlint.yml
DESTINATION="$(python3 scripts/ci/select_ios_simulator.py --print-destination)"
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -destination "$DESTINATION" -derivedDataPath /tmp/GradeDraftDerivedData -resultBundlePath /tmp/GradeDraftUnitTests.xcresult -skip-testing:GradeDraftTests/GradeDraftScreenshotTests ARCHS=arm64 clean test
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -destination "$DESTINATION" -derivedDataPath /tmp/GradeDraftScreenshotDerivedData -resultBundlePath /tmp/GradeDraftScreenshotTests.xcresult -only-testing:GradeDraftTests/GradeDraftScreenshotTests ARCHS=arm64 test
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -configuration Release -destination "generic/platform=iOS" -derivedDataPath /tmp/GradeDraftReleaseDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -configuration Release -destination "generic/platform=iOS" -archivePath /tmp/GradeDraft.xcarchive CODE_SIGNING_ALLOWED=NO archive
```

Xcode, SwiftLint, simulator, UIKit/PDFKit runtime, Vision/VisionKit OCR, Foundation Models, LocalAuthentication, share-sheet, and physical-device validation were not run in this Linux container.

## 2026-06-10 — Second-pass maximum-effort hardening validation scope

Available in this non-Xcode implementation environment after applying the second-pass incremental patch:

```bash
git apply --check mark_my_work_full_audit_hardening.patch
git apply mark_my_work_full_audit_hardening.patch
git diff --check
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_release_readiness_static.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

Additional patch-format validation required for generated artifacts:

```bash
git apply --check mark_my_work_second_pass_max_effort_incremental.patch
git apply mark_my_work_second_pass_max_effort_incremental.patch
git apply --check mark_my_work_consolidated_full_hardening_v2.patch
```

`python3 scripts/repo_health.py` remains the intended aggregate local static gate. If it is unavailable or times out in a constrained environment, run each component check above individually and record the timeout honestly.

Required outside this non-Xcode implementation environment:

```bash
xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft
swiftlint lint --config .swiftlint.yml
DESTINATION="$(python3 scripts/ci/select_ios_simulator.py --print-destination)"
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -destination "$DESTINATION" -derivedDataPath /tmp/GradeDraftDerivedData -resultBundlePath /tmp/GradeDraftUnitTests.xcresult -skip-testing:GradeDraftTests/GradeDraftScreenshotTests ARCHS=arm64 clean test
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -destination "$DESTINATION" -derivedDataPath /tmp/GradeDraftScreenshotDerivedData -resultBundlePath /tmp/GradeDraftScreenshotTests.xcresult -only-testing:GradeDraftTests/GradeDraftScreenshotTests ARCHS=arm64 test
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -configuration Release -destination "generic/platform=iOS" -derivedDataPath /tmp/GradeDraftReleaseDerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -configuration Release -destination "generic/platform=iOS" -archivePath /tmp/GradeDraft.xcarchive CODE_SIGNING_ALLOWED=NO archive
```

Simulator/device validation is still required for UIKit/PDFKit rendering, Vision/VisionKit OCR, Foundation Models availability, LocalAuthentication export gates, file importers, share sheets, Airplane Mode behavior, backup/restore UI copy, and physical-device source capture.

## 2026-06-12 — Ridiculously-close audit Windows validation

Passed in this Windows checkout after the audit hardening pass:

```bash
git diff --check
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

`python3 scripts/ci/check_release_readiness_static.py` fails correctly because release readiness is still blocked by:

- missing `Package.resolved`;
- support/contact URLs explicitly not configured in release docs; and
- unrun manual QA in `docs/release/MANUAL_QA_RESULTS.md`.

`python3 scripts/repo_health.py` passes the component static scans and then fails at the release static readiness gate for the same reasons above.

Unavailable in this Windows checkout: `xcodebuild`, `xcrun`, `swift`, and `swiftlint` are not installed, so package resolution, SwiftLint, Xcode build/test, XCUITest, simulator screenshots, Vision/VisionKit OCR runtime, Foundation Models runtime, LocalAuthentication, share sheets, and physical-device/manual QA remain required on macOS/Xcode or CI.

Follow-up export-risk consolidation validation in the same Windows checkout:

```bash
git diff --check
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

`python3 scripts/ci/check_release_readiness_static.py` and `python3 scripts/repo_health.py` still fail only at the release-readiness blockers listed above.

Follow-up curriculum index validation in the same Windows checkout:

```bash
git diff --check
python3 scripts/ci/check_curriculum_catalog.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
```

`python3 scripts/ci/check_release_readiness_static.py` fails correctly with the unresolved release blockers: no `Package.resolved`, support/contact not configured in release docs, and unrun manual QA. `python3 scripts/repo_health.py` runs the component scans successfully and then fails at that release-readiness gate.

Build iOS Apps / XcodeBuildMCP was checked with `session_show_defaults`; no project, scheme, or simulator defaults are configured in this session. `where.exe xcodebuild`, `where.exe xcrun`, `where.exe swift`, and `where.exe swiftlint` also failed to find Apple tooling, so Xcode package resolution, SwiftLint, XCTest, XCUITest, simulator/device runtime checks, and manual QA remain unavailable in this Windows checkout.

## 2026-06-13 — Dynamic Type button audit validation

Passed in this Windows checkout after the shared action-button Dynamic Type update:

```bash
git diff --check
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

`python3 scripts/ci/check_release_readiness_static.py` still fails correctly because release readiness remains blocked by the missing `Package.resolved`, unconfigured support/contact release docs, and unrun simulator/device manual QA. `python3 scripts/repo_health.py` runs the component scans successfully and then fails at that release-readiness gate.

Build iOS Apps / XcodeBuildMCP was checked again: `session_show_defaults` reported no configured project, scheme, or simulator defaults, and `list_sims` failed with `spawn xcrun ENOENT`. Simulator/device Dynamic Type XXL screenshots and VoiceOver inspection remain unavailable in this Windows checkout.

## 2026-06-13 — Import rollback and clipboard guard follow-up

Passed in this Windows checkout after adding focused regression coverage for failed import transactions and non-text clipboard export blocking:

```bash
git diff --check
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_curriculum_catalog.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
```

`python3 scripts/ci/check_release_readiness_static.py` fails correctly with unresolved release blockers: no `Package.resolved`, support/contact not configured in release docs, and unrun manual QA. `python3 scripts/repo_health.py` runs the component scans successfully and then fails at that release-readiness gate.

Build iOS Apps / XcodeBuildMCP was checked again: `session_show_defaults` reported no configured project, scheme, or simulator defaults, and `list_sims` failed with `spawn xcrun ENOENT`. Direct command probes also reported `xcodebuild: not found`, `xcrun: not found`, `swiftlint: not found`, and `actionlint: not found`; `python3 scripts/ci/select_ios_simulator.py` failed because `xcrun` was not found.

## 2026-06-13 — Routed export confirmation and selection hardening follow-up

Passed in this Windows checkout after routing guided-grading exports through the shared confirmation sheet, adding the core-lane export XCUITest fixture path, and hardening invalid assignment selection against fallback mutation:

```bash
git diff --check
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_curriculum_catalog.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
```

`python3 scripts/ci/check_release_readiness_static.py` fails correctly with unresolved release blockers: no `Package.resolved`, support/contact not configured in `APP_STORE_METADATA.md` or `APP_REVIEW_NOTES.md`, and unrun simulator/device manual QA. `python3 scripts/repo_health.py` runs the component scans successfully and then fails at that release-readiness gate.

## 2026-06-13 — Saved-assignment preflight for import/export side effects

Passed in this Windows checkout after adding a shared saved-assignment preflight for file-producing imports, all export kinds, and clipboard copy:

```bash
git diff --check
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_curriculum_catalog.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
```

`python3 scripts/ci/check_release_readiness_static.py` fails correctly with unresolved release blockers: no `Package.resolved`, support/contact not configured in `APP_STORE_METADATA.md` or `APP_REVIEW_NOTES.md`, and unrun simulator/device manual QA. `python3 scripts/repo_health.py` runs the component scans successfully and then fails at that release-readiness gate.

## 2026-06-13 — Saved-assignment preflight for previews and local AI

Passed in this Windows checkout after extending fail-closed saved-assignment checks to source lookup, clear-student-work, rubric/roster/curriculum previews and imports, AI readiness, AI packet preview, draft generation, and feedback rewrite:

```bash
git diff --check
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_curriculum_catalog.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
```

`python3 scripts/ci/check_release_readiness_static.py` fails correctly with unresolved release blockers: no `Package.resolved`, support/contact not configured in `APP_STORE_METADATA.md` or `APP_REVIEW_NOTES.md`, and unrun simulator/device manual QA. `python3 scripts/repo_health.py` runs the component scans successfully and then fails at that release-readiness gate.

## 2026-06-13 — Saved-assignment preflight closure for review and template actions

Passed in this Windows checkout after extending fail-closed saved-assignment checks to OCR review, final-review, template/rubric, pasted-text, curriculum map/unmap, and export audit-record helper boundaries:

```bash
git diff --check
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_curriculum_catalog.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
```

`python3 scripts/ci/check_release_readiness_static.py` fails correctly with unresolved release blockers: no `Package.resolved`, support/contact not configured in `APP_STORE_METADATA.md` or `APP_REVIEW_NOTES.md`, and unrun simulator/device manual QA. `python3 scripts/repo_health.py` runs the component scans successfully and then fails at that release-readiness gate. XcodeBuildMCP `session_show_defaults` reported no configured project, scheme, or simulator defaults, and XcodeBuildMCP `list_sims` failed with `spawn xcrun ENOENT`. Direct Windows command probes reported `xcodebuild`, `xcrun`, `swiftlint`, and `actionlint` unavailable, so Xcode package resolution, SwiftLint, XCTest, simulator/device QA, and actionlint cannot be completed in this environment.

## 2026-06-13 — Release evidence cleanup and stale expectation follow-up

Passed in this Windows checkout after adding release status/blocker evidence docs, removing release-package placeholder wording, enforcing release placeholder scans, and aligning stale batch/OCR XCTest expectations with fail-closed behavior:

```bash
git diff --check
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_curriculum_catalog.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
```

`python3 scripts/ci/check_release_readiness_static.py` fails correctly with unresolved release blockers: no `Package.resolved`, support/contact not configured in `APP_STORE_METADATA.md` or `APP_REVIEW_NOTES.md`, and unrun simulator/device manual QA. `python3 scripts/repo_health.py` runs the component scans successfully and then fails at that release-readiness gate.

XcodeBuildMCP `session_show_defaults` reported no configured project, scheme, or simulator defaults, and XcodeBuildMCP `list_sims` failed with `spawn xcrun ENOENT`. Direct Windows command probes reported `xcodebuild`, `xcrun`, `swiftlint`, and `actionlint` unavailable, so Xcode package resolution, SwiftLint, XCTest, simulator/device QA, and actionlint remain unavailable in this environment.

## 2026-06-13 — Accessibility labels, PR UI gate, and curriculum size guard closure

Passed in this Windows checkout after adding export/OCR accessibility source coverage, making `ui-smoke` a PR-required CI gate, and enforcing static size budgets for the split curriculum catalog resources:

```bash
git diff --check
python3 scripts/ci/check_ci_contract.py
python3 scripts/ci/check_route_and_export_truthfulness.py
python3 scripts/ci/check_xcode_project_membership.py
python3 scripts/no_network_scan.py
python3 scripts/export_hardening_scan.py
python3 scripts/ci/bad_string_scan.py
python3 scripts/ci/check_native_ui_refactor.py
python3 scripts/ci/check_ai_evaluation_fixtures.py
python3 scripts/ci/check_app_intents_safety.py
python3 scripts/ci/check_local_ai_tools.py
python3 scripts/ci/check_ai_prompt_safety.py
python3 scripts/ci/check_ai_batch_readiness.py
python3 scripts/ci/check_ai_packet_preview_screen.py
python3 scripts/ci/check_curriculum_catalog.py
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
```

`python3 scripts/ci/check_release_readiness_static.py` fails correctly with unresolved release blockers: no `Package.resolved`, support/contact not configured in `APP_STORE_METADATA.md` or `APP_REVIEW_NOTES.md`, and unrun simulator/device manual QA. `python3 scripts/repo_health.py` runs the component scans successfully and then fails at that release-readiness gate.

XcodeBuildMCP `session_show_defaults` reported no configured project, scheme, or simulator defaults, and XcodeBuildMCP `list_sims` failed with `spawn xcrun ENOENT`. Direct Windows command probes reported `xcodebuild`, `xcrun`, `swiftlint`, and `actionlint` unavailable, so Xcode package resolution, SwiftLint, XCTest, simulator/device QA, and actionlint remain unavailable in this environment.
