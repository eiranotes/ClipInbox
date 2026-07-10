# Changelog

## 0.2.0 - 2026-07-10

### Added

- Local persistence for clips, folders, bookmarks, and settings.
- Real add, title/memo/tag edit, move, delete, folder creation, and Sort Later mutations.
- Clipboard copy, system-share fallback, external URL open, share-card PNG download, JSON export/import, and delete-all flows.
- Validation, empty, completed, disabled, and restore states for the new functional paths.
- Responsive tablet and desktop workbench layouts with two-column clip and folder collections.
- End-to-end browser QA for responsive dimensions, mutations, downloads, delete-all, import restore, and single-item deletion.
- Superloopy target, token, visual QA, and performance evidence under `.superloopy/evidence/frontend/20260710-full-ui-functional-audit`.

### Changed

- Increased interactive chips from 32px to 40px and card quick menus to 44px.
- Expanded the 768px shell to 736px and the 1280px shell to 960px instead of retaining a 430px phone preview.
- Replaced fixed inbox and folder counts with live values.
- Replaced nested clip-card button semantics with a dedicated full-card hit target and independent quick actions.
- Added intrinsic image dimensions, first-image preload/fetch priority, async decoding, and lazy loading for non-primary thumbnails.
- Updated static asset cache-busting paths for reliable visual QA refreshes.

### Fixed

- Edit, move, delete, new-folder, settings, share, export, import, and sort CTAs no longer stop at a placeholder notice.
- Folder detail now shows matching clips and a deliberate empty state.
- Search includes memo content and correctly handles the tag filter.
- Bookmark state belongs to the selected clip instead of one global toggle.
- Korean state messages keep words together instead of breaking polite endings mid-word.
- Static `noop` validation no longer rejects the secure `noopener` window feature.
- Imported and edited values no longer reach `innerHTML` or action attributes without escaping/encoding; unsafe URL schemes and remote image paths are rejected.

### Verified

- `npm run build`, design-system compliance, `git diff --check`, and the expanded `npm run qa` pass.
- Browser QA includes a hostile JSON import regression that proves stored markup stays inert and unsafe link CTAs remain disabled.
- 390/768/1280px evidence shows 1/2/2 columns, 390/736/960px shell widths, minimum 40px interactive controls, and no horizontal overflow.
- Lighthouse medians after import hardening: mobile 99 performance and 100 accessibility/best-practices/SEO; desktop 100 in all four categories.

## 0.1.2 - 2026-07-09

### Changed

- Redesigned the inbox clip card to remove cramped wrapping: the thumbnail now stretches to the text block's full height (no mid-card floating), the title clamps to two lines instead of breaking mid-word, and the source host renders on its own full-width line so URLs like `m.blog.naver.com` and `visitgangneung.net` are no longer truncated.
- Moved the saved time to the card's top row beside the quick menu, which no longer overlaps tall thumbnails.
- Inbox cards now stack directly on the app background instead of inside a bordered board panel, removing the border-in-border look and widening the card text column (139px to 183px on a 375px screen).
- Localized detail-screen section labels to Korean (`노트`, `정리`, `폴더 · 인박스`, `태그 · …`).
- Replaced the placeholder `domain fallback` source string with a realistic host on the no-preview sample clip.

### Fixed

- Bookmark action now toggles on and off and reflects its state on the detail header button; previously it was hardcoded to "added" and the "removed" branch was unreachable.

### Verified

- `npm run build` static validation passes; Playwright QA reports no horizontal overflow at 390/768/1280 and all CTA flows navigate correctly. Card layout re-checked at 360/375/390 widths.

## 0.1.1 - 2026-07-09

### Added

- CTA destination screens for filter, card menu, bookmark, share, more actions, external link confirmation, folder move, clip edit, delete confirmation, save destination, tag editor, new folder, folder detail, and setting detail.
- Browser QA coverage for the new CTA screens.

### Changed

- Reduced tag and badge accent usage to a four-color state set: yellow, blue, green, and danger.
- Restyled rounded tags into quieter neutral chips with small state markers.
- Static validation now rejects `noop` CTA actions and button templates without navigation/action wiring.

## 0.1.0 - 2026-07-09

### Added

- Initial Clip Inbox Trello-token UI prototype.
- `DESIGN.md` token contract covering color, type, spacing, radius, border, motion, and depth.
- Inbox, Share Save, Detail, Folder, Search, Sort Later, Settings, and app icon preview screens.
- Cropped local reference thumbnails for clip cards and preview imagery.
- Browser QA script for screenshots and interaction checks.
- Superloopy visual and performance evidence.
- SVG and ICO favicon matching the app icon direction.
- Project tracking docs.
