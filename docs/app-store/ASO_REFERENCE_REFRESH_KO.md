# Korean ASO Reference Refresh

## Direction

The three supplied files under `docs/app-store/aso/` define the marketing grammar: centered Clip Inbox branding, a large two-line benefit statement, one yellow underline, product proof below, and a compact three-point footer. The reference UI itself is not copied because it predates the current native list-first product.

## Current-version sequence

1. `링크, 보자마자 바로 저장`: real Safari Share sheet with the compiled Clip Inbox extension icon behind the current Inbox.
2. `저장만 하고, 정리는 나중에`: current Folder screen.
3. `필요할 때, 바로 다시 찾기`: current Search screen with the `디자인` query.

All product surfaces are fresh captures from the booted iPhone 17 Pro simulator. Status bars, Dynamic Islands, home indicators, fake device hardware, perspective transforms, personal data, prices, endorsements, and generated UI are excluded from the final marketing composition.

## Brand mark

Built-in ImageGen generated one original yellow paperclip mark from the supplied references. The prompt required a single continuous clip silhouette, warm-ivory opaque background, strong 32px readability, and no text, tray, cards, device, UI, border, gradient, glow, purple, blue, or baked app-icon mask.

The same 1024px no-alpha source is used for:

- `ios/ClipInbox/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- `ios/ClipInbox/Assets.xcassets/lock-clip.imageset/lock-clip.png`
- `ios/ClipShareExtension/Assets.xcassets/ShareExtensionIcon.appiconset/ShareExtensionIcon-1024.png`

## Outputs

- Upload files: `docs/app-store/generated/aso-reference-refresh-v1/upload/ko-KR/`
- Contact sheet: `docs/app-store/generated/aso-reference-refresh-v1/contact-sheet-ko-KR.png`
- ImageGen source and simulator proofs: `docs/app-store/generated/icon-reference-refresh/`
- Reproduction: `./scripts/generate_aso_reference_refresh.sh`

Every upload file is 1320 x 2868 RGB PNG without alpha. Exact Korean copy is composited with bundled Pretendard.
