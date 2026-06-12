# Repo patch

This folder contains a draft patch for renaming the app from Mark My Work to MarkForMe in the main display-name locations and permission copy.

Do not apply it blindly. Before applying:

1. Clear the name.
2. Confirm the final bundle ID.
3. Confirm the Apple Developer Team.
4. Search the repo for Mark My Work, MarkMyWork and GradeDraft user-facing strings.
5. Rebuild in Xcode.
6. Run tests.
7. Capture new screenshots.

## App icon replacement

The folder `Assets.xcassets/AppIcon.appiconset` contains a replacement `AppIcon-1024.png` and `Contents.json` matching the existing repo app-icon structure. Copy this folder over:

`GradeDraft/Resources/Assets.xcassets/AppIcon.appiconset`

Then open Xcode, clean build and confirm the icon renders correctly on device and in Archive.
