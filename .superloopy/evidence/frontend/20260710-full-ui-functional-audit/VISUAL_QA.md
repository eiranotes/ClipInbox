# Visual QA

Status: PASS

Reference boundary: structured adaptation. The seven local reference images define screen hierarchy and mobile rhythm; the live v1.5 spec, `DESIGN.md`, and working source define tokens and behavior.

## Responsive evidence

| Viewport | Shell | Layout | Minimum interactive control | Horizontal overflow | Artifact |
|---|---:|---|---:|---|---|
| 390 x 844 | 390px | 1 column | 40px | No | `mobile-390.png` |
| 768 x 1024 | 736px | 2 columns | 40px | No | `tablet-768.png` |
| 1280 x 900 | 960px | 2 columns | 40px | No | `desktop-1280.png` |

The 44px icon and card-menu targets were measured separately in the browser. The 40px minimum belongs to filter and tag chips, which exceeds the prior 32px implementation and matches the token contract.

## Interaction and state evidence

- Add inserts a real clip, persists it locally, updates the count from 5 to 6, disables the completed CTA, and shows `state-add-saved.png`.
- Bookmark persists on the selected clip and shows `state-bookmark.png`.
- Clipboard copy writes the stored URL; system share has a clipboard fallback.
- Image-card export downloads `exported-share-card.png` using the selected real thumbnail.
- External open passes the stored URL to a new tab request.
- Move updates the folder shown in detail.
- Edit updates title, memo, and tags; see `state-edited-detail.png`.
- Folder creation uses the entered name and produces a specific empty state; see `state-folder-created.png`.
- Settings choices persist and update their row values.
- JSON export, delete-all, and JSON import restore the exported six-clip snapshot.
- Hostile JSON import is normalized and escaped: unsupported types/states, unsafe URL schemes, remote image paths, and markup payloads do not become executable DOM.
- Sort Later commits both unsorted clips and reaches the completed state. The accepted artifact is `state-sort-complete-real-browser.png`, recaptured from the in-app browser after computed-style verification when the first automated screenshot was visually corrupted.
- Single delete removes the clip and returns the total to 5; see `state-delete-complete.png`.
- Search error-free empty state is captured in `state-search-empty.png`.

## Visual review

- Mobile: title, utility actions, cards, media, host, chips, and bottom navigation remain readable at 390px.
- Tablet: five cards occupy two 344px columns without compressing card titles or media.
- Desktop: the shell expands from the previous 430px phone preview to a 960px workbench with two 456px columns.
- Korean state copy uses `word-break: keep-all` to avoid breaking polite endings mid-word.
- Focus rings are visible on navigation, card hit areas, menus, chips, rows, inputs, textareas, and file selection.
- Empty, validation error, success, disabled, selected, destructive, and completion states use distinct token-backed treatments.

## Anti-slop pre-flight

- [x] Zero em dash and en dash characters in visible source.
- [x] No eyebrow overuse; app screen headings are functional labels.
- [x] No purple gradient or glow.
- [x] Deliberate Apple system stack retained because the product is an iOS utility.
- [x] No beige-and-brass premium palette; yellow is the existing utility action token.
- [x] Color, shape, and theme locks hold across screens.
- [x] App layout families include card stack, board form, detail article, folder rows, compact search results, settings groups, and sequential classification.
- [x] Real local thumbnails are used; no div-based fake screenshot.
- [x] Visible copy contains no banned AI clichés, placeholder names, or fake-perfect product statistics.
- [x] No decorative status dots, fake version hero, rotated text, or other micro-tells.
- [x] Motion is implemented with transform/opacity behavior and reduced-motion handling.
- [x] Design-system compliance passes with no undeclared color or spacing violations.
- [x] Interactive, empty, error, disabled, selected, loading, destructive, and completion states are handled where applicable.
- [x] User-edited and imported text is escaped; dynamic action values are encoded.
- [x] No horizontal scroll at 390, 768, or 1280px.

SUPERLOOPY_EVIDENCE: `.superloopy/evidence/frontend/20260710-full-ui-functional-audit/VISUAL_QA.md`
