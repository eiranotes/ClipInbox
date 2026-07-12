# Visual QA — ASO, Icon, Lock Mark, and Inbox Filters

Date: 2026-07-12

## Artifacts

- `aso-final-contact-sheet.png`: ko-KR, en-US, and ja-JP final three-frame sets.
- `app-icon-strong-1024.png`: opaque 1024px app/extension icon master.
- `lock-paperclip-only.png`: actual iPhone 17 Pro Simulator App Lock render.
- `inbox-folder-tag-rows.png`: actual iPhone 17 Pro Simulator Inbox render.

## Checks

- PASS — all nine final ASO files are opaque sRGB PNGs at exactly 1320 x 2868.
- PASS — name, subtitle, promotional text, and keyword budgets pass for all three locales; keyword byte counts are 99, 83, and 87.
- PASS — the app/extension icon is opaque, centered, and visibly heavier and larger than the previous mark.
- PASS — the lock image has alpha, transparent corners, and renders only the paperclip shape on the app canvas with no square tile.
- PASS — Inbox retains five equal-width visible controls per row, with folders above tags and no clipping or overlap at the iPhone 17 Pro size.
- PASS — the paired-row implementation creates one horizontal `ScrollView` per row, so folder and tag offsets are not shared; the standard non-paired selector retains the existing 5x2 grid.
- PASS — no new UI color, spacing, radius, type, or motion literals were added outside the `DESIGN.md` / `Tokens.swift` contract.
- PASS — simulator Debug build includes both `ClipInbox` and embedded `ClipInboxShare`; all 59 tests pass.

## Anti-slop pre-flight

- No purple gradients, generic card wall, decorative dashboard, fake device frame, emoji icon, or unrequested motion.
- One visual hierarchy is preserved: warm canvas, near-black type, yellow selection/brand accent, divider-first lists.
- The icon contains one subject only. The lock mark removes the unrelated square container.
- Localized ASO frames preserve one shared story order without translating layout into inconsistent variants.

Result: PASS
