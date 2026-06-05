# Offline Capability

Mark My Work is designed so the core grading workflow has no server dependency:

```text
scan/import/paste -> local OCR -> teacher review -> local model draft -> teacher final review -> local export
```

## No-network posture

The scaffold contains no backend client, no analytics SDK, no cloud OCR, and no cloud grading fallback. The `scripts/no_network_scan.py` guardrail fails if obvious network APIs or hosted URLs enter Swift/project/privacy files.

## Local AI availability

Foundation Models may not be available on every device, OS, language, region, or configuration. Mark My Work checks availability and refuses to draft grades when the local model is unavailable. It does not silently fall back to a remote model.

The AI readiness report is deterministic app behavior. It reflects the real local AI availability check, OCR review gate, reviewed student text, grading-standard state, prompt-injection risk scan, identity-redaction policy, and conservative prompt budget plan. It must not display a ready state when any required gate is blocked.

Custom teacher instructions are linted locally for unsafe patterns such as overriding the rubric, awarding full marks regardless of evidence, grading by effort, penalizing handwriting in the text lane, using student background, removing the evidence requirement, or asking the app/model to make the grade final. These warnings require teacher review and do not create an automatic final-grade path.

## OCR availability

OCR uses Apple Vision locally. OCR output is not trusted as final text until the teacher reviews it when required. Scanned or photo-imported work sets OCR status to `needsReview` and blocks draft grading until the teacher confirms the reviewed text.

## Storage

The scaffold stores assignment state in local JSON under Application Support. Scanned/imported images are also written under Application Support and referenced by local relative path. These local files may contain student data.

## Export warning

Student exports exclude private teacher notes and render only teacher-approved, non-stale final grade content. Teacher-audit exports can include reviewed text, OCR state, source references, private notes, model-draft metadata, and audit events. Treat teacher-audit exports and local backups as sensitive student records.

Mark My Work applies best-effort local file-protection attributes to generated exports where supported by the platform, and export files are marked to be excluded from backup where supported. This does not make exported files encrypted after they leave the app and does not replace school-approved storage, transfer, retention, or device-management policies.

ZIP archives and full backups include `archive_inventory.json` so the exported package records which categories of data are present, including whether private teacher notes, original source files, and internal metadata were included.

## Not encryption

The scaffold does not implement encryption. Local storage, source images, reports, and backups should not be described as encrypted unless a real encryption layer is added later. Best-effort file-protection attributes are platform hints and must not be marketed as encryption or compliance certification.

## Local model packet limits

Foundation Models availability depends on supported hardware, operating-system version, Apple Intelligence settings, language/region, and model readiness. Mark My Work checks availability before generating a local draft.

Long grading packets are handled locally. The app may use a compact prompt or criterion-by-criterion typed generation when safe, but it must not silently truncate reviewed student work or send the packet to a cloud model. If the packet is too large for the on-device model, Mark My Work reports that limitation and keeps manual grading available.

Before generation, teachers can prepare a local packet preview. The preview shows included reviewed text and grading materials, identity fields excluded from the model-visible prompt, prompt version, packet fingerprint, prompt fingerprint, estimated token budget, and selected generation mode. Preparing this preview does not create a draft or final grade.

During generation, the app uses the Foundation Models structured streaming API, shows local pipeline progress, and offers cancellation while the draft task can be cancelled. If cancellation completes, no local draft is saved and manual final review remains available. Token-by-token or field-by-field partial draft display still requires later UI work and physical-device validation.

Model-visible prompts remove student name, student ID, class name, roster membership, local source filenames, and local source file paths by default. Local assignment records and teacher-only exports may still contain these fields where they are part of the teacher workflow.

Local AI lookup tools are assignment-scoped and read-only. They can retrieve rubric criteria, reviewed evidence, OCR/source references, answer-key text, exemplar text, curriculum references, selected constraints, and packet limits from local app state. Tool output is source-labeled, bounded by per-request call/output limits, and accompanied by local audit metadata. They cannot approve grades, export reports, write records, delete data, read other students, access contacts/calendar/photos, fetch the web, upload data, or send email.

Safe App Intents can open review workflows, route to concrete in-app screens including AI Readiness, prepare a packet preview, create a blank local assignment shell, apply recommended non-sensitive AI constraints, save pasted student work as teacher-reviewed local input, and search local assignment titles. Assignment selection uses local `AssignmentEntity` lookup and redacted assignment display titles. These intents do not create drafts, final approvals, student exports, uploads, other-student reads, or cloud/network operations.

The feedback rewrite assistant is also local-only. It is available only for in-progress final reviews when the local model is available, never changes scores or evidence, and still requires teacher approval before export.

Teacher-audit exports and full backups may include local model audit metadata. Student-facing exports do not include raw prompt material, raw model material, local model audit metadata, or private teacher notes.

The local AI evaluation fixture harness is offline as well. Static and XCTest preflight checks decode committed local fixtures, inspect prompt/readiness behavior, and produce anonymized metadata without contacting a model or network service. Actual Foundation Models evaluation remains a manual device path and must be recorded separately with device, OS, build, date, and tester details.

Batch AI readiness is deterministic and offline. It creates a readiness table for selected local assignments, redacts known identity from row display titles, and reports whether each row is ready, needs review, or is blocked. It does not run drafts in the background, approve grades, or export reports.

## Airplane Mode AI test steps

Physical-device release testing must include an Airplane Mode run on an Apple Intelligence-capable device:

1. Enable Airplane Mode.
2. Confirm the app still opens existing local assignment data.
3. Confirm manual final review remains available.
4. Open Final Review and prepare the local AI packet preview.
5. If Foundation Models reports available on that device, generate a local draft and verify no cloud fallback or network prompt appears.
6. If Foundation Models reports unavailable, verify the app surfaces that state and keeps manual final review available.
7. Approve a teacher-final review and export locally.

## Australian Curriculum catalog offline behavior — 2026-05-31

The Australian Curriculum browser loads committed JSON resources from the app bundle. The app does not fetch MRAC, Scootle, ACARA, or other curriculum endpoints at runtime. Provenance URLs are stored as inert catalog metadata for attribution and audit export. The developer-side generator may refresh sources during maintenance, but normal app operation remains offline.
