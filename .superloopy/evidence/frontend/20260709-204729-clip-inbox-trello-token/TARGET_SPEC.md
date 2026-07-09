# Visual Target Spec

## Reference Analysis

The seven local reference images show a Korean iOS-style clipping app with these recurring traits:

- Warm ivory app background and generous vertical rhythm.
- Large, heavy Korean screen titles.
- White rounded cards and panels with soft spacing.
- Yellow selected chips, buttons, and active tab icons.
- Compact utility buttons in the top right of inbox-like screens.
- Bottom navigation with Inbox, Folder, Add, Search, and Settings.
- Real content thumbnails for links/images and clear fallback rows for utility settings.

## v1.5 Correction Applied

The written spec overrides the softer screenshots where needed:

- Cards, panels, buttons, and chips use strong black outlines.
- Trello-like modular board cards replace generic iOS list rows.
- Yellow is limited to selected controls and primary actions.
- No sports dashboard, ranking, prediction, social, or gamified elements.
- Suggested folders appear as chips/buttons without scores or percentages.

## Implemented Surface Target

The prototype must include:

- Inbox screen with filters, utility controls, clip cards, thumbnails, and fallback card.
- Share extension save screen with preview-loading fast path and save toast.
- Detail/edit screen with preview, note, organization, and actions.
- Folder screen with card-like rows and counts.
- Search screen with query, filters, recent searches, results, and empty state.
- Sort Later screen with one-card classification flow.
- Settings screen with lock, default folder, JSON import/export, delete, and icon preview.
- App icon preview using cream background, black tray/card outline, and one yellow clipped card.

## Anti-Slop Locks

- Zero visible em-dashes.
- System font is intentional because the product is iOS-first.
- No purple glow, glass panels, bento filler, fake rankings, fake percentages, or decorative status dots.
- Real cropped image assets are used for clip thumbnails.
- All colors and spacing values trace to `DESIGN.md`.
