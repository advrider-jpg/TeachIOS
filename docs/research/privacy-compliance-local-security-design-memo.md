# Privacy & Compliance Design Memo  
## Local-First iOS/iPadOS Teacher Grading Assistant

**Prepared for:** Product, Engineering, Privacy, Security, and Legal Review  
**Date:** May 28, 2026  
**Scope:** Teacher-facing iPhone/iPad app for local processing of student work, rubrics, scores, grading drafts, teacher notes, OCR text, scanned images, and feedback reports.  
**Core assumption:** The core grading workflow does not upload student work, use cloud OCR, use cloud AI grading, use analytics, use advertising, or depend on a server.

---

## 1. Executive Summary

A local-first iOS/iPadOS teacher grading assistant can materially reduce privacy and compliance risk by keeping student work, OCR output, rubrics, scores, teacher notes, proposed grades, final grades, and reports on the teacher’s device. The product should be designed and documented as a **teacher-controlled, local processing tool**, not as a cloud education platform and not as an autonomous student-data processor.

Local-only architecture does not eliminate privacy obligations. Student names, roster records, assignments, scanned work, grades, and teacher comments are sensitive educational data. In school use, much of this information may become or reflect **education records** under FERPA. If the app is adopted by a school or district, the school’s own FERPA and state-law duties will shape how the app may be used, how exports are handled, and what contractual assurances the vendor may need to provide.

The most important product conclusions are:

1. **Do not transmit student work or student identifiers in the core workflow.** This is the product’s central privacy posture and should be enforced technically, not merely promised in marketing language.

2. **Treat all student-linked data as sensitive educational data.** This includes scanned images, OCR text, rubrics applied to a student, draft grades, final grades, teacher notes, and feedback reports.

3. **Do not position the app as child-directed.** The app should be teacher-facing and should generally avoid Apple’s Kids Category unless the product is redesigned for direct child use and counsel intentionally accepts the resulting legal and App Store constraints.

4. **Be precise about App Store privacy labels.** Apple defines “collect” for App Privacy disclosures as transmitting data off device in a way that the developer or third-party partners can access beyond what is necessary to service a real-time request. If student data is processed only on device and never transmitted off device, Apple’s current App Privacy guidance says that on-device-only data is not “collected” and does not need to be disclosed in App Store Connect answers. That does not eliminate the need for a public privacy policy explaining local storage and controls.

5. **Avoid analytics and third-party SDKs by default.** Even seemingly harmless crash, analytics, or attribution SDKs can undermine the “nothing leaves the device” claim and introduce COPPA, FERPA, state-law, App Store, and district procurement complications.

6. **Use iOS security controls, but do not overclaim them.** The app should use iOS Data Protection, file protection classes, Keychain, LocalAuthentication, app sandboxing, and optional database/file encryption. The app may say it uses device security controls; it should not claim that data is “unhackable,” “anonymous,” or categorically “FERPA compliant.”

7. **Exclude sensitive student data from iCloud backup by default.** A local-first app should not quietly move sensitive student records into iCloud backup or sync. If optional backup/sync is ever offered, it should be explicit, gated, documented, and capable of being disabled.

8. **Exports are the highest practical leakage risk.** PDF, CSV, JSON, ZIP, image, and archive exports can move sensitive records outside the app sandbox. Export workflows should require explicit confirmation, show file-specific warnings, separate teacher-only and student-facing content, and prevent accidental inclusion of private teacher notes.

9. **Product requirements should be framed as controls.** The app should include data minimization, pseudonymous/local identifiers, deletion, retention, export, backup, authentication, evidence separation, and report-redaction controls as release-blocking requirements.

10. **Counsel should review state-law and district procurement implications.** State student privacy laws and district DPAs often impose contract and security expectations even when a product is local-first.

---

## 2. Source Base and Methodology

This memo relies primarily on the following categories of sources:

- U.S. Department of Education FERPA regulations and Student Privacy Policy Office materials.
- FTC COPPA guidance and COPPA Rule materials.
- Apple App Store Review Guidelines and App Privacy Details guidance.
- Apple Platform Security materials for Data Protection and device security architecture.
- Selected state student privacy materials and statutes, including examples from New York, California, and Connecticut.
- Student privacy procurement models and district/vendor contracting norms, including Student Data Privacy Consortium materials where relevant.

The memo distinguishes between:

- **Legal requirements**, which come from statutes, regulations, official guidance, App Store rules, or binding contracts.
- **Platform requirements**, which are imposed by Apple as a condition of App Store distribution.
- **Best practices**, which are conservative design recommendations intended to reduce compliance risk, procurement friction, and accidental disclosure.
- **Open legal questions**, which require jurisdiction-specific legal advice or district-specific contract review.

---

## 3. Product Context and Assumptions

The app concept is a local-first iOS/iPadOS teacher grading assistant. The app allows a teacher to paste, import, scan, photograph, or upload student work into the app; confirm or correct extracted text; apply a standard rubric and any teacher-provided grading instructions; and generate criterion-by-criterion score suggestions, evidence references, uncertainty flags, and draft feedback.

The app may store:

- Student names.
- Local student identifiers.
- Class rosters.
- Assignment metadata.
- Rubrics.
- Teacher-provided grading instructions.
- Scanned work images.
- Imported documents.
- OCR text.
- Teacher-corrected text.
- AI-generated grading drafts.
- Teacher notes.
- Proposed scores.
- Final grades.
- Student-facing feedback reports.
- Internal teacher-only review records.
- Export files, if generated.

The core app must not:

- Upload student work to a server.
- Use cloud OCR.
- Use cloud AI grading.
- Use analytics.
- Depend on a server.
- Use advertising SDKs.
- Track users across apps or websites.
- Sell, share, or repurpose student data.
- Use student data for model training.
- Treat AI suggestions as final grades without teacher review.

This memo assumes that the core app runs on-device and that any later cloud, sync, collaboration, analytics, account, LMS, school admin, or remote support feature would be treated as a separate risk profile requiring separate legal, security, and App Store review.

---

## 4. Applicable Legal and Regulatory Frameworks

### 4.1 FERPA

#### 4.1.1 Legal framework

FERPA governs the privacy of education records at educational agencies and institutions that receive funds from applicable U.S. Department of Education programs. FERPA regulations define **education records** as records that are directly related to a student and maintained by an educational agency or institution or by a party acting for the agency or institution.

This matters because the app may store exactly the types of information that can become education records in school use: student names, rosters, submitted work, grades, assessment records, feedback, and teacher comments.

