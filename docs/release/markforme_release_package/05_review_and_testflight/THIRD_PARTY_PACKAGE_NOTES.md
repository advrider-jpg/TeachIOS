# Third-party package notes

## Source: DEPENDENCIES.md

# Dependency plan and package linkage

This document records MarkForMe's Swift Package Manager dependency set, target linkage, license posture, and privacy relevance for the local-first release candidate.

`Package.resolved` is still pending Xcode generation in this non-Xcode implementation environment. Run `xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft` on macOS/Xcode, commit the generated resolution file, and update exact resolved revisions before TestFlight.

## Runtime libraries linked to the app target

| Package | Repository | Version policy in project | Product | Target | Purpose | License | Ships in app binary | Privacy/network posture |
|---|---|---|---|---|---|---|---:|---|
| GRDB.swift | `https://github.com/groue/GRDB.swift.git` | up to next major from `6.0.0` | GRDB | MarkForMe | SQLite/GRDB persistence for assignments, rubrics, records, audits, rosters, source records, and final reviews. | MIT | yes | Local SQLite code only; no runtime network path used by MarkForMe. |
| swift-markdown | `https://github.com/swiftlang/swift-markdown.git` | up to next major from `0.2.0` | Markdown | MarkForMe | Markdown/rubric parsing support. | Apache-2.0 | yes | Local parsing only. |
| TPPDF | `https://github.com/techprimate/TPPDF.git` | up to next major from `2.0.0` | TPPDF | MarkForMe | Styled student and teacher PDF export rendering in `Export/PDFExportService.swift` (heading hierarchy, inline emphasis, lists, repeating header/footer, page numbers, automatic pagination), with a `UIGraphicsPDFRenderer` fallback. | MIT | yes | Local document rendering only. |
| ZIPFoundation | `https://github.com/weichsel/ZIPFoundation` | up to next major from `0.9.0` | ZIPFoundation | MarkForMe | ZIP archive export/import and backup archive handling. | MIT | yes | Local archive code only; project docs note recent ZIPFoundation releases include privacy-manifest maintenance. |

## Removed from the dependency set

| Package | Reason removed | Replacement |
|---|---|---|
| SwiftCSV | Library is parse-only and provides no spreadsheet formula-injection hardening. | CSV is implemented natively in `Export/CSVCodec.swift` (RFC 4180 quoting and parsing) and `Export/CSVExportService.swift`, which neutralizes formula-like cells (`=`, `+`, `-`, `@`) before writing. This is safer and more complete than the library, so SwiftCSV was unlinked from the app target. |
| swift-dependencies | The app already uses initializer-based dependency injection throughout (`GradeDraftViewModel` receives its store, OCR, grading, file-manager, and export-authentication collaborators as `init` parameters). The Point-Free `Dependencies` container in `Core/AppDependencies.swift` was defined but referenced nowhere — dead scaffolding. | Removed the package and deleted `Core/AppDependencies.swift`, leaving one coherent DI approach. |

## Test-only library

| Package | Repository | Version policy in project | Product | Target | Purpose | License | Ships in app binary | Privacy/network posture |
|---|---|---|---|---|---|---|---:|---|
| swift-snapshot-testing | `https://github.com/pointfreeco/swift-snapshot-testing.git` | up to next major from `1.0.0` | SnapshotTesting | GradeDraftTests | Snapshot tests for UI regression. | MIT | no | Test-only. It must not be linked into the app target. |

## Tooling only

| Tool | Integration | Target link | Purpose | License |
|---|---|---|---|---|
| SwiftLint | CI/Homebrew tool | not linked | Linting in CI. | MIT |
| Python stdlib curriculum generator | `scripts/curriculum/build_acara_curriculum_catalog.py` | not linked | Developer-side MRAC/workbook normalization and validation. | repository code |

## Privacy and App Store SDK review notes

