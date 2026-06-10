# Privacy Review

## Baseline conclusion
Recommended App Store privacy label remains **Data Not Collected** only while the final release contains no developer-accessible data transmission, analytics, crash reporting, ads, accounts, cloud OCR, cloud AI, backend sync, hosted curriculum downloads, or support-bundle upload.

## Evidence reviewed
- `scripts/no_network_scan.py`
- `scripts/export_hardening_scan.py`
- `scripts/ci/check_release_readiness_static.py`
- `GradeDraft/Resources/PrivacyInfo.xcprivacy`
- `GradeDraft/Resources/Info.plist`
- `GradeDraft/AppRouting.swift`
- `GradeDraft/AppIntents/GradeDraftAppIntents.swift`
- `docs/DEPENDENCIES.md`
- `docs/OSS_REVIEW.md`
- bundled Australian Curriculum catalog manifest and generator

## App data handled locally
- student names and local IDs
- class names
- scanned work, images, and PDFs
- OCR text and review status
- rubrics, answer keys, exemplars, and teacher instructions
- mapped curriculum references
- draft feedback
- final scores and feedback
- private teacher notes
- exports and backups
- temporary Shortcut handoff payloads for pasted student work

## Data transmitted to developer
None in the core workflow.

## Tracking
None. `PrivacyInfo.xcprivacy` sets `NSPrivacyTracking` to false and declares no tracking domains.

## Collected data declaration
`NSPrivacyCollectedDataTypes` is empty because the app has no developer-accessible data transmission path in the audited runtime code.

## Required-reason API declaration
The app privacy manifest declares:

| Category | Reason | Why this app uses it |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | Stores only app-private launch-route metadata for Shortcuts/App Intents. Sensitive student-work handoff text is not stored in `UserDefaults`. |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | Reads app-container file metadata while purging expired local Shortcut payload files and maintaining local file-protection/backup-exclusion posture. |

## Sensitive App Intent handoff
`AddPastedStudentWorkIntent` now stores pasted student work in a protected local file under the app container and writes only an opaque UUID token to `UserDefaults`. The app consumes and deletes the file when handling the launch request. Legacy v1 launch requests that contained `payloadText` are consumed from `UserDefaults`, dropped from the migrated request model, and not re-encoded with student work.

## Export and clipboard privacy posture
Teacher-only exports remain warning-gated and local-authentication-gated where available. Text copied to the clipboard uses a local-only pasteboard item with a short expiration window rather than `UIPasteboard.general.string`.

## Third-party SDKs
Runtime packages are GRDB.swift, swift-markdown, TPPDF, and ZIPFoundation. swift-snapshot-testing is test-only. No package introduces runtime network calls, telemetry, accounts, analytics, or cloud services in Mark My Work’s app path based on the current static review.

## Reviewer caveat
This privacy conclusion is invalid if future changes add developer-accessible data collection, cloud services, account identifiers, analytics, telemetry, remote support uploads, hosted curriculum updates, remote crash reporting, or runtime network calls.
