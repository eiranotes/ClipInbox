# Clip Inbox Project Instructions

## Implementation Source of Truth

- The production application is the native SwiftUI project under `ios/`.
- Implement product behavior, UI state, persistence, navigation, and CTA changes in `ios/ClipInbox/**/*.swift`.
- Implement incoming iOS share behavior in `ios/ClipShareExtension/**/*.swift` and shared queue contracts in `ios/ClipInbox/Shared/**/*.swift`.
- Treat the root `src/` web application as a historical design prototype only. Do not add or mirror product logic there unless the user explicitly asks for web work.

## Xcode Project Workflow

- Edit `ios/project.yml` for target, resource, entitlement, Info.plist, or build-setting changes.
- Regenerate `ios/ClipInbox.xcodeproj` with `xcodegen generate --spec project.yml` from the `ios/` directory after changing `project.yml` or adding target resources.
- Verify both `ClipInbox` and the embedded `ClipInboxShare` extension with an iOS simulator build.
- Keep DerivedData on the local disk because the repository is on an external volume.

Recommended verification:

```sh
xcodebuild \
  -project ClipInbox.xcodeproj \
  -scheme ClipInbox \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=64C7804C-355B-4444-90EE-C8ED0D9355CF' \
  -derivedDataPath /Users/tofu/Library/Developer/Xcode/DerivedData/ClipInbox-Codex-Density \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build
```
