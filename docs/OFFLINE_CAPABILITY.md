# Offline Capability

GradeDraft is designed so the core grading workflow has no server dependency:

```text
scan/import/paste -> local OCR -> teacher review -> local model draft -> teacher final review -> local export
```

## No-network posture

The scaffold contains no backend client, no analytics SDK, no cloud OCR, and no cloud grading fallback. The `scripts/no_network_scan.py` guardrail fails if obvious network APIs or hosted URLs enter Swift/project/privacy files.

## Local AI availability

Foundation Models may not be available on every device, OS, language, region, or configuration. GradeDraft checks availability and refuses to draft grades when the local model is unavailable. It does not silently fall back to a remote model.

## OCR availability

OCR uses Apple Vision locally. OCR output is not trusted as final text until the teacher reviews it when required. Scanned or photo-imported work sets OCR status to `needsReview` and blocks draft grading until the teacher confirms the reviewed text.

## Storage

The scaffold stores assignment state in local JSON under Application Support. Scanned/imported images are also written under Application Support and referenced by local relative path. These local files may contain student data.

## Export warning

Student exports exclude private teacher notes and render only teacher-approved, non-stale final grade content. Teacher-audit exports can include reviewed text, OCR state, source references, private notes, model-draft metadata, and audit events. Treat teacher-audit exports and local backups as sensitive student records.

GradeDraft applies best-effort local file-protection attributes to generated exports where supported by the platform, and export files are marked to be excluded from backup where supported. This does not make exported files encrypted after they leave the app and does not replace school-approved storage, transfer, retention, or device-management policies.

ZIP archives and full backups include `archive_inventory.json` so the exported package records which categories of data are present, including whether private teacher notes, original source files, and internal metadata were included.

## Not encryption

The scaffold does not implement encryption. Local storage, source images, reports, and backups should not be described as encrypted unless a real encryption layer is added later. Best-effort file-protection attributes are platform hints and must not be marketed as encryption or compliance certification.

## Local model packet limits

Foundation Models availability depends on supported hardware, operating-system version, Apple Intelligence settings, language/region, and model readiness. GradeDraft checks availability before generating a local draft.

Long grading packets are handled locally. The app may use a compact prompt or criterion-by-criterion typed generation when safe, but it must not silently truncate reviewed student work or send the packet to a cloud model. If the packet is too large for the on-device model, GradeDraft reports that limitation and keeps manual grading available.

Teacher-audit exports and full backups may include local model audit metadata. Student-facing exports do not include raw prompt material, raw model material, local model audit metadata, or private teacher notes.
