---
name: gradedraft-core-rules
description: Enforce GradeDraft local-first and anti-fake-state behavior across coding, review, and workflow guidance.
---

Use this skill for every task in TeachIOS, regardless of scale. It defines the behavior constraints that keep sessions safe and truthful.

Start by grounding in repo truth:
- Read `README.md` and `docs/ARCHITECTURE.md`.
- Read `docs/OFFLINE_CAPABILITY.md` and `docs/TEST_PLAN.md`.
- Read the target files directly before proposing behavior changes.

Non-negotiable product rules:
- Do not add or imply backend, cloud OCR, cloud grading, analytics, or login features.
- Do not claim an action succeeded unless a real persisted state update or real backend/OS result confirms it.
- Do not introduce placeholder, mocked, demo-only, or simulated success states.
- Do not collapse explicit state layers: `source input -> OCR output -> reviewed text -> grading packet -> model draft -> final review -> export`.
- If a feature path is unsupported, disable the button/path and explain clearly to the user.

State and audit expectations:
- Preserve existing separation between draft points and final points.
- Preserve and reference `AssignmentRecord`-level audit fields when state transitions happen.
- Preserve staleness behavior; changing draft inputs should surface stale draft/final review states, not silently re-grade silently.
- Guard every user-facing "ready" state with validation against true model/availability/input prerequisites.

Implementation behavior checks:
- Prefer minimal edits in place; do not create parallel fake pathways.
- If you touch persistence, ensure writes are durable and recoverable (sorting, atomic writes, existing error types).
- For any "unavailable" condition, return explicit error signaling and visible UI disabled states, never silent fallback.
- Never edit unrelated files unless they block the task.

Testing and verification expectations:
- If you change behavior in `Services`, `Models`, or any state transitions, align with relevant `docs/TEST_PLAN.md` cases.
- Keep in mind `.github/workflows/swift.yml` is the repo's current gate; if behavior changes should be enforced by CI, ensure it remains honest.

If a requested behavior cannot be implemented correctly within this scaffold, stop implementation and report the concrete missing behavior and the safest disabled fallback.
