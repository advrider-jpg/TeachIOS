# GradeDraft Core Rules

1. No server dependency for core grading.
2. No student work upload in the default workflow.
3. No cloud OCR in the default workflow.
4. No cloud AI grading fallback.
5. No proposed grade without a rubric, answer key, exemplar, or teacher-provided grading standard.
6. No grading from OCR unless required OCR review has been completed.
7. Every proposed score must cite student evidence or be marked for teacher review.
8. The AI proposes; the teacher finalizes.
9. Final criterion points are separate from proposed criterion points.
10. The app calculates totals deterministically.
11. Raw source input, OCR output, reviewed text, model proposal, teacher edits, final grade, exports, and audit events remain separate records.
12. A draft or final review must become stale when its source packet changes.
13. Student-facing exports must exclude private teacher notes by default.
14. Teacher-audit exports are sensitive student records.
15. The UI must not imply that unavailable OCR, local AI, export, or grading functionality is working.
16. The app must fail openly on OCR failure, local AI unavailability, malformed model output, persistence failure, or export failure.
17. Handwriting, diagrams, posters, physical models, and visual artifacts require explicit teacher-confirmed evidence before grading.
18. Subjective criteria such as creativity, craftsmanship, effort, or presentation quality require teacher review and must not be presented as fully automated judgments.
