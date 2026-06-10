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
Expected: digital text extraction works for the text PDF; OCR fallback creates review-needed state for the image PDF.

## Test 5: Foundation Models
Steps: use an eligible device, enable Apple Intelligence, enable Airplane Mode, and generate a draft.
Expected: draft generation works locally, no cloud fallback appears, and the draft requires teacher review.

## Test 6: export authentication
Steps: trigger teacher audit export, gradebook archive, and full backup; complete local authentication once and cancel it once.
Expected: sensitive export is blocked when authentication fails or is canceled; student report export does not unnecessarily require local authentication.

## Test 7: backup and restore
Steps: create backup archive, import backup, review preview, and test restore-as-copy, keep-local, and replace-local conflict handling.
Expected: preview happens before mutation, restored paths are safe, and conflict strategy is honored.

## Test 8: curriculum catalog
Steps: browse the bundled catalog, search by code/text, filter by learning area/year/kind, map a reference, unmap it, and export teacher audit.
Expected: only teacher-mapped references enter the grading packet; official entries remain read-only; teacher audit includes catalog provenance, source version, warnings, and external source URI.
