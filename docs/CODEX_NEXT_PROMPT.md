# Codex Next-Pass Prompt

/goal Harden GradeDraft v3 into a more production-like single-submission MVP. Do not expand into handwriting, posters, LMS sync, cloud services, or visual artifact grading. Preserve the local-only posture and the strict separation between source input, OCR output, reviewed text, model draft, teacher final review, exports, and audit events.

## Repo-scoped Codex skills

These repo-local skills are now the preferred playbook for future sessions:

- `.agents/skills/gradedraft-core-rules/SKILL.md`: cross-cutting GradeDraft constraints and anti-fake-state doctrine.
- `.agents/skills/gradedraft-xcode-verify/SKILL.md`: local verification aligned to CI workflow.
- `.agents/skills/gradedraft-ocr-review/SKILL.md`: OCR review gating and low-trust text controls.
- `.agents/skills/gradedraft-export-safety/SKILL.md`: student/audit export separation and sensitive-data safety.
- `.agents/skills/gradedraft-foundationmodels/SKILL.md`: local AI availability, failure paths, and no-fallback behavior.

Required work (Completed in v3 Feature Slice):

1. [Done] Open the repo locally in Xcode 26+ and fix any compile errors caused by the exact installed Apple SDK, especially Foundation Models API names.
2. [Done] Do not add any cloud AI fallback, backend URL, analytics SDK, remote OCR, account login, or telemetry.
3. [Done] Replace/extend the JSON persistence scaffold with SQLite database storage managed via GRDB, using normalized schema tables.
4. [Done] Add a side-by-side OCR review screen showing source image thumbnails, OCR line confidence, and reviewed text.
5. [Done] Add per-line OCR correction and teacher confirmation. Low-confidence/unconfirmed OCR blocks grading.
6. [Done] Preserve local source image references and verify source files exist after scan/photo import.
7. [Done] Add evidence quote source references with bounding-box linkage and coordinates where available.
8. [Done] Keep final criterion points separate from proposed points. App-calculated totals use final points for final review.
9. [Done] Student export excludes private teacher notes. Teacher audit export includes private notes and is labeled sensitive.
10. [Done] Add tests for PDF/ZIP/archive, roster CSV setup, curriculum import mapping, and side-by-side OCR.

Next-Pass Objectives:

1. Build further UI/UX refinement on the side-by-side OCR panel to support fluid scrolling of large PDFs.
2. Run local simulator-based UI tests simulating multiple OCR confirmations and corrections.
3. Conduct profiling checks on memory footprint when handling multi-page high-resolution scans.
4. Verify Foundation Models responses on target Apple Silicon devices under iOS 18/iPadOS 18 frameworks.
