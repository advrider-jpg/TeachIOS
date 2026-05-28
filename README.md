# GradeDraft v2

GradeDraft is a local-first iOS/iPadOS starter repo for a teacher-controlled, text-only grading assistant.

It supports the intended first product lane:

```text
scan or import student text work -> local OCR -> teacher-reviewed text -> local rubric draft -> teacher final review -> local export
```

The repo is deliberately scoped to text work. Posters, physical models, diagrams, symbolic math, and visual-artifact grading are deferred.

## What changed in v2

v2 turns the first starter into a more complete product scaffold:

- Assignment history with create, duplicate, delete, and local JSON persistence.
- Built-in rubric templates for short answers, paragraph responses, essays, and lab write-ups.
- Assignment type metadata for grading context.
- OCR quality summaries, low-confidence warnings, and OCR evidence display.
- Strict grading prompt contract with a single JSON schema.
- More tolerant model-output parsing for camelCase and snake_case fields.
- Grade-draft normalization: deterministic totals, score clamping, missing-evidence review flags, and compliance notes.
- Teacher finalization state separate from the model draft.
- Local Markdown report export through explicit teacher sharing.
- Expanded tests for totals, validation, OCR quality, JSON extraction, report generation, and draft guardrails.
- Expanded offline/security docs and scripts.

## Product promise

GradeDraft is not an autonomous grader. It is a teacher-controlled assistant:

1. The teacher supplies the rubric, answer key, and custom grading instructions.
2. The app extracts text locally with Apple Vision.
3. The teacher reviews and edits the extracted text.
4. The app proposes rubric scores and feedback using Apple’s on-device language model when available.
5. The teacher approves or edits the final grade.
6. The app preserves draft and final states separately.

GradeDraft does **not** upload student work, rubrics, prompts, draft grades, or final grades to a server.

## Apple framework posture

- OCR: Vision / VisionKit.
- Local grading draft: Foundation Models, when available on supported devices.
- Storage: local JSON in Application Support.
- Export: explicit teacher-controlled local Markdown report.
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
```

## Open in Xcode

1. Open `GradeDraft.xcodeproj` in Xcode 26 or later for Foundation Models development.
2. Select an iOS simulator or physical device.
3. For actual local AI grading, use a compatible physical device with Apple Intelligence enabled and the on-device model ready.
4. Build and run.

The repo cannot be compiled in this environment because Xcode and the iOS SDK are not available here.

## First user flow

1. Create or select an assignment.
2. Apply a rubric template or paste a rubric.
3. Scan/import student work or paste text directly.
4. Review OCR and correct the reviewed student text.
5. Tap **Draft Grade**.
6. Review criterion scores, evidence, explanations, flags, and feedback.
7. Tap **Finalize Draft**.
8. Export a local Markdown report only if the teacher chooses to share it.

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

Recommended next steps are listed in `docs/V2_IMPLEMENTATION_NOTES.md`. The highest-value next pass is criterion-level editing in the final review screen, followed by PDF export and UI tests.
