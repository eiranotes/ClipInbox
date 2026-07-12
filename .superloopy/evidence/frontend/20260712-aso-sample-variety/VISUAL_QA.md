# Visual QA

## Rendered artifacts

- `contact-sheet-ko-KR.png`
- `contact-sheet-en-US.png`
- `contact-sheet-ja-JP.png`
- `inbox-ko-KR.png`
- `link-detail-ko-KR.png`

This is a native iOS, fixed App Store canvas task. Browser breakpoints do not apply; the relevant rendered targets are the real iPhone 17 Pro simulator capture and the final 1320 x 2868 store canvases.

## Findings

- PASS: The first visible Inbox rows alternate food, city walk, workspace, text memo, and exhibition graphic.
- PASS: The three new photos retain distinct focal colors at contact-sheet scale.
- PASS: The city-walk clip and its detail frame show the same hanok image; no beach image is mislabelled as a city route.
- PASS: The beach appears once per locale, on the lower beach clip only.
- PASS: Korean, English, and Japanese frames preserve the same visual content order and localized copy.
- PASS: Real UI remains upright with status bar, Dynamic Island, and home indicator removed in the composed feature frames.
- PASS: Every upload image is opaque sRGB and 1320 x 2868.

## Anti-slop pre-flight

- [x] No new purple gradient, glow, premium beige-and-brass, or generic card system.
- [x] Existing Pretendard/Hiragino typography and one yellow accent remain locked.
- [x] Real simulator UI and real generated raster imagery are used; no div-based fake screenshot.
- [x] Visible marketing copy was not changed and retains no banned cliché or fake statistic.
- [x] No new decorative micro-tells or generated text inside the photo assets.
- [x] All existing ASO color, type, spacing, radius, and canvas values remain traced to `DESIGN.md`.
- [x] No motion was claimed.
- [x] Native app interactive/empty/loading/error behavior was not changed.

## Review result

PASS. The sample-content refresh materially increases subject and color variety while preserving the approved App Store layout and current SwiftUI product proof. The simulator Debug build succeeded with the embedded Share Extension, and the complete XCTest run passed 59 of 59 tests with no skips or expected failures.