FERPA regulations also define **personally identifiable information** broadly. PII includes the student’s name, a student identification number, biometric records, and other information linked or linkable to a specific student that would allow a reasonable person in the school community to identify the student.

FERPA generally restricts disclosure of PII from education records without consent unless a specific exception applies. One frequently relevant exception is the **school official exception**, under which a school may disclose education records to a contractor, consultant, volunteer, or other party to whom the school has outsourced institutional services or functions, if that party performs a function for which the school would otherwise use employees, is under the school’s direct control with respect to the use and maintenance of education records, and is subject to FERPA’s use and redisclosure requirements.

**Primary sources:**  
- U.S. Department of Education FERPA regulations: https://studentprivacy.ed.gov/ferpa  
- 34 CFR Part 99, including definitions of education records and PII: https://www.ecfr.gov/current/title-34/subtitle-A/part-99  
- U.S. Department of Education Student Privacy Policy Office: https://studentprivacy.ed.gov/

#### 4.1.2 Application to local-first teacher app

A purely local app does not automatically become a FERPA-covered entity merely because it stores student data. FERPA obligations generally apply to educational agencies and institutions that receive covered federal funds, and vendors become relevant when acting on behalf of those schools.

However, the product should be designed on the assumption that:

- A school may treat app data as part of its instructional records.
- A district may require the vendor to sign a FERPA-aligned agreement.
- A teacher may export records from the app into official systems.
- A parent or eligible student may request access to records that were created or stored using the app.
- A district may require deletion or return of student data if the teacher or school stops using the app.

Because FERPA focuses on records maintained by schools or parties acting for schools, the key product question is not simply whether data leaves the device. The key question is whether the app supports school control, authorized access, limited use, secure handling, and controlled disclosure.

#### 4.1.3 Practical FERPA design implications

The app should support:

- Local-only storage by default.
- Teacher control and finalization of grades.
- Student-name-optional workflows.
- Pseudonymous local student identifiers.
- Clear separation between teacher notes and student-facing feedback.
- Export controls that warn teachers when FERPA-sensitive data may leave the app.
- Deletion controls for student records, assignments, scans, OCR text, grading drafts, and exports.
- Retention controls by class, assignment, student, and date.
- Documentation explaining that schools remain responsible for FERPA use decisions.
- A vendor security and privacy packet suitable for district review.
- A data map showing all data categories and storage locations.

The app should not imply that local-first architecture alone guarantees FERPA compliance. FERPA compliance depends on the school’s use, policies, contracts, disclosure practices, and state law.

---

### 4.2 COPPA

#### 4.2.1 Legal framework

COPPA applies to operators of websites or online services that are directed to children under 13 or that have actual knowledge they are collecting personal information online from children under 13. COPPA generally requires notice and verifiable parental consent before collecting, using, or disclosing personal information from children under 13.

**Primary sources:**  
- FTC COPPA Rule page: https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa  
- FTC COPPA FAQ: https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions

#### 4.2.2 Application to teacher-facing app

For the proposed product, COPPA risk is reduced because:

- The intended user is the teacher, not the child.
- The app is not designed for student accounts or direct child use.
- The core workflow does not collect information online from children.
- The app does not transmit student data to a developer server.

However, COPPA risk could reappear if:

- The app is marketed as student-facing or child-directed.
- The app is placed in Apple’s Kids Category.
- Students directly use the app.
- The app collects data from children through online features.
- Analytics, crash reporting, attribution, support, push notification, or SDK services transmit child-linked data off device.
- The app creates accounts for students under 13.
- The app lets children upload work directly to a developer-controlled service.

#### 4.2.3 COPPA design implications

The product should:

- State clearly that it is intended for teachers and educational professionals, not direct use by children.
- Avoid student account creation in the MVP.
- Avoid direct child-facing workflows in the MVP.
- Avoid cloud submission of student work.
- Avoid analytics and advertising SDKs.
- Avoid behavioral tracking.
- Avoid App Store Kids Category classification unless counsel affirmatively approves a child-directed product strategy.
- Use marketing, onboarding, and App Store metadata that consistently describe the product as teacher-facing.

The product should not say “COPPA does not apply” as an absolute statement. It should say the app is designed so that the core workflow does not collect personal information online from children and does not target children as users.

---

### 4.3 State Student Privacy Laws

#### 4.3.1 General landscape

Many states have enacted student privacy laws that regulate how education technology vendors handle student information. These laws vary, but commonly address:

- Written contracts with educational agencies.
- Limits on targeted advertising.
- Limits on sale or commercial use of student data.
- Data security requirements.
- Data deletion and return obligations.
- Parent/student rights.
- Breach notification.
- Vendor transparency.
- Data minimization.
- Prohibitions on profiling unrelated to educational purposes.

A local-first app reduces many risks, but state-law and district procurement requirements may still matter because schools may require vendor assurances even if data stays on device.

#### 4.3.2 California example: SOPIPA

California’s Student Online Personal Information Protection Act (SOPIPA), codified at California Business and Professions Code section 22584, is a major model for student privacy obligations. It restricts certain operators of K-12 online services from knowingly engaging in targeted advertising to students or parents using covered information, using covered information to create profiles except for K-12 school purposes, selling student information, and disclosing covered information except in specified circumstances.

**Primary source:**  
- California Business and Professions Code § 22584: https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=22584

For this product, SOPIPA-type principles strongly support the design decision to avoid advertising, tracking, behavioral profiling, model training, data sale, and secondary commercial use.

#### 4.3.3 New York example: Education Law § 2-d ecosystem

New York’s student data privacy regime is especially relevant for school procurement. The New York State Education Department maintains data privacy and security resources, including resources for parents, students, educational agencies, vendor supplemental information, incident reporting, and Parents’ Bill of Rights materials.

**Primary source:**  
- NYSED Data Privacy and Security: https://www.nysed.gov/data-privacy-security

A vendor seeking school adoption in New York should expect requests for privacy documentation, security practices, data inventory, vendor supplemental information, and contract language addressing student PII.

#### 4.3.4 Connecticut example: student data privacy contracting

Connecticut has statutory requirements and procurement practices relating to student data privacy, including obligations that can affect contracts between boards of education and operators of educational software. The Connecticut General Statutes are an example of how state law can impose terms beyond FERPA.

**Primary source:**  
- Connecticut General Statutes, Chapter 170: https://www.cga.ct.gov/current/pub/chap_170.htm

For a local-first teacher app, Connecticut-style contracting regimes should be treated as a procurement issue even if the vendor does not operate a cloud system.

