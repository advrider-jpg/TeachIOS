# Export and Backup Warning UI Copy Pack

**Product:** [App Name]  
**Audience:** Product, design, engineering, and compliance teams  
**Use Case:** Local-first iOS/iPadOS teacher grading assistant  
**Status:** Draft copy and acceptance criteria for legal/design review  
**Last updated:** May 28, 2026

---

## 1. Copy Principles

Export and backup warnings should be direct, specific, and hard to miss. The app should not rely on generic warnings such as “Are you sure?” because teachers may be exporting files that contain student names, scanned work, grades, teacher notes, feedback drafts, or other sensitive educational information.

Each warning should answer four questions:

1. What data will be included?
2. Where is the data going?
3. What changes after export or backup?
4. What does the teacher need to check before continuing?

The safest default is that teacher-only notes, internal review flags, OCR uncertainty, and grading drafts are excluded from student-facing reports unless deliberately selected.

---

## 2. Global Export Confirmation Modal

**Title:** Export student information?

**Body:** This export may include student names, assignment work, grades, rubric scores, feedback, and teacher notes. Once exported, the file may leave the app’s protected local storage. Store and share it only through approved school channels.

**Primary button:** Continue to Export  
**Secondary button:** Cancel

**Optional checkbox:** I understand this file may contain sensitive student information.

**Recommended trigger:** Before any PDF, CSV, JSON, ZIP, archive, or share-sheet export.

---

## 3. Student-Facing Report Export

**Title:** Review student-facing report

**Body:** This report is intended for student or family review. Confirm that it includes only the feedback, scores, and evidence you want the student or family to see.

**Warning line:** Teacher-only notes and internal review flags should not be included unless you intentionally add them.

**Primary button:** Preview Report  
**Secondary button:** Cancel

**Post-preview confirmation:** I reviewed the report and confirmed it is appropriate to share.

**Primary button after preview:** Export Student Report  
**Secondary button after preview:** Go Back

---

## 4. Teacher-Only Record Export

**Title:** Export teacher-only grading record?

**Body:** This file may include internal grading notes, draft scores, rubric reasoning, OCR uncertainty flags, and teacher annotations. It is not intended for students or families unless reviewed and redacted.

**Primary button:** Export Teacher Record  
**Secondary button:** Cancel

**Optional checkbox:** I understand this export may include teacher-only content.

---

## 5. PDF Export Warning

**Title:** Export PDF with student information?

**Body:** This PDF may include student names, assignment text, grading feedback, rubric scores, and evidence quotes. Review the preview before sharing. Once exported, the PDF can be copied, printed, emailed, uploaded, or forwarded outside the app.

**Primary button:** Preview PDF  
**Secondary button:** Cancel

**Final button:** Export PDF

---

## 6. CSV Export Warning

**Title:** Export spreadsheet data?

**Body:** This CSV may include student names, scores, grades, rubric labels, and comments. CSV files are easy to copy, upload, email, and re-import into other systems. Use only approved school storage and transfer methods.

**Security note:** The app should neutralize spreadsheet formula injection risks before export. Review free-text fields before sharing.

**Primary button:** Export CSV  
**Secondary button:** Cancel

**Optional checkbox:** I understand this file may expose student records if shared incorrectly.

---

## 7. JSON Export Warning

**Title:** Export structured data?

**Body:** This JSON file may contain full assignment records, OCR text, rubric data, scores, feedback, teacher notes, and internal metadata. JSON exports may reveal more information than a student-facing report.

**Primary button:** Export JSON  
**Secondary button:** Cancel

**Optional checkbox:** I understand this export may include complete local records.

---

## 8. ZIP or Archive Export Warning

**Title:** Export archive with source files?

**Body:** This archive may include scanned work images, OCR text, grading records, feedback drafts, rubrics, and teacher notes. Archives can contain multiple files and may expose more student information than expected.

**Checklist before export:**

- Review which classes, assignments, and students are included.
- Confirm whether scanned images are included.
- Confirm whether teacher-only notes are included.
- Confirm the destination is approved by your school or district.

**Primary button:** Review Archive Contents  
**Secondary button:** Cancel

**Final button:** Export Archive

---

## 9. Copy to Clipboard Warning

**Title:** Copy student information?

**Body:** The copied text may include student information. Other apps, shared devices, or clipboard history tools may expose copied content. Copy only what you need.

**Primary button:** Copy  
**Secondary button:** Cancel

**Recommended trigger:** Before copying student-linked grades, work text, feedback, evidence quotes, or teacher notes.

---

## 10. Share Sheet Warning

**Title:** Share outside the app?

**Body:** You are about to send a file or text to another app. [App Name] cannot control how that destination app stores, syncs, forwards, or protects the information.

**Primary button:** Open Share Sheet  
**Secondary button:** Cancel

