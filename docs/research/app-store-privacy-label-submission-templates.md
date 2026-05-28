# App Store Privacy Label Templates

**Product:** [App Name]  
**Audience:** App Store submission, product, legal, and engineering teams  
**Use Case:** Local-first iOS/iPadOS teacher grading assistant  
**Status:** Draft submission template for counsel and App Store review preparation  
**Last updated:** May 28, 2026

---

## 1. Critical Apple Definition

Apple’s App Privacy Details use a specific definition of “collect.” Apple states that “collect” means transmitting data off the device in a way that allows the developer or third-party partners to access it for longer than necessary to service a transmitted request in real time. Apple also states that data processed only on device is not “collected” and does not need to be disclosed in App Store Connect privacy answers.

This distinction matters. A local-first teacher grading app may store sensitive student information on device, but if the developer and third-party partners cannot access that information because it never leaves the device, the App Store privacy label may properly be “Data Not Collected.” The privacy policy should still clearly explain local storage and local processing so that schools and teachers understand the sensitivity of the data.

---

## 2. Baseline Assumptions for the Recommended Label

The recommended baseline below applies only if all of the following statements are true:

- The app is teacher-facing and not directed to children.
- Student work, scans, OCR text, grades, rubrics, teacher notes, and feedback remain local to the teacher’s device.
- The app does not use cloud OCR.
- The app does not use cloud AI grading.
- The app does not upload student work or derived grading data to the developer.
- The app does not include third-party analytics, advertising, tracking, or crash-reporting SDKs that transmit user data.
- The app does not create developer-accessible teacher or student accounts.
- The app does not sync student records through a developer-controlled backend.
- The app does not transmit support bundles, logs, screenshots, attachments, or diagnostics without a separate user-initiated flow that has been separately analyzed.
- The app does not use any third-party AI service or API in the core grading workflow.

If any of these assumptions changes, the App Store privacy answers must be re-evaluated before submission.

---

## 3. Recommended Baseline App Store Privacy Answer

### App Privacy: Data Collection

**Recommended answer:** Data Not Collected.

**Rationale:** In the baseline local-first design, student and teacher data are processed and stored only on device, and no data is transmitted off device to the developer or third-party partners. Under Apple’s App Privacy Details, data processed only on device is not “collected” for privacy-label purposes.

### Tracking

**Recommended answer:** No.

**Rationale:** The baseline design does not link app data with third-party data for targeted advertising or advertising measurement and does not share data with data brokers.

### Data Linked to the User

**Recommended answer:** Not applicable if “Data Not Collected” is selected.

### Data Used to Track You

**Recommended answer:** Not applicable if “Tracking” is No and no data is collected.

---

## 4. App Store Connect Privacy Questionnaire Template

| App Store Connect Area | Baseline Local-Only Answer | Notes |
|---|---|---|
| Does the app collect data from this app? | No | Use only if no data is transmitted off device to the developer or third-party partners. |
| Does the app use data for tracking? | No | No advertising SDKs, no data brokers, no cross-app tracking. |
| Does the app use third-party analytics? | No | Do not include third-party analytics SDKs in the core app. |
| Does the app use third-party advertising? | No | No ads. |
| Does the app collect diagnostics? | No | Use only if no developer-accessible diagnostics, logs, or crash reports are transmitted. Apple’s own App Store analytics are separate from app-collected data. |
| Does the app collect user content? | No | Use only if scans, OCR text, grading data, and reports remain on device and are not accessible to the developer. |
| Does the app collect identifiers? | No | Use only if no account IDs, device IDs, advertising IDs, or server identifiers are transmitted to the developer or partners. |
| Does the app collect contact info? | No | Use only if names, emails, or rosters remain on device and are not transmitted off device. |

---

## 5. Privacy Policy Alignment Language

Even if the privacy label is “Data Not Collected,” the privacy policy should not imply that the app handles no sensitive information. Use language like this:

