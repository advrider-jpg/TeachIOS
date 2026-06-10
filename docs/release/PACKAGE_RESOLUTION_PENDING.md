# Package Resolution Pending

`Package.resolved` was not generated in this Linux implementation environment because Xcode package resolution is unavailable here. Before release or TestFlight, run with Xcode 26 or later on macOS:

```bash
xcodebuild -resolvePackageDependencies -project GradeDraft.xcodeproj -scheme GradeDraft
xcodebuild -project GradeDraft.xcodeproj -scheme GradeDraft -configuration Release -destination 'generic/platform=iOS' build
```

Commit the generated `Package.resolved` file from Xcode after verifying that the resolved package versions match the dependency review. This remains an external release gate, not a source-code defect.
