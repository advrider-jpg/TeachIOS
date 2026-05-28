# Dependency plan and package linkage

This document records the OSS dependency set introduced for the next implementation phase and where each package is linked in the local Xcode project.

## Required runtime libraries (app target)

| Package | Version policy | Product | Target link | Phase/use |
| - | - | - | - | - |
| `GRDB` (`https://github.com/groue/GRDB.swift.git`) | Up to next major (minimum `6.0.0`) | `GRDB` | `GradeDraft` | SQLite storage foundation for assignment/rubric/submission/audit record persistence. |
| `swift-markdown` (`https://github.com/swiftlang/swift-markdown.git`) | Up to next major (minimum `0.2.0`) | `Markdown` | `GradeDraft` | Parser surface for staged rubric parsing into criterion IDs, levels, and points. |
| `TPPDF` (`https://github.com/techprimate/TPPDF.git`) | Up to next major (minimum `2.0.0`) | `TPPDF` | `GradeDraft` | Export rendering for student-facing and teacher-audit PDFs. |
| `ZIPFoundation` (`https://github.com/weichsel/ZIPFoundation`) | Up to next major (minimum `0.9.0`) | `ZIPFoundation` | `GradeDraft` | `.gradedraft` bundle archive writer for assignment export/import staging. |
| `SwiftCSV` (`https://github.com/swiftcsv/SwiftCSV.git`) | Up to next major (minimum `0.8.0`) | `SwiftCSV` | `GradeDraft` | CSV roster and export interoperability with validation helpers. |
| `swift-dependencies` (`https://github.com/pointfreeco/swift-dependencies.git`) | Up to next major (minimum `0.1.0`) | `Dependencies` | `GradeDraft` | DI container for clocks, UUIDs, file access, persistence, OCR, grading, and export clients. |

## Test-only library

| Package | Version policy | Product | Target link | Phase/use |
| - | - | - | - | - |
| `swift-snapshot-testing` (`https://github.com/pointfreeco/swift-snapshot-testing.git`) | Up to next major (minimum `1.0.0`) | `SnapshotTesting` | `GradeDraftTests` | UI regression checks for non-AI screens while runtime logic remains unchanged. |

## Tooling only

| Tool | Integration | Target link |
| - | - | - |
| SwiftLint (`https://github.com/realm/SwiftLint`) | CI tool (`brew install swiftlint`) + `.swiftlint.yml` | Not linked in app/test targets |

## Deferred/no-runtime packages

- `swift-snapshot-testing` is intentionally test-only.
- SwiftLint is not linked into any runtime target; it is installed and executed in CI.
- Full parser/export/persistence migrations are deferred to follow-on passes and are currently represented by thin adapter stubs.