> [App Name] stores and processes student work, grading records, rubrics, teacher notes, and feedback locally on your device. The developer does not receive, upload, or access this information in the core app workflow. Because this information is processed only on device and is not transmitted to the developer or third-party partners, it is not “collected” for purposes of Apple’s App Privacy label. You should still treat local app data and exported files as sensitive student information.

Avoid language like this:

> We do not handle student data.

That statement would be misleading, because the app does handle student data locally.

---

## 6. App Review Notes Template

Use a short, direct explanation in App Review notes:

> [App Name] is a teacher-facing local-first grading assistant. The core workflow runs on device. The app does not upload student work, OCR text, rubrics, grading drafts, teacher notes, final grades, or feedback reports to the developer or third-party services. The app does not include third-party analytics, advertising, tracking, or cloud AI grading. Student work may be imported or scanned by the teacher and remains in local app storage unless the teacher explicitly exports it through the iOS share sheet. The app includes in-app warnings for sensitive exports and is intended for teachers, not direct child use.

If the app has no accounts, add:

> The app does not require a user account, and there is no developer-accessible backend account database.

If the app has a local lock, add:

> The app includes local device authentication for sensitive areas and exports where supported.

---

## 7. Feature Change Matrix

The following table identifies features that would require privacy-label re-analysis.

| Feature | Baseline Recommendation | Label Impact if Added |
|---|---|---|
| Third-party analytics SDK | Do not include | May require Usage Data, Diagnostics, Device ID, or other disclosures depending on SDK behavior. |
| Third-party crash reporting | Do not include in MVP | May require Diagnostics disclosure if crash logs or related data are transmitted and accessible. |
| Developer account login | Avoid unless necessary | May require Contact Info, Identifiers, and possibly User Content depending on account data. |
| Cloud AI grading | Exclude from core flow | Would likely require User Content and possibly Sensitive Info or Other Data disclosures, plus explicit consent and third-party AI disclosure. |
| Cloud OCR | Exclude from core flow | Would likely require User Content, Photos or Videos, and/or Other User Content disclosures. |
| Developer-controlled sync | Exclude from core flow | Would likely require disclosures for all synced categories, including identifiers and user content. |
| Optional teacher support bundle | Avoid or make separately consented | May be optional to disclose only if it meets all Apple optional-disclosure criteria; otherwise disclose relevant categories. |
| User-submitted support email outside app | Keep outside app if possible | Analyze separately; if in-app and retained, may require Customer Support or Other User Content disclosure. |
| iCloud backup controlled by user | Exclude sensitive data by default | Analyze carefully. Do not call it developer collection unless the developer can access the data, but disclose in privacy policy and UX. |
| App Groups / extensions | Avoid for MVP | Ensure sensitive data does not become accessible to unintended extensions or processes. |
| Push notifications | Avoid unless necessary | May involve device tokens and notification metadata; analyze label impact. |
| Web views | Avoid for MVP | Apple says data collected via web traffic must be declared unless the user is navigating the open web. |
| ClassKit | Avoid unless intentionally required | Apple has special restrictions on data gathered from ClassKit and similar APIs. |

---

## 8. Data Categories If Baseline Changes

If future features transmit data off device to the developer or a third-party partner, evaluate these Apple data categories:

| Apple Category | Possible App Examples if Transmitted Off Device |
|---|---|
| Contact Info - Name | Teacher name, student names, parent names. |
| Contact Info - Email Address | Teacher email, student email, support contact email. |
| User Content - Photos or Videos | Scanned pages, photographed assignments, student artwork images. |
| User Content - Other User Content | OCR text, pasted work, rubrics, teacher notes, feedback drafts, comments. |
| Identifiers - User ID | Teacher account ID, district account ID, server account ID. |
| Identifiers - Device ID | Advertising ID, vendor ID, push token, device-level identifier if transmitted. |
| Usage Data - Product Interaction | App events, feature usage, export actions, grading workflow analytics. |
| Diagnostics - Crash Data | Crash logs if transmitted to developer or third-party crash service. |
| Diagnostics - Performance Data | Launch time, hang rate, memory traces if transmitted to developer or service. |
| Sensitive Info | Disability, health, biometric, demographic, or similar information if the app specifically requests or transmits it. Avoid collecting or transmitting this in core workflows. |
| Other Data | Any student-linked or teacher-linked data not captured above. |

