# OSS dependency review

The app remains local-first and does not require backend credentials for any grading, OCR, rubric, or export path in this phase.

## License posture

- GRDB.swift: MIT
- swift-markdown: Apache 2.0
- TPPDF: MIT
- ZIPFoundation: MIT
- SwiftCSV: MIT
- swift-dependencies: MIT
- swift-snapshot-testing: MIT
- SwiftLint: MIT

## Privacy and local-first notes

- All required runtime packages are integrated through Swift Package Manager and are expected to execute local code only for local persistence and file export flows.
- No cloud APIs, remote inference endpoints, or managed analytics SDKs are introduced by these dependencies.
- Package download metadata (repository URLs, SPM resolution files) appears only as build/dependency metadata and is not used by app logic at runtime.

## Operational risk notes

- Swift package metadata will resolve from GitHub during build tooling. Build hosts must allow package resolution as part of the normal Xcode toolchain process.
- The new OSS set does not in itself change teacher grading truth rules:
  - Grading only proceeds with rubric text and reviewed student text.
  - OCR-derived text still requires teacher review before grading.
  - Totals continue to be recalculated locally and deterministically from saved criterion values.
  - Student exports will continue to omit private teacher notes in this and future passes.
