# Visual QA

Date: 2026-07-10  
Device: Adelie iPhone 17 Pro, iOS 26.5 simulator, 402 x 874 pt  
Method: Installed Debug app inspected through the live Simulator accessibility tree and screenshots.

## Acceptance results

| Area | Result | Evidence |
|---|---|---|
| Inbox density | Pass. The count-only row is gone; the first clip follows the second filter row by the shared 8pt rhythm. Rows expose title, source, optional image, and independent menu only. | `inbox-final.jpeg` |
| Main filters | Pass. Six direct filters are split 3/3 across two natural-width horizontal rows. Labels are not clipped, the right edge remains visible, and active state uses a yellow underline. | `inbox-final.jpeg`, `search-final.jpeg` |
| Root title alignment | Pass. Inbox, Folders, Add, Search, and Settings use the same fixed 44pt header slot. | `inbox-final.jpeg`, `folders-final.jpeg`, `add-final.jpeg`, `search-final.jpeg`, `settings-final.jpeg` |
| Settings cleanup | Pass. The app-icon preview section is absent and the remaining groups keep an even vertical rhythm. | `settings-final.jpeg` |
| Default modal spacing | Pass. Tag Editor, Card Menu, and Share open at the 68% detent with visible content above the primary action and without a large unused full-screen tail. | `tag-editor-final.jpeg`, `card-menu-final.jpeg`, `share-options-final.jpeg` |
| Growing tags | Pass. Ten tag options render across two rows. The first and second rows were scrolled independently; both retain 44pt targets and the 8pt item rhythm. | `tag-row1-scrolled.jpeg`, `tag-two-rows-scrolled.jpeg` |
| Detail | Pass. The image has side breathing room, tags remain detail-only, the note editor is directly settable, and modifying it enables Save. Bottom organization rows do not overlap the tab bar. | `detail-final.jpeg` |
| Share Extension discovery | Pass. Clip Inbox is visible in Safari's system share app row with the generated app icon. | `share-sheet-app-visible.jpeg` |
| Zero-confirm share | Pass. Tapping Clip Inbox returns directly to Safari without presenting a Save/OK form. The next app launch shows the imported `Example Domain` link as the first inbox item. | `share-after-app-tap.jpeg`, `share-imported-final.jpeg` |

## Typography

- Pretendard Regular, SemiBold, and Bold are registered in the main app; Regular is registered in the Share Extension.
- Korean labels use consistent stroke weight without the earlier yellow/black text doubling.
- SF Symbols retain native system metrics; text uses the bundled Pretendard faces.

## Residual boundary

Simulator behavior is proven. Distribution signing and App Group capability still need a physical-device check with the release Apple Developer team.
