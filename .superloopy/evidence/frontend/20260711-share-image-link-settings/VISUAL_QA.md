# Visual and Runtime QA

## Scope

- Link-opening setting and confirmation behavior
- Photos image Share ingestion
- Original image storage and full-screen rendering
- Launch/App Group/keyboard diagnostic logs

## Build and Tests

- `xcodebuild ... test` succeeded on iOS 26.5, iPhone 17 Pro simulator.
- 14 XCTest cases passed with 0 failures.
- Embedded `ClipInboxShare.appex` validation passed.
- Regression fixture: PNG, 2400×1800, exact input bytes retained by `SharedImageAsset`.

## Live Share Receipt

Source fixture: `runtime-original-2400x1800.png`

- Format before Share: PNG
- Pixel dimensions before Share: 2400×1800
- Bytes before Share: 1,472,067
- SHA-256 before Share: `21ff962ce36c3187e03afd4d99f9d8a267b9f3a85c969797cbfb375cd9fb44fa`

Stored App Group file: `F940B9DB-054E-4459-BA25-C92AFE5A7A51.png`

- Format after Share: PNG
- Pixel dimensions after Share: 2400×1800
- Bytes after Share: 1,472,067
- SHA-256 after Share: `21ff962ce36c3187e03afd4d99f9d8a267b9f3a85c969797cbfb375cd9fb44fa`
- Pending payload: `type=image`, `url=""`
- Imported clip: `type=image`, `url=""`, same `sharedImageName`
- Queue JSON removed only after app persistence succeeded.

## Interaction Checks

- Settings displayed `링크 열기 방식` with `바로 열기` as the initial/default value.
- `열기 전 확인` persisted and displayed the native `브라우저에서 열까요?` confirmation.
- The simulator preference was restored to `바로 열기` after QA.
- Photos Share returned to Photos after save; the containing app did not auto-launch.
- The imported image opened in detail and in the pinch/double-tap full-screen viewer.
- The first real keyboard tap opened the software keyboard without a synthetic launch-time focus cycle.

## Log Checks

After installing the changed build, launching, saving settings, and opening the keyboard once, a targeted two-minute unified-log query found none of:

- `Using kCFPreferencesAnyUser with a container`
- `Reporter disconnected`
- `Failed to send CA Event`

The CA launch measurement message is system telemetry and is not an app correctness signal; it was not reproduced in the final run.

## Visual Evidence

- `link-opening-default.png`: Settings row after restoring the direct-open default.
- `link-opening-setting.png`: Settings row showing the persisted confirmation choice during QA.
- `fullscreen-original-image.png`: imported original image in the native full-screen viewer.

This is a native iOS target, so browser-only 390/768/1280 viewport checks do not apply. The production target was exercised on the repository's required iPhone 17 Pro simulator.

## Anti-Slop Preflight

- [x] Existing Pretendard typography and warm-neutral palette retained.
- [x] No new gradient, glow, shadow, card system, pill, or accent color.
- [x] Existing row, divider, icon, spacing, selection, and touch-target components reused.
- [x] No placeholder copy or decorative micro-labels added.
- [x] Direct, confirm, disabled-link, Share success, and full-screen states exercised.
- [x] No new magic visual values or orphan colors.

Result: PASS
