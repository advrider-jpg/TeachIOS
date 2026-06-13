# MarkForMe Release Integration

## Integrated package

The complete release package from `C:\Users\jackg\Downloads\markforme_release_package (1).zip` has been copied into:

`docs/release/markforme_release_package/`

The support-site folder is also exposed at:

`docs/release/support_site/`

## Promoted release docs

- `docs/release/APP_STORE_METADATA.md`
- `docs/release/APP_REVIEW_NOTES.md`
- `docs/release/TESTFLIGHT_NOTES.md`
- `docs/release/PRIVACY_POLICY.md`
- `docs/release/SUPPORT_PAGE_COPY.md`
- `docs/release/SCHOOL_ONE_PAGER.md`
- `docs/release/SCREENSHOT_COPY_PLAN.md`
- `docs/release/RELEASE_BLOCKERS.md`
- `docs/release/RELEASE_STATUS.md`

## App changes

- Public app name updated to MarkForMe.
- Display name and permission copy updated in `GradeDraft/Resources/Info.plist`.
- Release bundle ID setting updated to `com.markforme.app`; Apple signing remains manual.
- Primary app icon replaced from the package with the MarkForMe 1024 x 1024 icon.

## Brand and screenshots

Brand assets live under:

`docs/release/markforme_release_package/02_brand/`

Screenshot templates live under:

`docs/release/markforme_release_package/03_screenshots/`

Templates are not final App Store screenshots. Capture real app screenshots before submission.

## Validation limits

This Windows checkout can run static Python checks and JSON/plist validation. Xcode build, archive, simulator, TestFlight upload, App Store Connect fields, physical-device camera/import/export tests and Foundation Models runtime checks must be completed on Apple tooling.
