# App Review Notes

No account is required. No demo login is required.

MarkForMe is a teacher-facing app for marking text-based student work. It helps teachers add student work, use a rubric or marking guide, check evidence, edit marks and feedback, approve the final result, and export feedback or a teacher record.

Use fake student work for review.

## Suggested test flow

1. Open the app.
2. Create a class and assignment.
3. Paste sample student work if camera or file import is not convenient in the review environment.
4. Add a simple rubric or marking guide.
5. Check the pasted or scanned text.
6. Start manual final review, or generate draft marks and feedback if the review device supports local draft feedback.
7. Edit a criterion mark and feedback comment.
8. Approve the final result.
9. Export student feedback and a teacher record.

## Privacy and teacher control

The current repo has no account flow, ads, subscriptions, in-app purchases, analytics, crash reporting, cloud sync, cloud OCR, cloud marking, or developer-accessible telemetry path in the core app.

Student work is not sent to us for marking. Student work stays on the device unless the teacher chooses to export or share it.

Student-facing export is blocked until a teacher-approved final result exists. Teacher-only exports and backups may contain sensitive student information and are warning-gated.

If draft marking is unavailable on a device, the app shows that draft feedback is not available on this device and does not use a cloud fallback. Manual review remains available.

## Device and OS caveats

Camera scan, PDF import, share/export sheets, Face ID/Touch ID/passcode export confirmation, Vision text recognition, and Foundation Models draft feedback require Apple runtime validation. The Windows checkout cannot run Xcode archive or device tests.

## Curriculum note

Bundled Australian Curriculum references are offline reference aids. MarkForMe does not claim ACARA endorsement, certification, compliance, or school-system reporting approval. Teachers choose any curriculum references before they are included in a marking task.

## Review contact status

Support and privacy URLs are not configured. App Store submission is blocked until real, working URLs and contact details are available.
- Review contact name: NOT CONFIGURED - blocks App Store submission.
- Review contact phone/email: NOT CONFIGURED - blocks App Store submission.
