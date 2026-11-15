# MarkForMe

MarkForMe is a local-first iPhone and iPad app that helps teachers mark text-based student work. The teacher supplies a rubric, scans or imports the work, checks the scanned text, and gets a suggested rubric score and feedback drafted on the device. The teacher edits and approves every criterion before a grade is final. MarkForMe is not an autonomous grader.

Nothing leaves the device: no backend, no cloud OCR or grading, no analytics, no account login and no network entitlement. Student work, rubrics, draft grades and final grades are never uploaded.

## Teacher use

1. Create a class and assignment, and add students by hand or from a roster CSV.
2. Apply or import a rubric (including Markdown rubrics), answer key, exemplar, custom instructions and Australian Curriculum references from the bundled offline catalog.
3. Scan, import a PDF or photo, or paste the student's work.
4. Review the scanned text beside the page image. Edit, confirm or reject each line; low-confidence lines need an explicit decision before the text counts as reviewed.
5. Draft with on-device AI where Apple Intelligence is available, or go straight to manual final review. If the on-device model is unavailable, MarkForMe says so and does not draft.
6. Edit each criterion's score, feedback and evidence, then approve the final grade.
7. Export a student PDF or Markdown report, a teacher record, a gradebook CSV, a ZIP archive or a full local backup, and restore a backup with a preview.

Student reports are available only after the teacher approves a current final review, and they leave out private teacher notes, model output, audit events and OCR internals. Teacher records, archives and backups are sensitive and teacher-only. Exported files are not encrypted once they leave the app.

## Development

Open `GradeDraft.xcodeproj` in Xcode 26 or later. The minimum deployment target is iOS 17.0; on-device drafting needs a compatible physical device with Apple Intelligence enabled.

| Purpose | Command |
|---|---|
| Repository health | `python3 scripts/repo_health.py` |
| No-network guardrail | `python3 scripts/no_network_scan.py` |
| Export hardening guardrail | `python3 scripts/export_hardening_scan.py` |
| Resolve Swift packages | `xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft` |
| Lint | `swiftlint lint --config .swiftlint.yml` |
| Unit tests | `xcodebuild test -project GradeDraft.xcodeproj -scheme GradeDraft -destination 'platform=iPhone Simulator,name=<iPhone simulator>'` |

The Python guardrails run anywhere; Xcode, simulator, Vision, PDFKit and Foundation Models behavior must be checked on macOS. CI jobs and local reproduction are described in [CI.md](docs/CI.md).

MarkForMe is not release-ready. TestFlight and App Store submission are blocked until package resolution is committed, Xcode validation and manual device QA are recorded, and real support and privacy URLs exist. See [RELEASE_BLOCKERS.md](docs/release/RELEASE_BLOCKERS.md).

## Documentation

- [AGENTS.md](AGENTS.md) and [PROJECT_RULES.md](PROJECT_RULES.md): operating and product rules.
- [CORE_RULES.md](docs/ledgers/CORE_RULES.md): foundational product invariants.
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) and [DATA_MODEL_V3.md](docs/DATA_MODEL_V3.md): structure and saved data.
- [OFFLINE_CAPABILITY.md](docs/OFFLINE_CAPABILITY.md): local-only posture.
- [TEST_PLAN.md](docs/TEST_PLAN.md) and [CI.md](docs/CI.md): verification.
- [Release documents](docs/release/): blockers, status, QA plan and App Store material.
