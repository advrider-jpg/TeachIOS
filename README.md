# GradeDraft v3

GradeDraft is a local-first iOS/iPadOS starter repo for a teacher-controlled, text-only grading assistant.

The core lane is:

```text
scan/import/paste student work -> local OCR where needed -> explicit teacher OCR review -> local rubric draft -> criterion-level teacher final review -> local export
```

The repo is deliberately scoped to text work. Handwriting, posters, physical models, diagrams, symbolic math, LMS sync, and visual-artifact grading are deferred unless and until they can be implemented without fake readiness.

## What changed in v3

v3 hardens the v2 scaffold around truth-state and auditability:

- Adds source-input records with local file references and deterministic content digests.
- Persists scanned/imported source images under Application Support instead of only retaining OCR text.
- Adds explicit OCR review states: `notNeeded`, `needsReview`, `reviewed`, and `blocked`.
- Blocks draft grading until OCR has been marked reviewed when a scan/photo source was used.
- Adds corrected/confirmed OCR-line fields and per-line teacher confirmation flags.
- Adds student/class metadata fields without introducing cloud accounts or sync.
- Adds answer-key and exemplar fields to the grading packet.
- Adds a simple structured rubric parser that assigns stable criterion IDs for point-bearing rubric lines.
- Adds packet fingerprints so drafts and final reviews become stale when text, rubric, answer key, exemplar, instructions, OCR status, or source references change.
- Adds `FinalCriterionScore` so teacher final points are separate from model-proposed points.
- Adds final-review status: `inProgress`, `approved`, and `stale`.
- Splits export into student-facing Markdown and teacher-audit Markdown.
- Ensures student exports exclude private teacher notes.
- Adds audit events and export records to the local assignment state.
- Expands tests for OCR gating, rubric parsing, structured-criterion completeness, final-score totals, and private-note export separation.

## Product promise

GradeDraft is not an autonomous grader. It is a teacher-controlled assistant:

1. The teacher supplies the rubric, answer key, exemplar, and custom grading instructions.
2. The app extracts text locally with Apple Vision when images are used.
3. The teacher reviews and confirms OCR text before grading.
4. The app proposes rubric scores and feedback using Apple’s on-device language model when available.
5. The teacher edits or approves each criterion before treating the grade as final.
6. The app preserves source input, OCR output, reviewed text, model proposal, final review, exports, and audit events as separate local records.

GradeDraft does **not** upload student work, rubrics, prompts, draft grades, or final grades to a server.

## Apple framework posture

- OCR: Vision / VisionKit.
- Local grading draft: Foundation Models, when available on supported devices.
- Storage: local JSON in Application Support for the scaffold; SQLite/SwiftData is a later production hardening pass.
- Export: explicit teacher-controlled local Markdown reports.
- Minimum deployment target in this scaffold: iOS 17.0.
- Foundation Models code is guarded with `canImport(FoundationModels)` and iOS availability checks.

If Foundation Models is unavailable, GradeDraft shows a local-unavailable state and refuses to generate an AI grade. It does not fall back to a cloud model.

## Local-only constraints

This repo intentionally contains:

- No backend.
- No `URLSession` use.
- No cloud OCR.
- No cloud grading.
- No analytics SDK.
- No remote rubric processing.
- No account login.
- No network entitlement request.

Run the guardrail before committing:

```bash
python3 scripts/no_network_scan.py
python3 scripts/repo_health.py
```

## Open in Xcode

1. Open `GradeDraft.xcodeproj` in Xcode 26 or later for Foundation Models development.
2. Select an iOS simulator or physical device.
3. For actual local AI grading, use a compatible physical device with Apple Intelligence enabled and the on-device model ready.
4. Build and run.

This package was source-checked in a non-Xcode environment, but it was not compiled against Apple’s iOS SDK here.

## First user flow

1. Create or select an assignment.
2. Add student/class metadata if useful.
3. Apply a rubric template or paste a rubric.
4. Optionally add custom instructions, an answer key, and an exemplar.
5. Scan/import student work or paste text directly.
6. If OCR was used, review the extracted text and tap **Mark OCR Reviewed**.
7. Tap **Draft Grade**.
8. Review criterion scores, evidence, explanations, flags, and feedback.
9. Tap **Start Final Review**.
10. Edit final criterion points and feedback as needed.
11. Tap **Approve Final Grade**.
12. Export a student report or teacher audit report.

## Repository layout

```text
GradeDraft/
  GradeDraft.xcodeproj/
  GradeDraft/
    GradeDraftApp.swift
    ContentView.swift
    GradeDraftViewModel.swift
    Models/
    Services/
    Views/
    Resources/
  GradeDraftTests/
  docs/
  scripts/
```

## Next implementation pass

The highest-value next pass is replacing local JSON persistence with a real SQLite/SwiftData repository layer and migration plan, followed by side-by-side source-image OCR review, PDF export, and UI tests.