---

## 9. Kids Category Recommendation

Do not place the app in the Kids Category if the app is teacher-facing. Apple describes the Kids Category as for apps designed for children and imposes special requirements, including restrictions on links, purchases, third-party analytics, and third-party advertising. Apple also states that apps not in the Kids Category should not use metadata implying that the main audience is children.

Recommended positioning:

- Category: Education.
- Intended audience: Teachers, educators, school staff, and administrators.
- Do not market as: “for kids,” “for children,” “student app,” or “child grading companion.”
- Do not require student sign-in.
- Do not create student-facing accounts in the MVP.

---

## 10. Required In-App Privacy Access Points

Apple requires a privacy policy link in App Store Connect metadata and within the app in an easily accessible manner. The app should include:

- Settings > Privacy.
- Settings > Data Storage.
- Settings > Export and Backup Controls.
- Settings > Delete Local Data.
- A privacy link in onboarding.
- A concise “Local-only design” explanation before first scan/import.

---

## 11. Local-Only Privacy Policy Summary for App Store Metadata

Use concise language in metadata:

> [App Name] is designed for teachers. Student work and grading records are processed locally on device. The core app does not upload student work, use cloud AI grading, use cloud OCR, include third-party analytics, sell data, or track users across apps and websites. Teachers control exports and are warned before files containing student information leave the app.

Avoid overbroad language such as:

> Completely private.

> FERPA compliant.

> No student data is handled.

> Unhackable.

---

## 12. Pre-Submission Verification Checklist

Before submitting to App Review, verify:

- [ ] Network inspection confirms no student data, scans, OCR text, grades, rubrics, or feedback are transmitted.
- [ ] There are no third-party analytics, advertising, tracking, crash-reporting, telemetry, or remote AI SDKs.
- [ ] App Privacy label says “Data Not Collected” only if no data is transmitted off device to developer or third-party partners.
- [ ] Privacy policy explains local storage and export risks even if the privacy label says “Data Not Collected.”
- [ ] App metadata does not imply direct child use or Kids Category positioning.
- [ ] In-app privacy policy is accessible without account creation.
- [ ] Export warnings appear before all file-sharing flows.
- [ ] Student-facing reports exclude teacher-only notes by default.
- [ ] Sensitive local files are protected using appropriate iOS/iPadOS protection mechanisms.
- [ ] App Review notes clearly describe local-only architecture and lack of cloud AI/OCR/analytics.

---

## 13. Source Notes

This template is grounded in the following primary guidance:

1. Apple App Privacy Details, including required privacy responses, the definition of “collect,” optional disclosure, tracking, and on-device processing: https://developer.apple.com/app-store/app-privacy-details/
2. Apple App Store Review Guidelines, including privacy policies, data minimization, data use and sharing, Kids Category restrictions, and app metadata accuracy: https://developer.apple.com/app-store/review/guidelines/
3. U.S. Department of Education FERPA regulations and definitions: https://studentprivacy.ed.gov/ferpa
4. FTC COPPA FAQ, including scope and school/operator questions: https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions
5. Apple Platform Security, Data Protection overview: https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web
6. Apple Platform Security, Keychain data protection: https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web

---

## 14. Drafting Note

This document is a privacy-label preparation template, not legal advice. Final App Store answers should be based on a code-level data-flow review, SDK inventory, network inspection, privacy manifest review, and counsel review before submission.
