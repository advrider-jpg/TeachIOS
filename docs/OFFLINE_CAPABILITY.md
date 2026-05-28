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

Student exports exclude private teacher notes. Teacher-audit exports can include reviewed text, OCR state, source references, private notes, and audit events. Treat teacher-audit exports and local backups as sensitive student records.

## Not encryption

The scaffold does not implement encryption. Local storage, source images, reports, and backups should not be described as encrypted unless a real encryption layer is added later.
