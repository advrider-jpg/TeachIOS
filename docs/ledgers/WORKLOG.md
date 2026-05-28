# Worklog

## 2026-05-28 — Initial repo memory layer

- Files changed:
  - `AGENTS.md`
  - `docs/ledgers/PROJECT_LEDGER.md`
  - `docs/ledgers/DATA_LEDGER.md`
  - `docs/ledgers/DECISIONS_LEDGER.md`
  - `docs/ledgers/VALIDATION_LEDGER.md`
  - `docs/ledgers/CORE_RULES.md`
  - `docs/ledgers/WORKLOG.md`
- What was inferred:
  - Project name `GradeDraft` and the core local-first grading lane from repo docs.
  - Build/lint/test references documented in README, TEST_PLAN, and architecture/offline docs.
- What was unknown:
  - Exact current CI pass status, active simulator targets, and current Foundation Models SDK behavior.
- Commands run:
  - Repository inspection only; no validation/build commands were executed.
- Production code untouched:
  - Yes.
- Tests untouched:
  - Yes.
- Validation not run:
  - Yes; no commands executed in this pass.

## 2026-05-28 — Ledger tightening to repo-native memory format

- Files changed:
  - `AGENTS.md`
  - `docs/ledgers/CORE_RULES.md`
  - `docs/ledgers/PROJECT_LEDGER.md`
  - `docs/ledgers/DATA_LEDGER.md`
  - `docs/ledgers/DECISIONS_LEDGER.md`
  - `docs/ledgers/VALIDATION_LEDGER.md`
  - `docs/ledgers/WORKLOG.md`
- What was inferred:
  - Prior repository truths are already authoritative (`README.md`, `docs/ARCHITECTURE.md`, `docs/OFFLINE_CAPABILITY.md`, `docs/TEST_PLAN.md`, `docs/CORE_RULES.md`).
  - `docs/CORE_RULES.md` was not suitable as a canonical project memory ledger and now needs a pointer-oriented role.
  - SwiftLint appears to be part of CI-equivalent validation from repo guidance.
- What was unknown:
  - No session-level validation was executed; no new proof of passing gates was produced.
  - Whether the next pass intends immediate GRDB/SQLite migration remains an explicit project scope decision.
- Commands run:
  - Repository inspection only; no build/lint/tests were executed.
- Production code untouched:
  - Yes.
- Tests untouched:
  - Yes.
- Validation not run:
  - Yes; no commands executed in this pass.