**Optional link:** Learn what is included in this export.

---

## 11. Backup Toggle Warning

**Title:** Include student records in device backup?

**Body:** By default, [App Name] keeps student records local and excludes sensitive app files from backup where supported. If you enable backup for student records, copies may be stored outside this device according to your device and account settings.

**Primary button:** Enable Backup  
**Secondary button:** Keep Local Only

**Optional checkbox:** I have confirmed this is permitted by my school or district.

---

## 12. Delete Local Data Warning

**Title:** Delete local student records?

**Body:** This will remove the selected records from this device. This action may delete scans, OCR text, scores, feedback, and teacher notes stored in the app. Export a permitted backup first if your school requires retention.

**Primary button:** Delete Records  
**Secondary button:** Cancel

**Escalated confirmation for bulk delete:** Type DELETE to confirm.

---

## 13. Teacher Notes Inclusion Warning

**Title:** Include teacher-only notes?

**Body:** Teacher-only notes may contain internal observations, draft reasoning, or information not intended for students or families. Include them only if this export is for internal school use.

**Primary button:** Include Teacher Notes  
**Secondary button:** Exclude Teacher Notes

**Recommended default:** Exclude Teacher Notes.

---

## 14. OCR Uncertainty Warning

**Title:** Export includes unconfirmed OCR text

**Body:** Some extracted text has not been confirmed by the teacher. Review uncertain OCR before exporting or using it for grading records.

**Primary button:** Review OCR Issues  
**Secondary button:** Export Anyway

**Recommended default:** Require review before final grade export; permit export anyway only for teacher-only diagnostic exports.

---

## 15. Draft Grade Warning

**Title:** Export draft scores?

**Body:** Some scores or comments are still marked as drafts. Draft grading content should not be shared with students or families unless you have reviewed and finalized it.

**Primary button:** Review Drafts  
**Secondary button:** Export Teacher Copy

**Recommended default:** Block student-facing export until all draft items are finalized.

---

## 16. Secure Flow Requirements

The export flow should follow this structure:

1. **Select scope:** The teacher chooses class, assignment, student, and content categories.
2. **Show inclusion summary:** The app lists whether the export includes student names, scans, OCR text, final grades, draft grades, feedback, teacher notes, and internal flags.
3. **Preview:** The teacher sees the actual student-facing document or teacher-only export summary.
4. **Confirm:** The teacher acknowledges the sensitivity warning.
5. **Authenticate:** The app requires Face ID, Touch ID, or device passcode for sensitive exports where supported.
6. **Share/export:** Only after confirmation does the app open the share sheet or create the file.

---

## 17. Acceptance Criteria

- [ ] Every export path shows a content-specific warning before creating or sharing a file.
- [ ] Student-facing reports default to excluding teacher-only notes, OCR uncertainty flags, and internal draft metadata.
- [ ] CSV exports neutralize spreadsheet formula injection by escaping dangerous leading characters in text fields.
- [ ] ZIP/archive exports show a file inventory before export.
- [ ] Share-sheet actions warn that the destination app controls downstream storage and sharing.
- [ ] Bulk exports require stronger confirmation than single-student exports.
- [ ] Sensitive exports require local authentication when available.
- [ ] Export logs, if implemented, remain local and record what was exported without exposing unnecessary content.
- [ ] Exported filenames avoid unnecessary student PII by default.
- [ ] The app never silently includes teacher-only notes in student-facing outputs.

---

## 18. Do Not Use These Weak Warnings

Do not use vague warnings such as:

- “Are you sure?”
- “Export complete.”
- “This may contain data.”
- “Share file?”
- “Proceed?”

These do not tell the teacher what information is included or what risk is created.

---

## 19. Source Notes

This copy pack is grounded in the following primary guidance:

1. Apple App Store Review Guidelines require clear privacy policies, data minimization, respect for permissions, consent for collection, and clear disclosures around data sharing: https://developer.apple.com/app-store/review/guidelines/
2. Apple App Privacy Details define “collect” as transmitting data off device in a way that permits developer or third-party access beyond what is necessary to service a real-time request, and state that data processed only on device is not “collected”: https://developer.apple.com/app-store/app-privacy-details/
3. U.S. Department of Education FERPA regulations define education records, disclosure, and personally identifiable information: https://studentprivacy.ed.gov/ferpa
4. FTC COPPA FAQ advises schools to ask what operators collect, how they use and disclose information, whether deletion is available, and what security measures protect student information: https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions
5. Apple Platform Security describes Data Protection and hardware-backed per-file encryption: https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web

---

## 20. Drafting Note

This document provides product copy and implementation criteria. It is not legal advice. Final copy should be reviewed by counsel and adjusted for the actual data flows, export formats, security controls, and district requirements implemented in the app.
