# Changelog

## Unreleased - 2026-07-10

### Added

- Native `ClipInboxShare` Share Extension for Safari, Photos, and text sources, embedded in `ClipInbox.app` with URL, web-page, text, and single-image activation rules.
- App Group file queue (`group.app.clipinbox.ClipInbox`) so the extension can save while the containing app is closed; the app imports queued clips whenever it becomes active.
- Shared-photo persistence and thumbnail rendering, including cleanup when a shared-image clip or all local data is deleted.
- Generated 1024px iOS app icon using the app's warm ivory, yellow, black, white, and soft-blue visual tokens.
- Generated an overlapping-clips fallback thumbnail for referenced images that fail to decode; clips with no image reference remain text-only.
- Direct note editing and persistence from the clip detail screen.
- Official Pretendard v1.3.9 fonts: Regular/SemiBold/Bold OTF faces for the app, Regular for the Share Extension, and a self-hosted variable WOFF2 for the web prototype, with SIL OFL license files.
- `ClipInboxTests` unit-test target with regression coverage for tag/search filtering, persisted recent searches, and primary data mutations across reload.

### Changed

- Designated the native SwiftUI implementation under `ios/` as the production source of truth; the root web prototype is now reference-only unless web work is explicitly requested.
- Reworked the native UI into a productive-minimal, list-first system with one warm canvas, row dividers, compact radii, quieter metadata, and no hard shadows.
- Reduced the native main title, removed the duplicated lower Inbox label, and made the full clip row open detail while preserving the independent quick menu.
- Removed the duplicate inbox filter modal; inbox, search, tag editor, and folder-tag selection now share a two-row selector with five equal-width controls per row and yellow selection underlines.
- Changed menu, move, edit, and picker sheets to a 68% default detent with a large expansion option and 20pt top/bottom content insets.
- Flattened the detail, folder, search-result, Sort Later, settings, and share-action hierarchy; detail media now has deliberate surrounding space and bottom actions stay above the tab bar.
- Removed the count-only inbox header and Settings app-icon preview, and aligned Inbox/Folders/Add/Search/Settings titles to the same fixed header slot.
- Changed Share Extension capture to save immediately after Clip Inbox is selected, without a second Save/OK step.
- Added ten practical default filter/tag options; options beyond the first ten continue horizontally without changing the two-row layout.
- Replaced static recent-search examples with newest-first, deduplicated, five-item local history recorded from submitted searches or opened results.

### Fixed

- Completed the iPad orientation declarations so generic iPhoneOS Xcode validation no longer warns about an unsupported interface orientation.
- Workflow sheets no longer crowd the grabber or leave a mostly empty full-height canvas; the duplicate filter sheet was removed entirely.
- Yellow-button and bookmark/save feedback labels no longer render with duplicated black hard shadows.
- Text-only clips no longer fabricate media placeholders, while broken referenced images receive the generated fallback.
- Detail note changes now save explicitly and on exit, with persisted-data feedback.
- Long tag sets no longer stop at six or clip at the trailing edge; the first ten fill a 5x2 grid and later options continue horizontally.
- Inbox images, text, and quick menus no longer share an overlay layer; media and no-media rows now keep identical content heights in inbox and compact results.
- Search now becomes first responder as the tab opens through default focus plus an 80ms next-runloop handoff.

### Verified

- `xcodebuild` succeeds for the iOS 26.5 simulator and validates the embedded `ClipInboxShare.appex`.
- Safari `example.com` share completed through the extension and appeared as a new link card in the app.
- A Photos image share completed through the extension, persisted a JPEG in the App Group, and rendered as the new inbox card thumbnail.
- Runtime evidence is stored in `.superloopy/evidence/ios/20260710-share-extension`.
- Redesign evidence is stored in `.superloopy/evidence/frontend/20260710-ios-list-first-redesign`.
- Final density, typography, modal, tag-scroll, and zero-confirm Safari share evidence is stored in `.superloopy/evidence/frontend/20260710-ios-density-alignment-refinement`.
- Three native XCTest regressions pass on the iOS 26.5 iPhone 17 Pro simulator, with the embedded `ClipInboxShare.appex` validated during the same build.
- Simulator smoke coverage passed for inbox filters, detail, card menu, share options, folders/new-folder, add/tag editor, search/recent history, Sort Later, and settings. Evidence is stored in `.superloopy/evidence/frontend/20260710-ios-tag-search-audit`.

## 0.3.0 - 2026-07-10 (native iOS)

### Added

- Native SwiftUI iOS app under `ios/` (XcodeGen project, iOS 17+, bundle `app.clipinbox.ClipInbox`) porting the full prototype: inbox with filter chips and clip cards, filter sheet, clip detail, share options (link copy, system share, share-card image), folder move, clip edit with tag editor, delete confirmations, save flow with destination picker and memo, folders with new-folder and folder detail, search with filters and recent chips, Sort Later classification, and settings with option details.
- `DESIGN.md` token contract ported to Swift (`Tokens.swift`) with shared components for badges, chips, box buttons, board sections, action rows, state panels, toasts, and thumbnails.
- Local JSON persistence in Application Support using the web prototype's version-2 backup schema, plus fileExporter/fileImporter backup and restore with the same normalization and 5MB/type/state/URL/image validation rules.
- LocalAuthentication app lock driven by the existing `app-lock` preference, with an automatic fallback when the device has no auth capability.
- Thumbnail assets bundled into the asset catalog from the web prototype's cropped reference images.

### Verified

- `xcodebuild` succeeds for the iOS 26.5 simulator (with local-disk DerivedData and the index store disabled due to external-volume rename semantics).
- The app installs, launches, and renders the app-lock gate and the inbox with live data on an iPhone 17 Pro simulator; a web-format backup JSON seeded into the app container loads through the shared normalization path. Screenshots in `.superloopy/evidence/ios/20260710-swiftui-port`.

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
