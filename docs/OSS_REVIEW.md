# OSS dependency review

Mark My Work remains local-first and does not require backend credentials, telemetry, analytics, accounts, hosted curriculum downloads, remote inference, or cloud OCR for grading, OCR, rubric, curriculum, or export paths.

## Reviewed package set

| Package | License | Maintenance/currentness notes from review | Accepted use | Rejected risks |
|---|---|---|---|---|
| GRDB.swift | MIT | Widely used Swift SQLite toolkit; current public information showed active releases. | Runtime persistence. | No runtime network/API service dependency accepted. |
| swift-markdown | Apache-2.0 | Official Swift project package for parsing/building/analyzing Markdown. | Runtime rubric/Markdown parsing support. | No hosted parsing service accepted. |
| TPPDF | MIT | Swift Package Index and upstream repository show maintained PDF generation package. | Runtime PDF export rendering. | No SaaS PDF rendering accepted. |
| ZIPFoundation | MIT | Upstream project supports reading/creating/modifying ZIP archives and has privacy-manifest-related release maintenance. | Runtime archive/backup export. | No cloud storage/sync accepted. |
| SwiftCSV | MIT | Lightweight local CSV parser. | Runtime roster/gradebook CSV handling. | No hosted CSV import accepted. |
| swift-dependencies | MIT | Point-Free dependency-control package; public package index indicates Swift 6 readiness. | Runtime dependency wiring. | No account/telemetry layer accepted. |
| swift-snapshot-testing | MIT | Point-Free snapshot test package. | Test target only. | Must not link into app target. |

## Packages/examples considered but not added

| Candidate | Reason rejected |
|---|---|
| LicensePlist / LicenseList | Not added because the current patch adds no new third-party runtime packages; manual notices and dependency docs are sufficient for source review, and adding another tool would require package resolution and license review. |
| Runtime JSON-LD/RDF parser packages | Not added because the curriculum pipeline is developer-side and Python stdlib parsing is sufficient for committed resources; adding a runtime parser would increase app size and review surface. |
| Cloud OCR, cloud AI, Firebase, RevenueCat, Sentry, Amplitude, Mixpanel, login/OAuth SDKs | Rejected because they conflict with Mark My Work's local-first, no-runtime-network, no-cloud-fallback, no-telemetry boundaries. |
| Hosted curriculum download clients | Rejected because runtime curriculum download is outside the product boundary; only developer-side source refresh is permitted. |

## Privacy posture

The accepted package set does not add runtime network calls, telemetry, analytics, accounts, cloud services, or SaaS dependencies in Mark My Work's app target. Third-party code ships only where necessary for local persistence, local parsing, local exports, and dependency control. SnapshotTesting is test-only.

`Package.resolved` and exact resolved revisions remain pending Xcode package resolution before TestFlight. This is documented as a release blocker rather than silently treated as complete.
