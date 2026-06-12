# Privacy Review

## Baseline conclusion
Recommended App Store privacy label remains Data Not Collected only while the final release contains no developer-accessible data transmission, analytics, crash reporting, ads, accounts, cloud OCR, cloud AI, backend sync, hosted curriculum downloads, or support-bundle upload.

## Evidence reviewed
- `scripts/no_network_scan.py`
- `scripts/export_hardening_scan.py`
- `GradeDraft/Resources/PrivacyInfo.xcprivacy`
- `GradeDraft/Resources/Info.plist`
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

## Data transmitted to developer
None in the core workflow.

## Tracking
None.

## Third-party SDKs
Runtime packages are GRDB.swift, swift-markdown, TPPDF, ZIPFoundation, SwiftCSV, and swift-dependencies. swift-snapshot-testing is test-only. No package introduces runtime network calls, telemetry, accounts, analytics, or cloud services in MarkForMe’s app path.

## Privacy manifest status
`PrivacyInfo.xcprivacy` explicitly sets tracking to false and contains no tracking domains. The manifest must be revisited if any telemetry, crash reporting, support upload, cloud sync, cloud AI, hosted curriculum refresh, account, or analytics feature is added.

## Reviewer caveat
This privacy conclusion is invalid if future changes add developer-accessible data collection, cloud services, account identifiers, analytics, telemetry, remote support uploads, or runtime curriculum downloads.
