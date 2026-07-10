# Visual QA

## Target

- App: native SwiftUI `ClipInbox`
- Device: iPhone 17 Pro simulator, iOS 26.5
- Capture resolution: 1206x2622 pixels at 3x scale
- Design mode: productive minimal application

## Evidence

- `inbox-grid-card.png`: inbox 5x2 filters plus image and no-image clip rows.
- `search-focused-recent.png`: search 5x2 filters, active first-responder caret, and persisted `거실` recent search.

## Acceptance checks

- Pass: Inbox exposes exactly ten filters, five equal-width controls per row across two rows.
- Pass: Search exposes exactly ten filters with the same 5x2 geometry and equal widths.
- Pass: Practical defaults include `인테리어`, `레퍼런스`, `아이디어`, and `여행`; tag editor and new-folder flows expose ten suggestions.
- Pass: Clip navigation, thumbnail, and menu are sibling layout regions. Images do not overlap title, source, or the 44pt menu target.
- Pass: Image and no-image inbox rows share the same fixed 68pt content height; compact results share 48pt.
- Pass: Selecting Search shows the insertion caret without another field tap. The simulator has a connected hardware keyboard, so the software keyboard panel is hidden while first-responder focus remains active.
- Pass: Submitting `거실` creates a real recent-search row; terminating and relaunching the app preserves it.
- Pass: Inbox and Search `인테리어` filters each reduce results to the matching clip.
- Pass: No clipping or horizontal overflow is visible at the target device width.

## Functional smoke

Opened and dismissed the following live paths: inbox filter, clip detail, card menu, share options, folders, new-folder sheet, add flow, tag editor, search and recent history, Sort Later, and settings. Destructive deletion, external-link launch, and system-share submission were intentionally not executed during this non-destructive smoke pass.

## Anti-slop pre-flight

- Pass: no purple/glow, beige/brass, glass, shadow, pill, or extra-card defaults were introduced.
- Pass: one color, shape, type, and surface system remains in use.
- Pass: all new sizes, spacing, counts, focus timing, and scale values trace to `DESIGN.md` and `Tokens.swift`.
- Pass: interactive, selected, empty recent-search, result, and no-media states were exercised.
- Pass: copy contains no generic marketing language or decorative micro-tells.
