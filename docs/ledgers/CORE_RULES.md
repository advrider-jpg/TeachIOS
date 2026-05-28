# Core Rules

This file records only the repository’s foundational invariants. It is not a roadmap, task list, issue tracker, validation report, or speculative rule catalog.

A rule belongs here only if all or nearly all of the following are true:

1. It has been true since the beginning of the project, or appears foundational to the original design.
2. It is repo-wide or architecture-defining, not merely a current implementation detail.
3. Violating it would materially change what the project is.
4. It is supported by clear repo evidence, existing docs/tests/build structure, or explicit same-thread instruction.
5. It should constrain future agents even when the user gives a broad implementation request.

If uncertain, do not include the rule.

## Core Rules

## C001 — Local-only core workflow

Rule:
The core grading workflow must not require a server, backend, network connection, analytics SDK, cloud OCR, cloud grading, remote rubric processing, account login, or network entitlement.

Why it matters:
This is the project’s product and privacy posture; changing it materially changes what GradeDraft is.

Evidence:
`README.md` (explicitly lists no backend, no cloud OCR, no cloud grading, no analytics, no account login, no network entitlement); `docs/OFFLINE_CAPABILITY.md`.

Validation:
`python3 scripts/no_network_scan.py` and `python3 scripts/repo_health.py` provide static guard checks.  
No dedicated automated check in CI confirms complete end-to-end cloud elimination.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.

## C002 — Teacher-controlled grading, not autonomous grading

Rule:
The app may generate draft proposals, but the teacher must review, edit, and finalize grades and feedback.

Why it matters:
Core product meaning depends on teacher authority over final outcomes.

Evidence:
`README.md` (the app is a teacher-controlled drafting assistant), `docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md`, and data model separation of proposed vs final points.

Validation:
Test intent in `docs/TEST_PLAN.md` and existing unit tests for review/path checks cover this boundary.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.

## C003 — Explicit state boundaries

Rule:
Keep source input, OCR output, teacher-reviewed text, grading packet, model draft, teacher final review, export, and audit events as separate state layers.

Why it matters:
Single-mutable-state behavior would break traceability and undermine correction workflows.

Evidence:
`docs/ARCHITECTURE.md` architectural flow; `docs/CORE_RULES.md`; data model files under `GradeDraft/Models` and services that pass these boundaries.

Validation:
No dedicated automated check identified.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.

## C004 — OCR review gating

Rule:
Draft grading must not proceed from OCR-derived work when required OCR review is incomplete.

Why it matters:
It prevents grading from unreviewed machine text extraction.

Evidence:
`README.md`, `docs/ARCHITECTURE.md`, `docs/OFFLINE_CAPABILITY.md`; implementation notes include explicit OCR states (`needsReview`, `reviewed`, `blocked`) and blocking behavior.

Validation:
Unit test intent in `docs/TEST_PLAN.md` covers OCR gating; no dedicated CI stage was asserted as complete in this session.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.

## C005 — Grade only reviewed text

Rule:
Grading must use reviewed text, not raw OCR or source image content, as the grading input.

Why it matters:
Reviewed text is the explicit teacher-confirmed basis for all scoring.

Evidence:
`docs/ARCHITECTURE.md` explicitly names `reviewedStudentText` as the grading input; model/docs guard this boundary.

Validation:
No dedicated automated check identified.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.

## C006 — Evidence-grounded criterion scores

Rule:
Each proposed criterion score must cite evidence or be explicitly marked for teacher review.

Why it matters:
Prevents silent inference without traceability to student work.

Evidence:
`docs/CORE_RULES.md` and `docs/TEST_PLAN.md` requirements, including evidence-review behavior.

Validation:
Source-level tests around evidence and teacher-review flags are listed in `docs/TEST_PLAN.md`.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.

## C007 — Deterministic totals

Rule:
Totals must be calculated deterministically from stored criterion points, not trusted from model-written totals.

Why it matters:
Prevents model output from silently defining grade math.

Evidence:
`README.md`, `docs/TEST_PLAN.md`, tests that compare deterministic total behavior.

Validation:
No dedicated automated check identified in this session.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.

## C008 — Separate proposed and final points

Rule:
Model proposal points and teacher final points must remain separate records.

Why it matters:
This protects teacher authority and supports stale/rollback semantics.

Evidence:
`README.md` and architecture/data model notes on `FinalCriterionScore`/final review separation.

Validation:
No dedicated automated check identified in this session.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.

## C009 — Staleness on packet changes

Rule:
Draft and final reviews must become stale when inputs in the grading packet change.

Why it matters:
It prevents reuse of outdated judgments after rubric/text/OCR/source changes.

Evidence:
`README.md`, `docs/ARCHITECTURE.md`, and v3 notes describe fingerprint-based stale behavior.

Validation:
No dedicated automated check identified.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.

## C010 — Export-state separation

Rule:
Student-facing exports exclude private teacher notes by default; teacher-audit exports may include private notes and sensitive material with explicit sensitivity context.

Why it matters:
Protects student-facing outputs and report semantics.

Evidence:
`README.md`, `docs/OFFLINE_CAPABILITY.md`, export service behavior in `GradeDraft/Export`.

Validation:
No dedicated automated check identified in this session.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.

## C011 — No fake availability or fake success

Rule:
The app must not imply unavailable OCR, local AI, export, grading, or persistence paths are working. It must fail visibly when unsupported or failed.

Why it matters:
Silent placeholder behavior breaks trust and masks missing functionality.

Evidence:
Existing core rules in `docs/CORE_RULES.md`, `README.md`, and `docs/OFFLINE_CAPABILITY.md`.

Validation:
No dedicated automated check identified; runtime behavior is verified via source and tests where possible.

Release impact:
Violation of this rule is a release blocker unless the user expressly changes the rule.
