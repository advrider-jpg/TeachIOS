# Codex Next-Pass Prompt

/goal Harden GradeDraft v3 into a more production-like single-submission MVP. Do not expand into handwriting, posters, LMS sync, cloud services, or visual artifact grading. Preserve the local-only posture and the strict separation between source input, OCR output, reviewed text, model draft, teacher final review, exports, and audit events.

## Repo-scoped Codex skills

These repo-local skills are now the preferred playbook for future sessions:

- `.agents/skills/gradedraft-core-rules/SKILL.md`: cross-cutting GradeDraft constraints and anti-fake-state doctrine.
- `.agents/skills/gradedraft-xcode-verify/SKILL.md`: local verification aligned to CI workflow.
- `.agents/skills/gradedraft-ocr-review/SKILL.md`: OCR review gating and low-trust text controls.
- `.agents/skills/gradedraft-export-safety/SKILL.md`: student/audit export separation and sensitive-data safety.
- `.agents/skills/gradedraft-foundationmodels/SKILL.md`: local AI availability, failure paths, and no-fallback behavior.

Required work:

1. Open the repo locally in Xcode 26+ and fix any compile errors caused by the exact installed Apple SDK, especially Foundation Models API names.
2. Do not add any cloud AI fallback, backend URL, analytics SDK, remote OCR, account login, or telemetry.
3. Replace the JSON persistence scaffold with either SQLite or SwiftData, but only if migrations and tests are included. Otherwise leave JSON intact and focus on UI/test hardening.
4. Add a side-by-side OCR review screen showing source image thumbnails, OCR line confidence, and reviewed text.
5. Add per-line OCR correction and teacher confirmation. Low-confidence/unconfirmed OCR must block grading.
6. Preserve local source image references and verify source files exist after scan/photo import.
7. Add evidence quote source references where possible. Do not fake bounding-box linkage if it is not implemented.
8. Keep final criterion points separate from proposed points. App-calculated totals must use final points for final review.
9. Student export must not include private teacher notes. Teacher audit export may include private notes and must be labeled sensitive.
10. Add UI tests for pasted-text flow, OCR-review blocking, staleness, final approval, and export separation.

Acceptance criteria:

- App builds in Xcode.
- Unit tests pass.
- No-network guardrail passes.
- Draft Grade is disabled when local AI is unavailable, rubric is missing, student text is missing, or OCR review is required.
- Final review can edit criterion points independently of proposed points.
- Editing text/rubric/instructions marks draft/final state stale.
- Student export excludes private notes.
- Teacher audit export includes audit state.
- No fake/demo grading behavior is introduced.