#### 4.3.5 State-law design implications

The product should implement a conservative privacy baseline:

- No targeted advertising.
- No third-party advertising SDKs.
- No sale of student data.
- No use of student data for model training.
- No cross-context tracking.
- No behavioral profiling outside the grading task.
- No cloud transmission in the core workflow.
- Strong local access controls.
- Data deletion controls.
- Export warnings.
- A district-facing data inventory.
- A public privacy policy.
- A vendor security overview.
- Optional DPA-ready documentation.

This baseline will not solve every state-specific requirement, but it will make the product easier to review, explain, and contract for.

---

### 4.4 District Procurement, DPAs, and Vendor Review

Districts often require vendors to complete security questionnaires and sign data protection agreements even when a product is local-first. Many procurement processes are built around cloud vendors, but local-first vendors should still expect questions about:

- What student data is handled.
- Whether the vendor receives the data.
- Whether third parties receive the data.
- Whether analytics are present.
- Whether data is encrypted at rest.
- Whether data is backed up.
- Whether the app supports deletion.
- Whether exports contain student PII.
- Whether the vendor uses data for AI training.
- Whether the app is FERPA, COPPA, and state-law aligned.
- Whether breach notification obligations are triggered.
- Whether the vendor has a written incident response process.

The Student Data Privacy Consortium’s National Data Privacy Agreement (NDPA) is one important model for district/vendor contracting, although specific district and state forms vary.

**Reference source:**  
- Student Data Privacy Consortium: https://privacy.a4l.org/

#### Procurement design implications

The app should include a “district review packet” that answers:

- The app stores data locally by default.
- The vendor does not receive student work in the core workflow.
- The app does not include analytics, advertising, tracking, or cloud grading.
- The app does not train AI models on student data.
- The app uses iOS device security and file protection.
- The app supports local deletion and export controls.
- Sensitive student data is excluded from backup by default.
- Exports are user-initiated and warned.
- The teacher controls final grades.
- The app is not child-directed.

---

## 5. Apple App Store Review Implications

### 5.1 App Review Guidelines

Apple’s App Store Review Guidelines require apps to respect user privacy and follow applicable laws. The Guidelines also include specific restrictions for apps in the Kids Category and rules about data collection, tracking, user consent, and third-party code.

**Primary source:**  
- Apple App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

Relevant design implications include:

- The app’s metadata should accurately describe the product as teacher-facing.
- The app should not mislead users about data flows.
- The app should not use third-party SDKs that collect student data contrary to the privacy policy.
- If no data leaves the device, the app should not quietly enable network transmissions that contradict that claim.
- The app should not include tracking or advertising.
- The app should avoid the Kids Category unless the product is intentionally designed for children and counsel approves that approach.

### 5.2 App Store privacy labels

Apple requires developers to provide App Privacy information in App Store Connect. Apple’s App Privacy Details guidance says developers must identify data that they or third-party partners collect, unless optional disclosure criteria apply. Apple defines “collect” as transmitting data off the device in a way that allows the developer or third-party partners to access it for longer than what is necessary to service a real-time request. Apple also states that data processed only on device is not “collected” and does not need to be disclosed in App Store Connect answers.

**Primary source:**  
- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/

#### Correct App Store label conclusion for this app

If the app truly:

- Processes student data only on device.
- Does not transmit student data off device.
- Does not use analytics.
- Does not use third-party SDKs that collect data.
- Does not use Apple services in a way that the developer collects data.
- Does not operate accounts, sync, support uploads, crash reporting, remote diagnostics, or telemetry.

Then the conservative App Store Connect answer may be **“Data Not Collected”**, because Apple does not treat purely on-device processing as “collection” for App Privacy label purposes.

However, this is only accurate if the implementation is technically consistent with the claim. The answer changes if any of the following are added:

- Cloud sync.
- Cloud backup controlled by the app or developer.
- Server accounts.
- Remote grading.
- Cloud OCR.
- Crash reporting that includes user data, logs, filenames, document excerpts, or identifiers.
- Analytics.
- Error reporting.
- Support upload.
- Push notifications linked to user or school identity.
- LMS integration.
- Cloud export.
- Cloud licensing/entitlement systems linked to user identity.
- Third-party SDKs that transmit identifiers or diagnostics.
- Any feature that sends derived data off device.

#### Practical App Store label recommendation

For the MVP, the product should aim for:

- **App Privacy Label:** Data Not Collected, if and only if no app data is transmitted off device in Apple’s sense.
- **Privacy Policy:** Still required. The policy should explain local data storage, local processing, exports, deletion, backups, and user responsibility.
- **Privacy Choices URL:** Optional, but useful if you host a page explaining how users manage deletion, exports, local lock, backup, and privacy controls.

The privacy policy should not contradict the label. It should distinguish clearly between “the app stores student data locally” and “the developer does not collect student data.”

### 5.3 Kids Category

Apple’s Kids Category is intended for apps made specifically for children. Apps in the Kids Category face stricter requirements, including restrictions around third-party analytics and advertising. A teacher-facing grading assistant should generally avoid the Kids Category because:

- The intended user is the teacher.
- The app may store sensitive student records, but students are not the app users.
- Kids Category classification may make the product appear child-directed for COPPA analysis.
- Kids Category restrictions may complicate future product features.
- The app should not be marketed to children.

The app should instead use the general Education category, with metadata emphasizing educators, teacher review, local storage, and no student-facing autonomous grading.

### 5.4 Third-party SDKs, analytics, and tracking

The MVP should not include:

- Advertising SDKs.
- Attribution SDKs.
- Analytics SDKs.
- Third-party crash reporting.
- Remote logging.
- Session replay.
- Heatmaps.
- A/B testing SDKs.
- Social login.
- Third-party OCR.
- Cloud AI APIs.
- Data brokers.
- Tracking or cross-app identifiers.

If a crash reporting or support feature is later added, it must be opt-in, redact student data, avoid logs containing student work, and be reviewed as a separate privacy and App Store disclosure change.

---

## 6. Local-Only Privacy Architecture

### 6.1 Architecture principle

The core privacy claim should be technically true by construction:

> Student work, extracted text, rubrics, grading suggestions, teacher notes, grades, and feedback reports are processed and stored locally on the teacher’s device. The core grading workflow does not send student work to the developer, to cloud AI services, to cloud OCR services, to analytics providers, or to advertising networks.

This should be supported by:

