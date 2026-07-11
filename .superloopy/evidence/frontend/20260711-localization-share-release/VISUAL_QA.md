# Visual QA

## Environment

- iPhone 17 Pro simulator, iOS 26.5, portrait 1206 x 2622 capture.
- Production SwiftUI app plus the embedded Share Extension.
- Real Safari share-sheet flow was used for both share modes.

## Passed checks

- Korean, English, and Japanese switch immediately without relaunching.
- Root tabs, filters, default sample content, setting labels, setting values, toasts, and Share Extension copy follow the selected language.
- English Settings shows `App lock, Off` and `Share save behavior, Save immediately`.
- Korean and Japanese inbox screens preserve the same header, selector, row, divider, and bottom-navigation rhythm.
- Japanese review mode presents a compact folder/memo workflow with a visible primary action and no clipped copy.
- English quick mode presents one green `Saved to Clip Inbox` status card and automatically returns to Safari.
- A review-mode Safari save was imported into the inbox; the live item count changed from 5 to 6 and `Example Domain` appeared.
- No gradient, excessive radius, hard shadow, decorative hero, or duplicate card shell was added.
- All inspected interactive controls retain at least a 44pt target.

## Evidence

- `screenshots/ko-inbox.png`
- `screenshots/en-inbox.png`
- `screenshots/en-settings.png`
- `screenshots/ja-inbox.png`
- `screenshots/ja-share-review.png`
- `screenshots/en-share-quick.png`
- `quick-share-flow.mov`

## Platform constraint

The outer Share Extension sheet and its height are owned by iOS. The extension opts out of full-screen presentation, supplies compact preferred sizes, and paints only the small status card or review form inside the system-owned sheet.

