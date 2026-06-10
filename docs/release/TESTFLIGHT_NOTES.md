# TestFlight Notes

## Internal testing focus
- Confirm first launch, local storage status, and absence of account/login/network prompts.
- Test paste-text grading, Shortcut pasted-work handoff, PDF import, camera OCR, manual final review, and student/teacher exports.
- Test Australian Curriculum search, filters, map/unmap workflow, and teacher audit provenance.
- Test Airplane Mode with local workflows and Foundation Models on an eligible device.
- Confirm ineligible or disabled Apple Intelligence devices show local AI unavailable without cloud fallback.

## Build notes
Source-level release hardening is complete in this patch. TestFlight remains blocked until Xcode package resolution, simulator tests, unsigned Release build, signed archive, App Store Connect app record, live support/privacy URLs, and physical-device smoke tests are completed on macOS with Xcode 26 or later.
