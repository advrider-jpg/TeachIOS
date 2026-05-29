# Decisions Ledger (append-only)

## D001 — Local-only core workflow

Date: Unknown
Status: Active
Decision: Keep core grading local-only: no backend, cloud OCR, cloud grading fallback, no analytics SDK, no account-login requirement, and no network entitlement in the default path.
Rationale: This posture is repeatedly defined as GradeDraft’s product invariant.
Consequences: Any networked feature must be explicitly introduced and documented before user-facing claims.
Source / Evidence: `README.md`, `docs/OFFLINE_CAPABILITY.md`.

## D002 — Teacher-controlled grading model

Date: Unknown
Status: Active
Decision: Maintain proposed-then-finalize flow where local AI drafts are suggestions and teacher review finalizes grading.
Rationale: Core proposition and anti-fake-state behavior depend on teacher final authority.
Consequences: Proposed totals/feedback cannot replace teacher finalization semantics.
Source / Evidence: `README.md`, `docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md`, `docs/ARCHITECTURE.md`.

## D003 — Explicit grading-state boundaries

Date: Unknown
Status: Active
Decision: Keep source input, OCR output, reviewed text, model draft, final review, export records, and audit events as separate layers/records.
Rationale: Collapsing these layers destroys staleness detection and auditability.
Consequences: Persistence and service interfaces must retain explicit boundaries.
Source / Evidence: `docs/ARCHITECTURE.md`, `docs/CORE_RULES.md`, `docs/TEST_PLAN.md`.

## D004 — Normalized GRDB product schema active with legacy payload backup

Date: 2026-05-28
Status: Active
Decision: Use GRDB normalized product tables for the local app workflow. Retain legacy JSON payload rows only as a lossless compatibility and backup/migration safety layer.
Rationale: PDF import/export, OCR line review, evidence traceability, curriculum mapping, roster, and backup/restore require explicit durable records.
Consequences: Do not describe persistence as JSON-only or deferred. Future work may further split repositories, but the product feature claim is normalized local persistence with compatibility payloads retained.
Source / Evidence: `GradeDraft/Persistence/Database.swift`, `docs/DATA_MODEL_V3.md`, `docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md`.

## D005 — Local AI availability gates drafting

Date: Unknown
Status: Active
Decision: Foundation Models unavailability blocks draft generation; no cloud substitute.
Rationale: A local grading availability check preserves offline and privacy posture.
Consequences: Draft path must fail openly when local AI is unavailable.
Source / Evidence: `README.md`, `docs/OFFLINE_CAPABILITY.md`, `GradeDraft/Services/FoundationModelGradingService.swift`.

## D006 — Student/audit export separation

Date: Unknown
Status: Active
Decision: Maintain strict student vs teacher-audit separation: student reports exclude private teacher notes by default; teacher-audit reports may include sensitive context.
Rationale: Prevents exposure of private notes and preserves reporting semantics.
Consequences: Export builders and labels must enforce the split.
Source / Evidence: `README.md`, `docs/OFFLINE_CAPABILITY.md`, `GradeDraft/Export/MarkdownReportBuilder.swift`.
Source / Evidence: `README.md`, `docs/OFFLINE_CAPABILITY.md`, `GradeDraft/Export/CSVExportService.swift`.

## D007 — Strict PR review against prompt

Date: 2026-05-28
Status: Active
Decision: When a user provides a PR link after a prompt, future sessions must inspect the live PR against the prompt in maximum depth and request a full-completion fix if anything is incomplete.
Rationale: This is required to prevent partial compliance and silent drift.
Consequences: Prompt-derived scope is enforced end-to-end; no phased follow-up or “good enough” completion is accepted for PR mismatches.
Source / Evidence: Same-thread user instruction in this thread.
