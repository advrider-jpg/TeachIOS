# Apple Intelligence Implementation

Mark My Work uses Apple Foundation Models only as a local draft-assistance path. It is not an autonomous grader, does not use cloud AI fallback, and does not make AI output final.

## Current source behavior

The current source path is:

```text
teacher-reviewed text
 -> grading packet
 -> prompt redaction
 -> AI readiness report
 -> packet preview
 -> conservative prompt budget plan
 -> read-only local tool policy / assignment-scoped lookup layer
 -> local Foundation Models typed generation
 -> progress / cancellation state
 -> deterministic validation
 -> optional local feedback rewrite for in-progress final reviews
 -> safe App Intent handoff into real in-app workflows
 -> teacher final review
```

`FoundationModelGradingService` remains behind `canImport(FoundationModels)` and iOS availability checks. If the framework, OS, device, Apple Intelligence setting, or model readiness is unavailable, draft generation fails visibly and manual final review remains available.

`LocalCapabilityBanner` now classifies those real availability messages into teacher-facing states: Apple Intelligence disabled, device not eligible, model not ready, Foundation Models unavailable, or local AI ready. The available state includes Airplane Mode/local-only QA reassurance; unavailable states keep manual final review visible and explicitly state that the app does not send student work to cloud AI as a fallback.

## Prompt redaction policy

Model-visible prompts are built from a sanitized packet view. The local assignment record may retain student and class data for teacher workflow, export, and audit, but the prompt path removes these fields by default:

- student display name;
- student ID;
- class group ID;
- class name;
- roster membership;
- source filenames; and
- local source file paths.

The model-visible prompt still includes assignment prompt, subject, grade/year level, assessment purpose, reviewed student text, rubric, answer key, exemplar, curriculum references, and selected AI constraint templates when supplied.

## Prompt versioning and fingerprints

The current prompt version is `gradedraft.foundationmodels.typed.v2`. Prompt fingerprints are generated from the exact prompt plan selected by the conservative budgeter. Draft audit records preserve prompt version, schema version, validator version, packet fingerprint, selected constraint-template fingerprint, generation mode, token estimate, and validation warnings.

## Packet preview behavior

Final Review, AI Readiness, App Intent routing, and the dedicated AI Packet Preview screen can prepare a local AI packet preview before generation. The preview is deterministic app behavior, not a model call. It shows:

- what reviewed content and grading materials will be included;
- what identity and local-device data is not sent to the model;
- planned generation mode;
- estimated input and reserved output token budget;
- prompt version and prompt fingerprint; and
- a technical prompt preview.

Preparing a packet preview does not create a draft, final score, export, or durable grading record. The dedicated preview screen is navigable from the `.packetPreview` launch route and is guarded by `scripts/ci/check_ai_packet_preview_screen.py` so it stays a non-generative inspection surface. The actual draft button still calls the guarded local generation path.

The AI Readiness Center and Rubric setup card are backed by the same `AIReadinessAnalyzer` and packet-preview state. They surface current local AI availability, packet blockers, prompt-injection warnings, sensitive-template reminders, prompt version, prompt fingerprint, packet fingerprint, included content, excluded identity/device data, and concrete next actions before the teacher drafts locally.

## Streaming, progress, and cancellation

Local draft and rewrite generation use the Foundation Models structured streaming API and collect the completed typed response before deterministic validation and storage. The UI publishes deterministic app-controlled progress stages:

- input validation;
- local AI availability check;
- packet budget planning;
- full-packet request or per-criterion generation;
- summary synthesis when needed;
- deterministic draft validation;
- local draft storage; and
- completed, cancelled, or failed terminal state.

Final Review exposes a Cancel control while the local draft task is cancellable. Cancellation cancels the app's running draft task and checks cancellation before saving. A cancelled draft does not write `latestDraft`, does not create final-review state, and surfaces "Local draft cancelled" instead of a misleading success state.

This is app-level request cancellation and progress over Foundation Models streaming requests. Token-by-token or field-by-field partial draft display is not exposed yet; physical-device validation must confirm how the installed Foundation Models runtime responds to cancellation while a model request is already executing.

If the Foundation Models runtime rejects a planned prompt for context size even after the conservative preflight estimate, `FoundationModelGradingService` retries with a smaller honest mode: full-packet failure falls back to compact/per-criterion planning, compact failure falls back to per-criterion planning, and per-criterion failure surfaces a prompt-too-large error. The recovery path does not truncate reviewed student text and does not use cloud fallback.

## Prompt-injection handling

Prompt v2 includes explicit authority and trust-boundary instructions. Reviewed student work, OCR text, imported source text, answer keys, exemplars, curriculum excerpts, file names, and source labels are treated as quoted evidence, not instructions.

The readiness analyzer flags common prompt-injection phrases in packet text. A flag does not silently rewrite or discard the teacher-reviewed text. It surfaces the risk and keeps teacher review explicit.

`CustomInstructionLinter` deterministically flags teacher custom instructions that appear to override the rubric, force full marks, grade by effort/intent, penalize handwriting in the text-evidence lane, use student background, remove the evidence requirement, or ask for final-grade behavior. These warnings appear in AI Readiness as `custom-instruction-lint` and require teacher review; they do not block manual grading or create an automatic final-grade path.

Sensitive AI constraints such as EAL/D-sensitive assessment and adjustment context require an explicit teacher confirmation sheet before selection. The sheet states that sensitive context must be teacher-provided or from a school record, must be relevant to the grading task, must not be inferred from student work, and must not raise or lower marks unless the rubric or teacher instructions explicitly require an adjustment.