- No network dependency in the grading path.
- No hidden telemetry.
- No remote model calls.
- No remote OCR calls.
- No cloud document parsing.
- No default cloud sync.
- No third-party data collection SDKs.
- Network-deny tests for core workflows.
- Privacy regression tests that fail if network calls are introduced in protected flows.

### 6.2 Local data flow

A defensible local flow should look like this:

1. Teacher creates a class or assignment locally.
2. Teacher optionally enters student names or pseudonymous local identifiers.
3. Teacher scans, photographs, imports, or pastes student work.
4. OCR runs locally, where applicable.
5. Teacher reviews and confirms OCR text before grading.
6. On-device model generates draft rubric-aligned suggestions.
7. Each proposed criterion score is grounded in teacher-confirmed evidence or flagged for review.
8. Teacher edits and finalizes grades and feedback.
9. Teacher exports only after explicit confirmation.
10. Teacher may delete local records at any time.

### 6.3 Local evidence boundary

The app should grade only from:

- Teacher-confirmed text.
- Teacher-approved rubrics.
- Teacher-provided instructions.
- Teacher-confirmed evidence links.
- Teacher-entered context.

The app should not infer private traits, effort, intent, disability, family background, protected class status, mental health, honesty, or behavior from student work.

### 6.4 Network boundary

The app should include release-blocking controls that confirm:

- No network request is made during OCR.
- No network request is made during grading.
- No network request is made when viewing student work.
- No network request is made when opening a student record.
- No network request is made when generating feedback.
- No network request is made when using local rubrics.
- No telemetry fires during sensitive workflows.
- Export uses only user-selected local/iOS share mechanisms and never developer-controlled upload unless a future feature explicitly changes the architecture.

---

## 7. Data Inventory

The product should maintain a formal data inventory. The initial data inventory should include at least the following categories.

### 7.1 Teacher account and settings data

- Teacher display name, if entered.
- School/class labels, if entered.
- Local preferences.
- Local app lock settings.
- Local grading defaults.
- Rubric templates.
- Custom instruction templates.

### 7.2 Student roster data

- Student names.
- Student initials.
- Student local identifiers.
- Optional pseudonyms.
- Class membership.
- Group membership, if supported.
- Assignment associations.

### 7.3 Assignment data

- Assignment title.
- Assignment instructions.
- Rubric.
- Point values.
- Criteria.
- Standards mappings, if any.
- Teacher-provided custom grading rules.
- Exemplars or answer keys, if provided.

### 7.4 Student work data

- Pasted text.
- Imported text files.
- PDFs.
- Document images.
- Camera scans.
- Photos of student work.
- OCR output.
- Teacher-corrected OCR text.
- OCR confidence/uncertainty data.
- Source image references.
- Page/region references.
- Evidence quotes.

### 7.5 Grading data

- Proposed criterion scores.
- Final criterion scores.
- Proposed total scores.
- Final total scores.
- Evidence cited for each criterion.
- Rationale/explanation text.
- Uncertainty flags.
- Teacher overrides.
- Timestamped review status.
- Draft feedback.
- Final feedback.

### 7.6 Teacher-only internal data

- Private notes.
- Internal assessment comments.
- Draft comments not intended for students.
- Review checklists.
- Internal uncertainty notes.
- Manual adjustment reasons.
- Notes about OCR quality.
- Notes about rubric ambiguity.

### 7.7 Export data

- PDFs.
- CSVs.
- JSON files.
- ZIP/archive bundles.
- Feedback reports.
- Gradebooks.
- Backup files.
- Diagnostic packages, if ever added.

### 7.8 Derived and metadata data

- Local record IDs.
- Local file paths.
- Hashes or checksums.
- Creation/modification dates.
- Device-local processing status.
- Local model output metadata.
- Error states.
- OCR uncertainty metadata.

---

## 8. Sensitive Data Classification

The app should classify data by sensitivity and usage.

### 8.1 Highest sensitivity: student-linked education records

This includes:

- Student names linked to assignments.
- Grades.
- Final feedback.
- Student work.
- Scanned work images.
- OCR text.
- Rubric-level evaluations.
- Teacher comments linked to a student.
- Evidence quotes linked to a student.
- Exported grade reports.

Controls required:

- Local encryption/file protection.
- App lock.
- Deletion controls.
- Export warning.
- Backup exclusion by default.
- No analytics or telemetry.
- No cloud transmission.

### 8.2 High sensitivity: teacher-only records

This includes:

- Private teacher notes.
- Internal review notes.
- Draft grading rationale.
- Uncertainty notes.
- Override reasons.
- Records of teacher decision-making.

Controls required:

- Never include in student-facing reports by default.
- Mark as “Teacher Only.”
- Require explicit opt-in before export.
- Redaction checks in report generation.
- Separate storage or tagging from student-facing feedback.

### 8.3 Moderate sensitivity: rubrics and assignment templates

This includes:

- Rubric templates.
- Custom instruction templates.
- Assignment prompts.
- Scoring settings.

These may not be student PII by themselves, but they can become sensitive when linked to specific students, classes, or grades.

### 8.4 Security metadata

This includes:

- Local record identifiers.
- Database keys.
- Export manifests.
- File hashes.
- App lock state.

These should be protected because they may reveal student record structure or facilitate unauthorized access.

---

## 9. Student Names, Local Identifiers, and Pseudonyms

### 9.1 Should student names be optional?

Yes. Student names should be optional.

The app should support:

- Named roster mode.
- Pseudonymous roster mode.
- Local ID mode.
- Assignment-only mode with no roster.
- Temporary grading mode.

This reduces unnecessary PII and supports teachers who want privacy-preserving workflows.

### 9.2 Recommended identifier model

The app should separate:

- **Display name:** Optional human-readable name.
- **Local student ID:** Random app-generated local identifier.
- **Teacher alias/pseudonym:** Optional teacher-entered pseudonym.
- **External school ID:** Avoid by default; allow only if teacher intentionally adds it.
- **Export name field:** Configurable per export.

The app should not require:

- Student email.
- Student date of birth.
- Student address.
- Student demographic data.
- Student disability status.
- Student parent contact information.
- School-issued student ID.

### 9.3 Pseudonym workflow

The app should allow the teacher to import or create a roster using pseudonyms such as “Student A,” “Student B,” or teacher-defined aliases. The app can keep a local mapping if the teacher chooses, but that mapping should be treated as highly sensitive.

### 9.4 Export implications

Exports should let the teacher choose:

- Include full student names.
- Include initials only.
- Include pseudonyms only.
- Include local IDs only.
- Exclude student identifiers entirely, where practical.

---

## 10. Backup, iCloud, and Sync