None of the runtime packages are cloud SDKs, analytics SDKs, login providers, crash-reporting SDKs, payment/entitlement SDKs, telemetry SDKs, or hosted curriculum clients. MarkForMe uses them for local persistence, local parsing, local PDF/ZIP/CSV export, and local dependency wiring. Build hosts may contact GitHub through the normal Swift Package Manager resolution process, but app runtime code does not call package repository URLs or download curriculum data.

Before release, update this document with the exact resolved version/revision from `Package.resolved` and verify whether each package has a privacy manifest/signature status relevant under Apple's current third-party SDK policy.


## Source: OSS_REVIEW.md

# OSS dependency review

MarkForMe remains local-first and does not require backend credentials, telemetry, analytics, accounts, hosted curriculum downloads, remote inference, or cloud OCR for grading, OCR, rubric, curriculum, or export paths.

## Reviewed package set

| Package | License | Maintenance/currentness notes from review | Accepted use | Rejected risks |
|---|---|---|---|---|
| GRDB.swift | MIT | Widely used Swift SQLite toolkit; current public information showed active releases. | Runtime persistence. | No runtime network/API service dependency accepted. |
| swift-markdown | Apache-2.0 | Official Swift project package for parsing/building/analyzing Markdown. | Runtime rubric/Markdown parsing support. | No hosted parsing service accepted. |
| TPPDF | MIT | Swift Package Index and upstream repository show maintained PDF generation package. | Runtime PDF export rendering (styled student/teacher reports in `PDFExportService`). | No SaaS PDF rendering accepted. |
| ZIPFoundation | MIT | Upstream project supports reading/creating/modifying ZIP archives and has privacy-manifest-related release maintenance. | Runtime archive/backup export. | No cloud storage/sync accepted. |
| swift-snapshot-testing | MIT | Point-Free snapshot test package. | Test target only. | Must not link into app target. |

## Packages/examples considered but not added

| Candidate | Reason rejected |
|---|---|
| SwiftCSV | Removed from the dependency set. CSV is implemented natively in `Export/CSVCodec.swift` (RFC 4180 quoting/parsing) and `Export/CSVExportService.swift`, which additionally neutralizes spreadsheet formula-injection (`=`, `+`, `-`, `@` leading cells) before writing — a hardening step SwiftCSV does not provide, and SwiftCSV does not write CSV at all. Keeping the native implementation is safer and more complete than the library. |
| swift-dependencies | Removed from the dependency set. The app already uses plain initializer-based dependency injection (the view model takes its store, OCR, grading, file-manager, and export-authentication collaborators as `init` parameters). The Point-Free `Dependencies` container was defined once and referenced nowhere, so it was dead scaffolding rather than wiring. Removing it leaves a single, coherent DI style. |
| LicensePlist / LicenseList | Not added because the current patch adds no new third-party runtime packages; manual notices and dependency docs are sufficient for source review, and adding another tool would require package resolution and license review. |
| Runtime JSON-LD/RDF parser packages | Not added because the curriculum pipeline is developer-side and Python stdlib parsing is sufficient for committed resources; adding a runtime parser would increase app size and review surface. |
| Cloud OCR, cloud AI, Firebase, RevenueCat, Sentry, Amplitude, Mixpanel, login/OAuth SDKs | Rejected because they conflict with MarkForMe's local-first, no-runtime-network, no-cloud-fallback, no-telemetry boundaries. |
| Hosted curriculum download clients | Rejected because runtime curriculum download is outside the product boundary; only developer-side source refresh is permitted. |

## Privacy posture

The accepted package set does not add runtime network calls, telemetry, analytics, accounts, cloud services, or SaaS dependencies in MarkForMe's app target. Third-party code ships only where necessary for local persistence, local parsing, local exports, and dependency control. SnapshotTesting is test-only.

`Package.resolved` and exact resolved revisions remain pending Xcode package resolution before TestFlight. This is documented as a release blocker rather than silently treated as complete.