`AIBatchReadinessAnalyzer` implements the source-level batch readiness table. It evaluates each selected local assignment with the same readiness gates, prompt-budget inputs, custom-instruction linting, and local availability state used by single-assignment drafting. Rows can be ready, needs-review, or blocked. The batch policy is one local assignment at a time with teacher pause/cancel controls; readiness does not create drafts, final approvals, or student-facing exports.

## Local tools and system surfaces

`LocalGradingToolSession` implements assignment-scoped, read-only lookup helpers for rubric criteria, reviewed evidence lines, OCR/source references, answer-key segments, exemplar segments, curriculum references, selected AI constraints, and packet limits. It returns source-labeled `LocalToolSnippet` values, enforces per-request call and output limits, blocks writes/network at policy level, and produces `LocalToolCallAudit` metadata with prompt version, assignment ID, argument hash, snippet IDs, truncation status, elapsed time, and error category. `LocalAIGradingToolbox` remains as compatibility wrappers for simple call sites. `LocalAIToolPolicy` explicitly forbids approval, export, email, upload, web fetch, contacts/calendar access, other-student reads, assignment writes, and deletion.

This is source-level local tool infrastructure and policy. Direct Foundation Models tool-calling still needs Xcode 26 SDK compilation and device/runtime validation before release claims.

`GradeDraftAppIntents.swift` exposes safe App Intents for opening review workflows, opening AI Readiness, opening the latest local draft/final-review workflow, preparing a packet preview, creating a blank local assignment shell, applying recommended non-sensitive AI constraints, saving pasted student work as teacher-reviewed local input, and searching local assignment titles. Shortcuts can resolve local assignments through `AssignmentEntity`, which displays only a redacted assignment title and does not store class, roster, student name, or student ID metadata. Launch requests route to the concrete in-app screen where possible. These intents do not draft grades, approve final grades, export reports, upload data, read other students, or bypass teacher review.

`scripts/ci/check_app_intents_safety.py` is part of `repo_health.py` and fails if the intent surface adds unsafe background grading, final approval, export/upload behavior, direct student/class entities, or assignment entity display fields that expose student/class metadata.

## Feedback rewrite assistant

In-progress final reviews can call the local Foundation Models rewrite path for teacher-selected rewrite modes such as warmer, concise, specific, age-appropriate, strengths plus next step, final-grade-language removal, or student-safe text from teacher-selected notes. The rewrite path:

- uses local AI only when Foundation Models is available;
- does not change scores, criteria, evidence, or approval state;
- rejects final-grade language and prohibited inference language;
- saves rewritten feedback as teacher-edited final-review content; and
- still requires teacher approval before student-facing export.

Final-review criterion controls include explicit teacher accept/reject actions. Accepting a suggestion saves a teacher-edited criterion decision locally and still requires final approval. Rejecting a suggestion saves the criterion as unapproved with a rationale prompt; it does not delete evidence, alter exports, or make the grade final.

The draft-suggestion view now keeps criterion evidence review explicit before final-review creation: each draft criterion shows suggested points, confidence, teacher-review-required state, review reasons, explanation, next step, exact evidence quotes, source-reference tags when present, a reviewed-text navigation action, and an "Accept, Edit, or Reject" action that starts the teacher-controlled final-review workflow instead of approving anything directly.

## Local evaluation harness

`GradeDraft/AI/Evaluation/AIEvaluation.swift` defines deterministic evaluation case models, preflight checks, draft-output checks, and anonymized Markdown report generation. The committed fixture corpus under `GradeDraftTests/Fixtures/AIEvaluation/` covers prompt injection, OCR uncertainty, source references, prohibited inference, answer keys, exemplars, formative feedback, summative caution, conventions, EAL/D context, adjustment context, off-prompt work, misconceptions, long context, unsupported language, guardrail-style errors, feedback rewriting, and batch workflow gates.

The deterministic preflight runner does not call the model and does not simulate a model pass. It checks local input gates, prompt budget planning, readiness reporting, identity redaction, prompt-injection flags, OCR/source-reference fixture setup, and expected constraint selection. Device-only evaluation can use the same cases with an injected local `GradingServicing & CapabilityChecking` service when Foundation Models is available.

`scripts/ci/check_ai_evaluation_fixtures.py` verifies that the fixture schema and required datasets are present, non-empty, unique, and context-safe for sensitive templates. `scripts/repo_health.py` runs that check as part of local static validation.

`scripts/ci/check_ai_prompt_safety.py` verifies that the canonical prompt authority snippets and custom-instruction linter categories remain present.

`scripts/ci/check_ai_batch_readiness.py` verifies that batch readiness keeps the no-background-draft/no-finalization/no-export safety boundary.

## Generation modes

The current source supports:

- full-packet typed generation;
- compact full-packet typed generation;
- per-criterion typed generation when full packet modes exceed the conservative local budget; and
- deterministic summary fallback when a per-criterion summary model pass would exceed budget.

The app does not silently truncate reviewed student work and does not send oversized packets to a cloud service.

## Not yet implemented

These production goals remain release-gated and are not claimed complete by the current source slice:

- Foundation Models direct tool-calling runtime validation;
- physical-device Apple Intelligence proof;
- Airplane Mode Apple Intelligence proof; and
- App Store release notes backed by device test dates, build numbers, and tester initials.

## Validation expectations

Before release, run the static repo guardrails, Xcode unit tests, SwiftLint, simulator smoke tests, physical-device Foundation Models tests, and Airplane Mode tests described in `docs/TEST_PLAN.md` and `docs/release/PRODUCTION_READINESS_CHECKLIST.md`.