### 10.1 Should scanned images, student work, and grade records be excluded from iCloud backup by default?

Yes. Sensitive student data should be excluded from iCloud backup by default.

The app should treat the following as backup-excluded by default:

- Scanned work images.
- Imported PDFs.
- OCR text.
- Teacher-confirmed student text.
- Student names and roster records.
- Grades.
- Teacher notes.
- Feedback reports.
- Export archives.
- Backup bundles.

Apple provides mechanisms for developers to mark files as excluded from backup. The product should use the appropriate file resource values for sensitive generated files and should document backup behavior clearly.

### 10.2 Why exclude backup by default?

Excluding sensitive student data from backup by default supports:

- Local-first privacy claims.
- Data minimization.
- Lower risk of unintended cloud copies.
- Easier district review.
- Clearer App Store and privacy policy disclosures.
- Reduced risk from shared Apple IDs or unmanaged personal devices.

### 10.3 Optional backup

If optional backup is later added, it should require:

- Explicit opt-in.
- A clear warning.
- Explanation of what will be backed up.
- Per-category backup controls.
- Easy disablement.
- Deletion instructions.
- Counsel review.
- App Store privacy review.
- District review.

### 10.4 iCloud Drive and Files app exports

Even if the app excludes internal data from iCloud backup, a teacher may choose to export files to iCloud Drive, Google Drive, OneDrive, email, LMS systems, or other destinations through iOS share flows. The app cannot fully control what happens after user-initiated export. The app should warn the teacher before export and should label exported files clearly.

---

## 11. iOS Local Security Recommendations

### 11.1 Apple Data Protection and file protection

Apple Platform Security describes Data Protection as a system that uses per-file encryption and protection classes. Third-party apps receive Data Protection automatically, and developers can opt files into stronger protection classes.

**Primary source:**  
- Apple Platform Security, Data Protection overview: https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web

The app should:

- Use strong file protection classes for sensitive files.
- Prefer protection that makes sensitive files unavailable while the device is locked.
- Ensure newly created scans, OCR files, databases, export drafts, and caches receive the intended protection class.
- Test file protection behavior when the device is locked/unlocked.
- Avoid leaving sensitive data in unprotected temporary directories.

### 11.2 Database encryption

If the app uses SQLite, Core Data, SwiftData, or a local document store, it should consider:

- Database-level encryption where feasible.
- Encrypting sensitive blobs separately.
- Avoiding plaintext copies in caches.
- Secure deletion limitations on flash storage.
- Encrypted export bundles if supported.
- Key rotation and migration strategies.
- Protecting search indexes and derived caches.

iOS file protection is important, but database-level encryption can provide additional protection for sensitive educational records, especially if exports, backups, or support packages become part of the product later.

### 11.3 Keychain

Use Keychain for:

- App-specific encryption keys.
- Local lock secrets.
- Export encryption keys, if supported.
- Recovery metadata, if any.

Avoid storing:

- Student work.
- Rubric content.
- Grade data.
- Large notes or files.

Keychain access controls should align with the intended security posture. Keys should not be accessible when the device is locked unless a specific user-facing feature requires it.

### 11.4 LocalAuthentication

Use LocalAuthentication for:

- App unlock.
- Access to student records.
- Access to teacher notes.
- Export generation.
- Export of full roster/gradebook.
- Privacy settings changes.
- Backup enablement.
- Deletion of all data, where an extra safety check is useful.

The app should state that Face ID/Touch ID/passcode protects access to the app on that device. It should not state that biometric lock encrypts all exported files or protects files after export unless that is separately implemented.

### 11.5 App sandboxing

The iOS app sandbox helps isolate app data from other apps. The app should rely on sandboxing but should not overstate it. Once the user exports a file through share sheets, Files, email, LMS upload, or another app, the exported copy is outside the app sandbox.

### 11.6 Clipboard controls

The app should minimize unnecessary clipboard use.

Recommended controls:

- Do not automatically copy student data to clipboard.
- Warn when copying student-linked feedback or grades.
- Offer “copy student-facing feedback only” and “copy with identifiers removed.”
- Avoid copying teacher-only notes unless explicitly requested.
- Consider automatic clipboard expiration messaging, while acknowledging iOS clipboard behavior is outside full app control.

### 11.7 Screenshots and screen recording

iOS generally allows screenshots and screen recordings. For sensitive screens, the app may:

- Display privacy reminders.
- Obscure sensitive content in app switcher snapshots, where feasible.
- Offer a “privacy mode” that hides names and grades.
- Provide “show names” toggles.

Do not claim the app can prevent all screenshots or recording unless it actually implements a specific supported mechanism.

### 11.8 Logs and diagnostics

The app should never log:

- Student names.
- Student work text.
- OCR output.
- Grades.
- Teacher notes.
- Rubric feedback tied to a student.
- Export paths containing student names.
- File thumbnails.

Diagnostic logging should use redacted IDs and should remain local unless the user explicitly exports a diagnostic bundle. Diagnostic bundles should be separately warned and should exclude student content by default.

---

## 12. Local Lock, Face ID, Passcode, Encryption, Backups, and Exports: How to Describe Without Overclaiming

### 12.1 Accurate claims

The app may say:

- “The core grading workflow runs on device.”
- “Student work is stored locally on this device.”
- “The app does not upload student work to our servers.”
- “The app does not use cloud AI grading in the core workflow.”
- “The app does not use analytics or advertising SDKs.”
- “The app uses iOS device security features, including file protection.”
- “You can enable an app lock using Face ID, Touch ID, or device passcode.”
- “Sensitive app files are excluded from iCloud backup by default.”
- “Exports are created only when you choose to export.”
- “Exported files may contain sensitive student information and must be handled securely.”

### 12.2 Claims to avoid

The app should not say:

- “FERPA compliant” as an unqualified certification.
- “COPPA compliant” as an unqualified certification.
- “District approved” unless approved by a specific district.
- “Anonymous” when pseudonymous or identifiable records exist.
- “De-identified” unless a robust de-identification process exists.
- “Unhackable.”
- “Fully secure.”
- “No one can access your data.”
- “Face ID encrypts your data.”
- “iCloud backup is secure for student records.”
- “Exports remain protected after sharing.”
- “The app guarantees legal compliance.”
- “AI grades students automatically.”
- “Teacher notes are never disclosed” unless every export path is tested and gated.

### 12.3 Preferred wording

Use measured wording:

> “This app is designed for local processing. Student work and grading records are stored on your device and are not sent to our servers in the core workflow.”

