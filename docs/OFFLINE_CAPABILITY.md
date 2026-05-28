# Offline Capability

GradeDraft is designed to complete the grading workflow without online services.

## Local stages

| Stage | Local mechanism |
|---|---|
| Student work capture | VisionKit document camera or photo import |
| OCR | Vision `VNRecognizeTextRequest` |
| Rubric draft | Foundation Models, when locally available |
| Totals | Deterministic app code |
| Storage | Local JSON files in Application Support |
| Export | Local Markdown file and explicit teacher sharing |

## No-cloud guarantee in this scaffold

The app contains no network service layer and no code path intentionally sending student data off device. The repository includes `scripts/no_network_scan.py` to fail if obvious networking calls, remote URL literals, or common analytics SDK strings are introduced into source files.

This is a source-level guardrail, not a full security proof. Before shipping, also review:

- SDK additions.
- Dependencies.
- Build settings.
- Crash reporting.
- Analytics.
- Privacy manifest declarations.
- App extensions.
- Entitlements.
- Network entitlements and background modes.

## Availability model

The UI must distinguish these states:

1. OCR available.
2. Document camera unsupported.
3. Foundation Models available.
4. Foundation Models unavailable because Apple Intelligence is disabled.
5. Foundation Models unavailable because the device is ineligible.
6. Foundation Models unavailable because the model is not ready.
7. Foundation Models unavailable because the SDK/framework is absent at compile time.

The app must never silently replace a missing local model with a network model.

## User-facing promise

Use this phrasing in product copy:

> GradeDraft processes student text work on this device. It does not upload student work or grading prompts. AI grade drafting requires a compatible device with Apple Intelligence enabled and the on-device model available.

## Deferred online features

These should stay out of the local MVP unless the teacher explicitly opts in later:

- LMS sync.
- Cloud drive import/export.
- Account login.
- Cross-device sync.
- Remote backup.
- Cloud OCR.
- Cloud AI grading.
- Analytics.
