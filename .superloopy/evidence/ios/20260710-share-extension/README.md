# iOS Share Extension QA

Date: 2026-07-10  
Simulator: iPhone 17 Pro, iOS 26.5 (`64C7804C-355B-4444-90EE-C8ED0D9355CF`)

## Build and package

- Generated `ClipInbox.xcodeproj` from `ios/project.yml` with XcodeGen.
- Built scheme `ClipInbox` using local-disk DerivedData and `COMPILER_INDEX_STORE_ENABLE=NO`.
- Confirmed the target graph contains `ClipInbox` and `ClipInboxShare`.
- Confirmed `ClipInbox.app/PlugIns/ClipInboxShare.appex` exists and passes Xcode's embedded-binary validation.
- Confirmed the built extension uses `com.apple.share-services` with URL, web-page, text, and image activation rules.
- Confirmed the installed app owns `group.app.clipinbox.ClipInbox` in `simctl listapps`.

## Runtime checks

1. Opened `https://example.com` in simulator Safari.
2. Confirmed `Clip Inbox` appears in the share sheet with the generated app icon.
3. Opened the extension, saved the link, launched the app, and confirmed an `Example Domain` link card was imported while its pending JSON was removed.
4. Added `public/images/clip-beach.png` to simulator Photos.
5. Confirmed `Clip Inbox` appears in the Photos share sheet.
6. Saved through the extension and confirmed the payload references a UUID JPEG in the App Group.
7. Launched the app and confirmed the pending JSON was removed, the new `공유한 이미지` card appeared, and the persisted JPEG rendered as its thumbnail.

## Screenshots

- `photo-share-sheet.png`: Photos share sheet exposing `Clip Inbox`.
- `photo-extension.png`: extension compose UI with localized `저장` action and image preview.
- `imported-photo-inbox.png`: imported image card and thumbnail at the top of the inbox.