> “Device security matters. Use a strong device passcode and enable Face ID or Touch ID for the app lock.”

> “Exported files leave the app’s protected storage. Handle exported files according to your school’s student privacy policies.”

---

## 13. Export and Backup Warning Language

### 13.1 General export warning

> This export may contain sensitive student information, including student names, work samples, grades, teacher feedback, and scanned images. Once exported, the file may no longer be protected by this app’s local security controls. Store and share the file only through channels approved by your school or district.

### 13.2 PDF feedback report warning

> This PDF may include student-facing feedback and grading information. Review the report before sharing. Teacher-only notes and internal review comments should not be included unless you intentionally choose to include them.

### 13.3 CSV gradebook warning

> This CSV may contain student names, identifiers, grades, and assignment records. Spreadsheet files can be easily copied, emailed, or uploaded. Handle this export as a student record and store it only in approved systems.

### 13.4 JSON export warning

> This JSON export may contain structured student records, including work text, OCR output, grading drafts, final grades, evidence references, and teacher notes. Use this format only if you understand the contents and have an approved storage or transfer location.

### 13.5 ZIP/archive warning

> This archive may contain multiple files, including scanned images, OCR text, grades, rubrics, feedback, and metadata. Archives may contain more student information than a visible report. Review the archive contents and share only through approved channels.

### 13.6 Backup warning

> Enabling backup may copy student records outside this app’s local storage. Before enabling backup, confirm that your school or district permits the backup location for student information.

### 13.7 iCloud warning

> iCloud is an Apple service outside this app’s local-only storage. If you choose to store exports or backups in iCloud, those files will be governed by your Apple account settings and your school’s policies.

### 13.8 Email/share sheet warning

> You are about to share a file that may contain sensitive student information. Confirm that the selected destination is authorized for student records.

### 13.9 Teacher-note warning

> Teacher-only notes are intended for your internal use. They are not included in student-facing reports unless you explicitly select them.

### 13.10 Redaction confirmation

> Before sharing, confirm that the report does not include private teacher notes, draft comments, internal uncertainty flags, or other content not intended for the recipient.

---

## 14. Preventing Leakage of Private Teacher Notes

### 14.1 Product rule

Teacher-only notes must never appear in student-facing reports by default.

### 14.2 Data model requirement

The data model should separate:

- Student-facing feedback.
- Teacher-only notes.
- Internal AI rationale.
- OCR uncertainty notes.
- Rubric ambiguity notes.
- Draft feedback.
- Final feedback.
- Export-included fields.
- Export-excluded fields.

Do not store all comments in a generic “notes” field and decide later. The product should enforce field purpose at the data-model level.

### 14.3 UI requirement

The UI should visibly label:

- “Student-facing feedback.”
- “Teacher-only note.”
- “Internal review flag.”
- “Draft AI suggestion.”
- “Final teacher-approved comment.”

### 14.4 Export requirement

Every export template should have a field inclusion manifest. Student-facing exports should exclude teacher-only fields by default.

### 14.5 Acceptance test examples

- A teacher-only note entered on a student record does not appear in the student report PDF.
- A teacher-only note does not appear in CSV export unless a teacher explicitly selects “include teacher-only notes.”
- A ZIP export includes a manifest showing whether teacher-only notes are included.
- If the teacher selects teacher-only notes for export, the export dialog gives a heightened warning.
- Draft AI rationale is not included in student-facing feedback unless converted into teacher-approved language.

---

## 15. Deletion, Retention, and Export Controls

### 15.1 Deletion controls

The app should allow deletion at multiple levels:

- Delete one scan.
- Delete OCR text for one scan.
- Delete one student work submission.
- Delete one assignment.
- Delete one student record.
- Delete one class.
- Delete all teacher notes.
- Delete all grading drafts.
- Delete all finalized grades.
- Delete all exports.
- Delete all app data.

### 15.2 Retention controls

The app should support:

- Per-class retention settings.
- Per-assignment retention settings.
- End-of-term archive/delete workflow.
- Warnings before retaining sensitive records beyond a school year.
- Teacher reminders to delete old records.
- Local archive export with warning, if the teacher intentionally wants a record.

### 15.3 Deletion limitations

The app should be honest that:

- Deleted app data cannot be recovered by the app.
- Exported copies are outside the app’s control.
- User-created backups may retain deleted data.
- iOS storage behavior and flash memory mean secure deletion guarantees should not be overclaimed.
- School policies may require retention of certain records outside the app.

### 15.4 Export controls

The app should support:

- Student-facing report export.
- Teacher internal export.
- Gradebook export.
- Full local backup export.
- Redacted export.
- Pseudonymized export.
- Name-excluded export.
- Per-student export.
- Per-class export.
- Per-assignment export.

Each export should show:

- What data categories are included.
- Whether student names are included.
- Whether teacher-only notes are included.
- Whether scanned images are included.
- Whether OCR text is included.
- Whether AI draft suggestions are included.
- Whether final teacher-approved grades are included.

---

## 16. Privacy Policy Language Themes

The privacy policy should be concise but complete. It should include the following themes.

### 16.1 Local storage

The policy should say that student work, grading records, rubrics, notes, and feedback are stored locally on the device.

Recommended wording:

> The app stores classroom and grading data locally on your device. The core grading workflow does not send student work, grades, teacher notes, or feedback reports to our servers.

### 16.2 No cloud AI or cloud OCR in core workflow

Recommended wording:

> The app’s core OCR, review, and grading-assistance workflows are designed to run on device. The app does not use cloud OCR or cloud AI grading for the core workflow.

### 16.3 No analytics, advertising, or tracking

Recommended wording:

> The app does not include third-party analytics, advertising, tracking, or data broker SDKs in the core product.

### 16.4 Data categories

The policy should list:

- Student names or pseudonyms.
- Class rosters.
- Assignment details.
- Rubrics.
- Scanned work.
- OCR text.
- Teacher-confirmed text.
- Draft scores.
- Final scores.
- Teacher notes.
- Feedback.
- Exports.

### 16.5 User control

The policy should describe:

- Deletion.
- Export.
- Backup settings.
- App lock.
- Pseudonym use.
- Report redaction.

### 16.6 Exports

The policy should say that exported files are user-directed and may contain sensitive student information.

### 16.7 Backups

The policy should say that sensitive data is excluded from iCloud backup by default, if implemented. It should explain that user-created exports may be stored wherever the user sends them.

### 16.8 Schools and legal obligations

Recommended wording:

