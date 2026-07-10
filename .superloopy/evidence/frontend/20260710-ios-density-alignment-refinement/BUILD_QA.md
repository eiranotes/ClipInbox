# Build and Interaction QA

Date: 2026-07-10

## Native build

Command:

```sh
xcodegen generate --spec project.yml
xcodebuild -project ClipInbox.xcodeproj -scheme ClipInbox -configuration Debug \
  -destination 'platform=iOS Simulator,id=64C7804C-355B-4444-90EE-C8ED0D9355CF' \
  -derivedDataPath /Users/tofu/Library/Developer/Xcode/DerivedData/ClipInbox-Codex-Density build
```

Result: `BUILD SUCCEEDED`. `ClipInboxShare.appex` was embedded, code signed for the simulator, and validated. The only diagnostic was the informational AppIntents metadata skip because the app has no AppIntents dependency.

## Font packaging

- Main `Info.plist` contains `UIAppFonts` entries for `Pretendard-Regular.otf`, `Pretendard-SemiBold.otf`, and `Pretendard-Bold.otf`.
- Share Extension `Info.plist` contains `Pretendard-Regular.otf`.
- Build products contain all registered files and the main bundle contains `LICENSE-Pretendard.txt`.
- Web QA requested `/public/fonts/PretendardVariable.woff2` successfully with HTTP 200.

Official source: `https://github.com/orioncactus/pretendard/releases/tag/v1.3.9`

SHA-256:

```text
2e91915fab54df71cc9598ebf608b2bdb54c6fe3c066ac61dff0bc44fca71cc7  Pretendard-Bold.otf
3ffbacde6ab8411f1d2db54bb9b1f0b3ee2a738932033722cf0388c06aed1c93  Pretendard-Regular.otf
c89bc43027dc7cde5726e96223376f8eec09302b2fc1f8147fd5b57cfc376118  Pretendard-SemiBold.otf
9599f12fd42fc0bce1cd50b47a0c022e108d7aa64dd0d1bb0ed44f3282d900b4  PretendardVariable.woff2
```

## Web regression

- `npm run build`: pass (`ok: true`, 9 files, 20 screens, 13 declared colors).
- First `npm run qa` attempt: environment-only failure because no preview server was running (`ERR_CONNECTION_REFUSED`).
- Re-run with `npm run preview` on `127.0.0.1:4173`: pass at 390, 768, and 1280px with no horizontal overflow and expected 1/2/2 columns.

## Share Extension end-to-end

1. Uninstalled and reinstalled the final simulator build.
2. Opened `https://example.com` in Safari.
3. Opened Share and confirmed Clip Inbox in the system app row.
4. Tapped Clip Inbox once. The share sheet dismissed directly to Safari; no Save/OK form appeared.
5. Confirmed one atomic App Group JSON payload with title `Example Domain`, source `example.com`, URL `https://example.com/`, and folder `인박스`.
6. Launched the containing app. The queue file was consumed and the persisted snapshot contained the imported link, which rendered as the first inbox row.
7. Simulator logs showed normal extension scene teardown and no Share Extension error or crash.

## Interaction checks

- All six inbox filters and all six search categories are exposed as accessibility buttons.
- Every clip row exposes a separate menu target and full-row detail target.
- Tag options increased from six to ten and both rows accepted independent horizontal scroll gestures.
- Direct detail-note editing changed the accessibility value and enabled the Save button.
- Card Menu exposed Bookmark, Share, Move, Edit, and Delete at the default sheet detent.
