# Build QA

Date: 2026-07-10

## Native iOS

Command:

```sh
xcodegen generate --spec project.yml
xcodebuild -project ClipInbox.xcodeproj -scheme ClipInbox -configuration Debug \
  -destination 'platform=iOS Simulator,id=64C7804C-355B-4444-90EE-C8ED0D9355CF' \
  -derivedDataPath /Users/tofu/Library/Developer/Xcode/DerivedData/ClipInbox-Codex-Redesign \
  COMPILER_INDEX_STORE_ENABLE=NO build
```

Result: `BUILD SUCCEEDED`. `ClipInboxShare.appex` was copied into the app and passed `ValidateEmbeddedBinary`. The only tool warning was skipped AppIntents metadata extraction because the app has no AppIntents dependency.

The final app was installed and launched on simulator `64C7804C-355B-4444-90EE-C8ED0D9355CF`.

## Design-system compliance

Result: pass, 13 declared colors, no violations. See `ds-compliance.json`.

## Web regression

- `npm run build`: pass.
- `npm run qa` after starting `npm run preview`: pass at 390 / 768 / 1280 px.
- The first direct QA invocation was refused because the required local preview server was not running; it was rerun with the documented server and passed.

## Repository checks

- `git diff --check`: pass.