> Teachers and schools are responsible for using the app in accordance with their own student privacy policies, FERPA obligations, state student privacy laws, and district-approved recordkeeping practices.

### 16.9 No legal certification

The policy should not claim blanket FERPA or COPPA certification. It should describe product practices instead.

---

## 17. App Store Privacy Label Recommendations

### 17.1 MVP with no off-device transmission

If the MVP truly performs all processing on device and the developer does not receive any app data, the likely App Store privacy label position is:

- **Data Collected:** None / Data Not Collected.

This conclusion is based on Apple’s current App Privacy Details guidance, which states that “collect” refers to transmitting data off device in a way that allows the developer or third-party partners to access it beyond what is necessary for a real-time request, and that data processed only on device is not “collected” and does not need to be disclosed in App Store Connect answers.

### 17.2 Conditions for “Data Not Collected”

The app must not transmit:

- Student names.
- Student IDs.
- Student work.
- OCR text.
- Scanned images.
- Grades.
- Teacher notes.
- Feedback.
- Rubrics.
- Assignment content.
- Diagnostics containing student data.
- Device identifiers tied to use.
- Analytics.
- Crash reports containing local context.
- Support bundles.
- Export copies.
- Derived model output.

### 17.3 Privacy policy despite “Data Not Collected”

Even if the App Privacy label says “Data Not Collected,” the app should still have a privacy policy because:

- Apple requires a privacy policy URL.
- Schools and districts will review it.
- Teachers need to understand local storage.
- Exports and backups create practical privacy risks.
- The app handles sensitive educational data locally even if the developer does not collect it.

### 17.4 If future features are added

The privacy label must be revisited if the app adds:

- Accounts.
- Licensing tied to identity.
- Cloud sync.
- iCloud documents or CloudKit controlled by the app.
- LMS integration.
- Email support from within the app.
- Crash reporting.
- Analytics.
- App usage telemetry.
- Remote AI.
- Remote OCR.
- Server backup.
- Shared classes.
- School admin dashboards.
- Push notifications.
- Payment or subscription analytics.
- Third-party SDKs.

### 17.5 Practical rule

Do not answer App Store privacy questions based on the product narrative. Answer based on observed data flows from the actual shipping binary, including SDK behavior.

---

## 18. Product Requirements and Acceptance Criteria

### 18.1 Privacy architecture requirements

**Requirement:** The core grading workflow must run without network access.  
**Acceptance criteria:** With networking disabled or blocked, the app can import or paste text, run local OCR where supported, review text, apply rubric, generate draft grading suggestions, allow teacher finalization, and create local exports.

**Requirement:** No student data may be transmitted to developer-controlled infrastructure in the MVP.  
**Acceptance criteria:** Network inspection during core workflows shows no transmission of student names, work, OCR text, grades, notes, rubrics, feedback, or derived outputs.

**Requirement:** No analytics or advertising SDKs may be included in the MVP.  
**Acceptance criteria:** Dependency review confirms no analytics, attribution, advertising, session replay, heatmap, or tracking SDKs.

### 18.2 Data minimization requirements

**Requirement:** Student names must be optional.  
**Acceptance criteria:** A teacher can grade using pseudonyms or local IDs without entering student names.

**Requirement:** The app must not require unnecessary student fields.  
**Acceptance criteria:** The app does not require date of birth, address, demographic data, disability status, parent contact information, or external student IDs.

**Requirement:** The app must support pseudonymous roster mode.  
**Acceptance criteria:** A teacher can create and export records using pseudonyms only.

### 18.3 Storage security requirements

**Requirement:** Sensitive files must use iOS file protection.  
**Acceptance criteria:** Scans, OCR text, databases, teacher notes, grades, and exports-in-progress are stored with intended protection classes.

**Requirement:** Sensitive files must be excluded from iCloud backup by default.  
**Acceptance criteria:** Files containing student data have backup-exclusion attributes set, and tests verify the attribute on created files.

**Requirement:** The app must avoid sensitive caches.  
**Acceptance criteria:** Temporary directories, thumbnails, logs, and previews do not retain unprotected student content.

### 18.4 App lock requirements

**Requirement:** The app must offer local lock using Face ID, Touch ID, or device passcode.  
**Acceptance criteria:** When enabled, sensitive screens require reauthentication after launch, timeout, or backgrounding.

**Requirement:** App switcher previews should avoid exposing student data where feasible.  
**Acceptance criteria:** Background snapshots obscure or hide sensitive screens if technically supported.

### 18.5 Export requirements

**Requirement:** Every export must show a data-included summary.  
**Acceptance criteria:** Before export, the user sees whether names, grades, scanned work, OCR text, teacher notes, and draft AI content are included.

**Requirement:** Exports must require explicit confirmation.  
**Acceptance criteria:** The export cannot occur through a silent or one-tap background process for sensitive data.

**Requirement:** Student-facing exports must exclude teacher-only notes by default.  
**Acceptance criteria:** Automated tests confirm teacher-only notes do not appear in student-facing PDFs, CSVs, or report exports.

**Requirement:** CSV exports must protect against spreadsheet formula injection.  
**Acceptance criteria:** String fields beginning with dangerous spreadsheet formula prefixes such as `=`, `+`, `-`, `@`, or leading whitespace before those characters are safely escaped according to the app’s export policy.

### 18.6 Deletion and retention requirements

**Requirement:** The app must support deletion of individual records and all app data.  
**Acceptance criteria:** A teacher can delete a student submission, an assignment, a class, a student, and all app data from settings.

**Requirement:** Deletion should distinguish internal data from exported copies.  
**Acceptance criteria:** Deletion UI states that exports and external backups are outside the app’s control.

**Requirement:** The app should support end-of-term cleanup.  
**Acceptance criteria:** A teacher can review old classes and delete or archive them with warnings.

### 18.7 Report separation requirements

**Requirement:** Teacher-only notes must be separate from student-facing feedback.  
**Acceptance criteria:** Data model, UI labels, and export templates distinguish teacher-only notes from student-facing comments.

**Requirement:** Draft AI suggestions must not become final comments without teacher approval.  
**Acceptance criteria:** Reports show only teacher-finalized feedback, not raw draft suggestions, unless intentionally included in an internal export.

### 18.8 Privacy documentation requirements

**Requirement:** The app must include an in-app privacy explanation.  
**Acceptance criteria:** Settings include a privacy screen summarizing local processing, no cloud grading, no analytics, exports, deletion, and backups.

**Requirement:** Public privacy policy must match implementation.  
**Acceptance criteria:** Privacy policy, App Store label, and actual network behavior are reviewed before release.

