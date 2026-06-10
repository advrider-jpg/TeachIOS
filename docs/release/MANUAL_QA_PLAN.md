# Manual QA Plan

## Device matrix
- iPhone simulator, iOS 26 or later
- iPad simulator, iOS 26 or later
- Physical iPhone or iPad with camera
- Physical Apple Intelligence-capable device
- Physical device without Apple Intelligence or with Apple Intelligence disabled

## Test 1: first launch
Steps: delete the app, install a fresh build, and launch.
Expected: no crash, local-first status visible, no account/login/network prompt, and local storage backup status visible.

## Test 2: paste text manual review
Steps: create assignment, paste student text, add rubric, start manual final review, approve all criteria, and export student PDF.
Expected: student export is blocked before approval, succeeds after approval, and excludes teacher-only data.

## Test 3: camera scan OCR
Steps: scan paper work, confirm permission prompt copy, review OCR lines, correct/reject one line, and mark document reviewed.
Expected: OCR review blocks grading until reviewed, corrected text is used, and rejected text is excluded from reviewed text but preserved in teacher audit.

## Test 4: PDF import
Steps: import a text PDF and an image-only PDF.
Expected: digital text extraction works for the text PDF; OCR fallback creates review-needed state for the image PDF; original PDF source files remain local and receive best-effort backup-exclusion/file-protection attributes.

## Test 5: Foundation Models
Steps: use an eligible device, enable Apple Intelligence, enable Airplane Mode, and generate a draft.
Expected: draft generation works locally, no cloud fallback appears, and the draft requires teacher review.

## Test 6: export authentication and clipboard
Steps: trigger teacher audit export, gradebook archive, and full backup; complete local authentication once and cancel it once. Then copy a text export to the clipboard.
Expected: sensitive export is blocked when authentication fails or is canceled; student report export does not unnecessarily require local authentication. Clipboard text is copied through an expiring local-only pasteboard item and the audit trail records the action after warning acceptance.

## Test 7: backup and restore
Steps: create backup archive, import backup, review preview, and test restore-as-copy, keep-local, and replace-local conflict handling.
Expected: preview happens before mutation, restored paths are safe, and conflict strategy is honored.

## Test 8: curriculum catalog
Steps: browse the bundled catalog, search by code/text, filter by learning area/year/kind, map a reference, unmap it, and export teacher audit.
Expected: only teacher-mapped references enter the grading packet; official entries remain read-only; teacher audit includes catalog provenance, source version, warnings, and external source URI.

## Test 9: App Intent pasted-work handoff
Steps: create an assignment, run the Add Pasted Student Work Shortcut with non-empty text, return to Mark My Work, and inspect the assignment’s student-work screen.
Expected: the app opens to the selected assignment, saves the pasted work as teacher-reviewed local input, clears stale draft/final-review state, and does not generate a grade or export anything in the background.

## Test 10: Shortcut invalid-target cleanup
Steps: create an Add Pasted Student Work Shortcut for an assignment, delete that assignment in the app, then run the Shortcut.
Expected: the app reports that the assignment is not saved on this device, does not alter any other assignment, and does not leave repeated pending-launch behavior.

## Test 11: clipboard export expiry
Steps: prepare a text-based export, accept the clipboard warning, copy to clipboard, paste immediately into Notes, wait at least five minutes, and try to paste again.
Expected: immediate paste works; the copied item is local-only and expires after the configured window. The app audit trail records that the copy happened after the warning.

## Test 12: original PDF protection and restore handling
Steps: import a PDF, create a teacher archive including original sources, restore the archive as a copy, and export the restored teacher audit.
Expected: the original PDF is preserved in the local source folder with backup exclusion/file protection applied best effort, restore preview occurs before mutation, and restored source paths remain inside the app-controlled source directory.

## Test 13: App Store privacy manifest archive review
Steps: archive the Release build in Xcode 26, open the generated privacy report, and compare it against `docs/release/PRIVACY_REVIEW.md`.
Expected: tracking is false, no tracking domains are present, collected-data types remain empty for the submitted build, required-reason API categories include app-private UserDefaults and app-container file metadata, and any dependency-contributed categories are either justified or resolved before upload.

## Test 14: icon and App Store visual smoke
Steps: install on iPhone and iPad simulators and physical devices, inspect home screen, Spotlight, Settings, and App Library icon placements.
Expected: icons are not blank, stretched, transparent, pixelated, or using the generic placeholder.
