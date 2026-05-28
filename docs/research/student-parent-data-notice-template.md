# Student-Facing Data Notice Template

**Product:** [App Name]  
**Audience:** Schools, teachers, parents, guardians, and students  
**Use Case:** Local-first iOS/iPadOS teacher grading assistant  
**Status:** Draft template for legal and district review  
**Last updated:** May 28, 2026

---

## 1. Purpose of This Notice

[App Name] is a teacher-facing grading and feedback tool. Teachers may use the app to review student work, apply a rubric, draft criterion-by-criterion feedback, and prepare grading records or student-facing reports.

The app is designed so that the core grading workflow runs locally on the teacher’s iPhone or iPad. Under the intended design, student work is not uploaded to the developer, is not sent to a cloud AI service, is not processed by cloud OCR, and is not used for analytics, advertising, tracking, or model training.

This notice is intended to help schools explain the app’s data handling in plain language. It should be reviewed and adapted by the school, district, or counsel before distribution.

---

## 2. Who Uses the App

The app is intended for teachers and authorized school personnel. It is not intended for direct use by children or students. Students are not expected to create accounts, sign in, submit work directly, or interact with the app as end users.

Teachers remain responsible for reviewing, editing, and finalizing any grade, score, comment, or feedback generated in the app. The app is not an autonomous grading authority.

---

## 3. What Student Information May Be Stored Locally

Depending on how the teacher uses the app, the app may store the following information on the teacher’s device:

| Data Category | Examples | Sensitivity |
|---|---|---|
| Student identifiers | Student name, local student ID, roster label, pseudonym, class group | Student PII if linked to a student |
| Student work | Scanned pages, photographed work, uploaded files, pasted text, OCR text | Student educational content |
| Assignment information | Assignment title, rubric, answer key, teacher instructions, grading criteria | Educational record context |
| Grading information | Draft scores, final scores, criterion notes, evidence quotes, feedback drafts | Grade/evaluation data |
| Teacher-only notes | Private observations, grading rationale, internal comments | Sensitive internal school record |
| Exported reports | PDF, CSV, JSON, ZIP, or other files created by the teacher | Sensitive once exported |

Schools should treat student-linked data in the app as sensitive educational information. FERPA defines education records as records directly related to a student and maintained by an educational agency or institution, or by a party acting for the agency or institution. FERPA also defines personally identifiable information to include the student’s name, personal identifiers, and other linkable information.

---

## 4. What the App Does Not Do in the Core Local-First Workflow

Under the intended local-first design, the app does not:

- Upload student work to the developer.
- Use cloud OCR for student work.
- Use cloud AI grading.
- Send student names, grades, scans, OCR text, teacher notes, or feedback drafts to a server.
- Use third-party analytics or advertising SDKs.
- Track students or teachers across apps or websites.
- Sell student information.
- Use student information for advertising, behavioral profiling, or model training.

If any future feature changes these data flows, the privacy policy, App Store privacy answers, school notice, and in-app warnings should be updated before release.

---

## 5. How the App Processes Student Work

The app processes student work locally on the teacher’s device. A typical workflow is:

1. The teacher scans, uploads, photographs, or pastes student work.
2. The app may extract text locally through on-device OCR where applicable.
3. The teacher reviews and confirms the text that will be graded.
4. The app drafts rubric-based score suggestions, evidence references, explanations, and feedback locally.
5. The teacher reviews, edits, approves, rejects, or finalizes the output.
6. The teacher may export a report or grading record, subject to in-app warnings.

The app should not grade unconfirmed OCR text, unreadable scans, missing evidence, or unsupported artifact types. If the source evidence is uncertain, the app should flag the issue for teacher review.

---

## 6. Teacher Control and Human Review

The app is designed to support teacher judgment, not replace it. Teachers should treat app outputs as draft suggestions. Teachers are responsible for confirming source text, reviewing rubric application, checking evidence, editing feedback, and finalizing grades.

The app should not make or display final student grades unless the teacher has confirmed the result. The app should not infer student effort, intent, disability, demographic traits, behavioral traits, or reasons for performance unless such information is explicitly present in teacher-provided instructions and appropriate for school use.

