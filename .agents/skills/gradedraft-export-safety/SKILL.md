---
name: gradedraft-export-safety
description: Keep GradeDraft exports truthful, privacy-safe, and aligned to teacher/Student boundaries.
---

Use this skill for any export, report, or share-related change.

Required file context:
- `GradeDraft/Services/LocalJSONStore.swift`
- `GradeDraft/Models/GradeDraftModels.swift`
- `README.md`
- `docs/OFFLINE_CAPABILITY.md`
- `docs/TEST_PLAN.md`

Truth rules:
- Student export must only contain student-facing content and must not include private teacher notes or raw internal model artifacts.
- Teacher audit export may include sensitive fields only when explicitly marked in the report.
- Never claim an export completed if write-to-disk fails; surface the export error path visibly.

Checks to enforce:
- Confirm `studentMarkdown` and `teacherAuditMarkdown` differ by design.
- Confirm local paths, OCR metadata, source input counts, audit events, and final-review state are represented honestly in the audit report.
- Confirm sensitive output labels remain in place and user-visible when teacher-specific report is generated.
- Keep temporary file naming and cleanup behavior deterministic and failure-reporting, not best-effort fiction.

Behavior constraints:
- Do not add export formats that bypass existing local-only state capture.
- Do not downscope teacher/audit protections to satisfy formatting convenience.
- If a new report type is added, add/adjust tests before merge and note limitations in docs.

Before finishing an export change:
- Ensure `docs/TEST_PLAN.md` coverage includes both student/audit separation and sensitive-content assertions.
