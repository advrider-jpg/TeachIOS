# Codex next-pass prompt

/goal Continue GradeDraft v2 as a local-only iOS teacher grading assistant. Do not redesign the product. Preserve the zero-online posture: no backend, no `URLSession`, no cloud OCR, no cloud grading, no analytics/telemetry SDK, no account login, no remote sync. If Foundation Models is unavailable, fail closed and show local AI unavailable. Do not add a cloud fallback.

Source of truth: use the local repo files only.

Required next pass:

1. Implement criterion-level editing in `FinalGradeReviewView`.
   - Editable score per criterion.
   - Editable rating.
   - Editable explanation.
   - Editable evidence lines.
   - Deterministic totals recalculated after every edit.
   - Set `teacherEdited = true` on every final-review edit.
   - Do not let the model control final arithmetic.

2. Add local PDF export.
   - Render from local app state only.
   - Preserve draft/final distinction.
   - Include assignment metadata, final score if available, feedback, criteria, evidence, reviewed student text, and rubric.
   - Do not use server-side rendering.

3. Add focused tests.
   - Final review edit recalculates totals.
   - Export prefers final review over draft.
   - No evidence still forces teacher review.
   - No-network guardrail still passes.

4. Validate in Xcode.
   - Fix any Swift compile errors.
   - Validate the installed Foundation Models SDK call shape.
   - Keep every SDK adjustment local-only.

Acceptance criteria:

- `python3 scripts/no_network_scan.py` passes.
- Unit tests pass in Xcode.
- App can create an assignment, apply a template, paste student text, attempt local grade drafting, finalize, edit final review, and export locally.
- Unsupported devices/simulators show local AI unavailable with no cloud fallback.