### 18.9 App Store submission requirements

**Requirement:** App Store privacy answers must be based on actual data flows.  
**Acceptance criteria:** Before submission, engineering signs off that no data is transmitted off device in the MVP.

**Requirement:** The app must avoid Kids Category unless intentionally redesigned for child users.  
**Acceptance criteria:** App Store metadata identifies teachers/educators as the intended audience.

### 18.10 Compliance review requirements

**Requirement:** Maintain a district review packet.  
**Acceptance criteria:** The packet includes privacy policy, security overview, data inventory, local-only architecture summary, export warnings, deletion controls, and “no cloud AI/no analytics/no advertising” statements.

---

## 19. Do Not Claim List

The product, website, App Store listing, privacy policy, onboarding, and procurement materials should not claim:

1. “FERPA compliant” as a blanket certification.
2. “COPPA compliant” as a blanket certification.
3. “Compliant with all state student privacy laws.”
4. “Anonymous” if student records can be linked to names, aliases, local IDs, scans, or context.
5. “De-identified” unless robust de-identification is implemented and documented.
6. “Unhackable.”
7. “Fully secure.”
8. “No one can access your data.”
9. “Apple/iCloud makes student data compliant.”
10. “Exports remain protected after sharing.”
11. “Face ID encrypts exported files.”
12. “Backups are always safe for student records.”
13. “AI grades students.”
14. “Autonomous grading.”
15. “No teacher review required.”
16. “No legal review needed for schools.”
17. “Kids Category safe” unless the app is actually designed and approved for that classification.
18. “No data concerns because everything is local.”
19. “Teacher notes can never leak” unless all export and report paths enforce that.
20. “The app never stores personal data” if it stores student names or work locally.

Preferred framing:

- “Designed to support local-first student privacy.”
- “Teacher-controlled grading assistance.”
- “No cloud grading in the core workflow.”
- “No developer collection of student work in the MVP.”
- “Local data remains under the teacher’s device control unless exported.”
- “Schools should use the app consistent with applicable policies and laws.”

---

## 20. Open Legal Questions for Counsel

Counsel should review the following issues before launch or institutional sales.

### 20.1 FERPA status and contracting

- When a teacher independently uses the app, under what circumstances is the vendor considered a party acting for the school?
- If the vendor never receives student data, what FERPA contract terms are still appropriate?
- Should the vendor offer a FERPA school official addendum even though data is local-only?
- How should the app support access, amendment, and deletion requests under school policies?

### 20.2 State student privacy

- Which target states impose vendor contract requirements even for local-first tools?
- Do state laws define “operator,” “vendor,” or “educational technology provider” broadly enough to cover local-only apps?
- Are there state-specific encryption, breach notification, or deletion requirements that should be included in the product baseline?
- How should the product handle New York Education Law § 2-d vendor documentation requests?
- How should California SOPIPA-type restrictions be reflected in policy and product language?

### 20.3 COPPA and child-directed classification

- Does any marketing, App Store metadata, imagery, or workflow imply child-directed use?
- Would student-facing review or feedback screens change the COPPA analysis?
- If students later submit work directly, what parental consent or school-consent framework would be needed?

### 20.4 App Store privacy labels

- Is “Data Not Collected” accurate for the actual shipping binary?
- Do any Apple services, SDKs, diagnostics, payment flows, or entitlement systems transmit data that must be disclosed?
- Does the privacy policy clearly distinguish local storage from developer collection?

### 20.5 iCloud, backup, and sync

- Is default backup exclusion legally advisable for all student data?
- If optional iCloud sync is later added, is Apple a service provider or merely the user’s selected storage provider for the relevant legal analysis?
- Would iCloud sync or CloudKit require new App Store labels, privacy policy changes, and district contract changes?

### 20.6 Exports and school records

- What warnings are legally sufficient when teachers export student records?
- Should exports include standard metadata stating that files may contain student education records?
- Should the app support district-required retention formats?

### 20.7 Security representations

- What exact security claims can be made in marketing and procurement materials?
- Should the app undergo third-party security review before district sales?
- What breach notification position is appropriate if the vendor never receives student data?

---

## 21. Source List

### Federal student privacy

1. U.S. Department of Education, FERPA regulations and resources:  
   https://studentprivacy.ed.gov/ferpa

2. Electronic Code of Federal Regulations, 34 CFR Part 99:  
   https://www.ecfr.gov/current/title-34/subtitle-A/part-99

3. U.S. Department of Education Student Privacy Policy Office:  
   https://studentprivacy.ed.gov/

### COPPA

4. FTC, Children’s Online Privacy Protection Rule:  
   https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa

5. FTC, Complying with COPPA: Frequently Asked Questions:  
   https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions

### Apple App Store and platform security

6. Apple, App Store Review Guidelines:  
   https://developer.apple.com/app-store/review/guidelines/

7. Apple, App Privacy Details:  
   https://developer.apple.com/app-store/app-privacy-details/

8. Apple Platform Security, Data Protection overview:  
   https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web

9. Apple Developer Documentation, LocalAuthentication:  
   https://developer.apple.com/documentation/localauthentication

10. Apple Developer Documentation, Keychain Services:  
    https://developer.apple.com/documentation/security/keychain-services

### State student privacy examples and procurement ecosystem

11. California Business and Professions Code § 22584:  
    https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=BPC&sectionNum=22584

12. New York State Education Department, Data Privacy and Security:  
    https://www.nysed.gov/data-privacy-security

13. Connecticut General Statutes, Chapter 170:  
    https://www.cga.ct.gov/current/pub/chap_170.htm

14. Student Data Privacy Consortium:  
    https://privacy.a4l.org/

---

## 22. Bottom-Line Design Position

The app should be designed as a **local-first, teacher-controlled, evidence-grounded grading assistant** with no cloud processing in the core workflow. The privacy posture should be implemented at the architecture level, not merely described in policy language. The safest MVP posture is:

- No developer collection of student work.
- No analytics.
- No advertising.
- No tracking.
- No cloud OCR.
- No cloud AI grading.
- No student accounts.
- No child-directed classification.
- Student names optional.
- Pseudonyms supported.
- Sensitive local files protected.
- Sensitive backups excluded by default.
- Exports explicitly warned.
- Teacher-only notes separated from student-facing reports.
- Deletion and retention controls built in.
- Privacy policy and App Store labels aligned with actual data flows.

That combination gives the product the strongest practical position for App Store review, district trust, and education-law defensibility while preserving the core value proposition of AI-assisted grading under teacher control.