---

## 7. Student Names, Pseudonyms, and Data Minimization

Schools may choose to use student names, district IDs, local roster IDs, initials, pseudonyms, or other local identifiers. The app should support pseudonymous local labels where practical.

Best practice is to store only the information needed for the teacher’s grading workflow. If a teacher does not need full student names in the app, the teacher should be able to use local identifiers instead.

---

## 8. Local Security and Device Responsibility

Because the app stores data locally, the security of the teacher’s device matters. Teachers and schools should use a device passcode, Face ID or Touch ID where available, and school-approved device management practices.

The app should use iOS/iPadOS security protections for sensitive files and should provide an app-level lock for sensitive views and exports. Apple describes iOS/iPadOS Data Protection as a system that protects data stored on devices using hardware-backed encryption and per-file protection classes. The app should not describe these controls as making data “unhackable” or “guaranteed secure.”

---

## 9. Backups, Sync, and Exported Files

The local-first design should exclude sensitive student records from iCloud backup by default unless a school or teacher explicitly enables backup behavior after reviewing the risks. If backups or sync are enabled, the school should determine whether that use is permitted under district policy.

Exported files require special care. Once a teacher exports a PDF, CSV, JSON, ZIP, or other file, that file may leave the app’s protected storage. The teacher or school is responsible for storing, transmitting, and deleting exported files securely.

---

## 10. Student-Facing Reports and Teacher-Only Notes

The app should separate teacher-only notes from student-facing feedback. Private teacher notes, internal grading rationale, OCR uncertainty flags, and review comments should not appear in student-facing reports unless the teacher explicitly chooses to include them.

Before any student-facing report is exported, the teacher should see a preview that clearly identifies what will be included.

---

## 11. Parent and Eligible Student Rights

FERPA rights are administered by the school or educational agency, not by the app itself. Parents and eligible students may have rights to inspect, review, request amendment of, or control certain disclosures of education records. Schools should direct questions about records created or maintained through the app to the appropriate teacher, school administrator, or district privacy office.

The app should provide local export and deletion tools so that teachers and schools can respond to authorized records requests under school policy.

---

## 12. Suggested Short Notice for Parents and Students

[School/District] uses [App Name], a teacher-facing iPad/iPhone tool, to help teachers review student work and draft rubric-based feedback. The app is designed for teacher use, not student sign-in or direct student use. In the core workflow, student work and grading information are processed locally on the teacher’s device and are not uploaded to the app developer, cloud AI services, cloud OCR services, analytics providers, or advertisers. Teachers review and finalize all grades and feedback. Exported files, if created by the teacher, may contain student information and must be handled under [School/District] privacy and records policies.

---

## 13. Implementation Checklist

- [ ] The app is described as teacher-facing and not child-directed.
- [ ] The school notice explains that local processing still involves sensitive student information.
- [ ] The app supports pseudonymous or local identifiers where practical.
- [ ] The app requires teacher confirmation before final grades or student-facing reports are produced.
- [ ] Teacher-only notes are excluded from student-facing reports by default.
- [ ] Export warnings are shown before any file leaves protected app storage.
- [ ] Deletion and export controls are available to support school records requests.
- [ ] Privacy statements do not claim absolute security or blanket FERPA/COPPA certification.

---

## 14. Source Notes

This template is grounded in the following primary guidance:

1. U.S. Department of Education, FERPA regulations and definitions: https://studentprivacy.ed.gov/ferpa
2. FTC, COPPA FAQ, including the scope of COPPA and school questions for operators: https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions
3. Apple App Store Review Guidelines, privacy, Kids Category, data security, and metadata accuracy: https://developer.apple.com/app-store/review/guidelines/
4. Apple App Privacy Details, including the definition of “collect” and the treatment of data processed only on device: https://developer.apple.com/app-store/app-privacy-details/
5. Apple Platform Security, Data Protection overview: https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web
6. Apple Platform Security, Keychain data protection: https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web

---

## 15. Drafting Note

This document is a product and school notice template. It is not legal advice. It should be reviewed by counsel before being used as a public notice, district procurement exhibit, or parent-facing communication.
