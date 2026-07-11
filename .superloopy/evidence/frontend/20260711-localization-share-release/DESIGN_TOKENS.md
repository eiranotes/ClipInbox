# Design Token Trace

## Scope

Native SwiftUI app and `ClipInboxShare` extension only. The root web prototype was not modified.

## Applied tokens

- App canvas: `#F3EFE7`; focused cards: white; primary text: `#171714`.
- Primary action: `#FFD900`; saved state: `#9BE7B0`; soft border: `#D8D1C4`.
- Screen inset: 16pt; compact control rhythm: 8/12pt; section rhythm: 24pt.
- Minimum interactive target: 44pt; primary action height: 52pt.
- Quick-share status host: 132pt; review-share form: 390pt.
- Card/button radius: 10pt; input radius: 8pt; no hard shadows or gradients.
- Pretendard remains the bundled text face; SF Symbols remain native icons.

## Readability decisions

- Language and share-mode settings use the existing full-width destination row, so labels and values share one alignment axis.
- English and Japanese strings are allowed to wrap in descriptions; controls retain the same minimum target size.
- Quick save contains one centered status card and no second confirmation action.
- Review save contains one title, title preview, folder menu, memo editor, primary save button, and cancel button. No duplicated panel nesting was introduced.

