# Mark My Work App Store Metadata Draft

## App name
Mark My Work

## Subtitle
Local teacher grading assistant

## Category
Education

## Promotional text
Draft rubric-based feedback locally, review evidence, and export teacher-approved reports.

## Description
Mark My Work is a teacher-facing grading assistant for text-based student work. Teachers can scan, import, or paste student work, review extracted text, apply rubrics and grading instructions, map teacher-selected curriculum references, generate local draft feedback where supported, edit criterion-level scores, and approve final student-facing feedback.

Mark My Work is designed around teacher control. Draft suggestions are not final grades. Teachers review OCR text, evidence, criterion scores, feedback, mapped curriculum references, and final reports before export.

The core workflow runs locally on device. Mark My Work does not upload student work, rubrics, OCR text, grading drafts, teacher notes, curriculum mappings, or final grades to the developer or a cloud AI service.

## Keywords
teacher,grading,rubric,feedback,assessment,OCR,PDF,education

## Support URL
Publish the contents of `docs/release/PUBLIC_SUPPORT_PAGE.md` to the product support site and enter the final live URL in App Store Connect.

## Privacy Policy URL
Publish the contents of `docs/release/PUBLIC_PRIVACY_POLICY.md` to the product privacy page and enter the final live URL in App Store Connect.

## Review notes
Mark My Work is a teacher-facing local-first grading assistant. No account is required. The core workflow runs on device. The app does not upload student work, OCR text, rubrics, grading drafts, teacher notes, final grades, curriculum mappings, or feedback reports to the developer or third-party services. Student work may be scanned/imported by the teacher and remains in local app storage unless the teacher explicitly exports it through iOS sharing. Sensitive teacher-only exports require a warning and local authentication where available. If Apple’s on-device language model is unavailable, Mark My Work shows a local-unavailable state and does not fall back to a cloud model. Manual final review remains available.

The bundled Australian Curriculum references are local offline reference aids. Mark My Work does not claim ACARA endorsement, certification, compliance, or jurisdiction reporting approval. Teachers must explicitly map curriculum references before they enter grading packets.

## What to test in TestFlight
1. Create a class and assignment.
2. Paste student text or import a PDF.
3. Add a rubric or answer key.
4. Browse the Australian Curriculum catalog and map one reference.
5. Review OCR/extracted text if applicable.
6. Generate local draft feedback where available, or start manual final review.
7. Edit and approve criterion scores.
8. Export a student-facing PDF and teacher audit archive.
9. Confirm sensitive export warnings and local authentication behavior.
10. Run the Add Pasted Student Work Shortcut and confirm student work is applied only after the app opens, with no background grading or export.


## Privacy-answer draft
Use “Data Not Collected” only if the submitted build still contains no developer-accessible data transmission, analytics, crash reporting upload, accounts, cloud AI, cloud OCR, hosted curriculum refresh, or support-bundle upload. The app handles student and teacher data locally on device, and teacher-created exports leave the app only through explicit teacher action.

## Age-rating answer notes
The app is an education/productivity tool for teachers. It does not contain gambling, unrestricted web access, user-generated public content, social networking, ads, commerce, or in-app purchases. OCR/imported student work is teacher-provided local content and must be reviewed under school policy.
