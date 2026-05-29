# Validation Ledger

This ledger records source-level validation expectations for the all-features completion patch.

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
