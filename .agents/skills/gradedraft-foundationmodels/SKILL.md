---
name: gradedraft-foundationmodels
description: Preserve local-only Foundation Models behavior and avoid fake AI readiness or grade simulation.
---

Use this skill whenever touching AI grading, prompt flow, or local model gating.

Required file context:
- `GradeDraft/Services/FoundationModelGradingService.swift`
- `GradeDraft/Services/GradingService.swift`
- `GradeDraft/Models/GradeDraftModels.swift`
- `docs/OFFLINE_CAPABILITY.md`
- `docs/TEST_PLAN.md`

Non-negotiables:
- Keep draft generation strictly local; if Foundation Models is unavailable, grading must be blocked with explicit user feedback.
- Never add cloud inference fallback or any hidden remote path.
- Never return mocked `GradeDraftResult` values when the model path is unavailable or failed.
- Maintain clear separation between proposed and final points.

Editing workflow:
1. Confirm build-time API compatibility (imports, types, availability checks) in `FoundationModelGradingService.swift`.
2. Confirm runtime gating in `GradingService` call sites and user actions.
3. Confirm model failure paths preserve readable user-facing reasons and auditability.

Truth checks:
- If the model output is missing, malformed, or untrusted, fail clearly and visibly.
- If user retries after failure, call the same guarded path; avoid silently returning stale results.
- For any local AI text parsing fallback, document exact parser expectations and failure handling.

Validation:
- Prefer direct alignment with `docs/TEST_PLAN.md` tests for missing-local-AI and unavailable-state behavior.
- For each grading change, ensure release gates include Xcode compile checks (Foundation Models symbols, SDK version compatibility).
