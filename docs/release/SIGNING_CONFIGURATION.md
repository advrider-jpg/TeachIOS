# Signing Configuration

The repository uses release configuration values in `Config/Shared.xcconfig`:

- `GRADEDRAFT_BUNDLE_ID`
- `GRADEDRAFT_TEST_BUNDLE_ID`
- `DEVELOPMENT_TEAM`

`DEVELOPMENT_TEAM` is intentionally not populated in source because it is account-specific. Before TestFlight or App Store submission, set the real Apple Developer Team ID in local release configuration or in Xcode project signing settings, then archive with automatic signing against the production bundle identifier.

Do not commit private keys, provisioning profiles, App Store Connect API private keys, or personal signing assets. Signed archive validation must be performed on a machine with the real Apple Developer Team configuration.

Minimum upload toolchain for the release track: Xcode 26 or later with the iOS/iPadOS 26 SDK or later. Record the exact Xcode build number and archive export method in the release checklist before uploading.
