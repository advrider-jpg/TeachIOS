# Signing Configuration

The repository uses replace-before-release values in `Config/Shared.xcconfig`:

- `GRADEDRAFT_BUNDLE_ID`
- `GRADEDRAFT_TEST_BUNDLE_ID`
- `DEVELOPMENT_TEAM`

Do not commit private keys, provisioning profiles, App Store Connect API private keys, or personal signing assets. Signed archive validation must be performed on a machine with the real Apple Developer Team configuration.
