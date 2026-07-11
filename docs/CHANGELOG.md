# Changelog

## Unreleased - 2026-07-11

### Internal

- Added the product-bounded A-to-Z audit adoption plan and moved native regression setup toward explicit version-2 fixtures so production sample removal can proceed safely.
- Added a `ClipRepository` boundary with typed bootstrap/commit failures, current/previous snapshot rotation, corrupt-file quarantine, version gating, and transaction rollback tests.
- Added a deterministic provider deadline primitive plus queue, image-limit, manual-capture, idempotency, and fail-closed lock regressions.

### Added

- Real manual Link, Text, Photo, and Memo capture in the Add tab, including PhotosPicker, canonical URL validation, exact-link duplicate disclosure, and durable folder/tag save.
- App-switcher privacy cover and App Lock capability gating that keeps content locked when device authentication is unavailable or fails.
- Settings choice for opening links immediately or asking before opening the browser, with immediate opening as the default.
- Adaptive light, dark, and system appearance with a warm near-black dark palette shared by the app and Share Extension configuration.
- Settings tag management for adding, renaming, and deleting tags; rename/delete updates every clip tag and folder default-tag reference and persists the catalog separately from the version-2 backup schema.
- Aspect-fit detail previews plus a tappable full-screen image viewer with pinch and double-tap zoom.
- Leading-edge swipe-back gestures for pushed detail, folder, and setting screens.
- Korean, English, and Japanese runtime localization for the production app and Share Extension, including accessibility labels, default samples, toasts/errors, and localized Face ID purpose text.
- Settings control for immediate Share save versus folder-and-memo review, synchronized to the extension through App Group preferences.
- Privacy manifests for the app and Share Extension, plus localized ASO copy, screenshot storyboard, release checklist, and a trilingual privacy-policy draft.
- Direct tag editing from the clip-detail organize row: the tag row opens the tag editor immediately and saves cleaned, deduplicated tags with a no-op guard, covered by a new `updateTags` XCTest regression.
- Share Extension now shows a compact green "Clip Inbox에 저장됨" confirmation card with a checkmark for about 2 seconds after the zero-confirm save, instead of disappearing without feedback.
- Korean "로/으로" particles in dynamic folder labels (move sheet, move toast, Sort Later CTA) now follow the final consonant — "디자인으로 분류하고 다음", "인박스로 이동" — via a tested `withRoParticle` helper.
- Native `ClipInboxShare` Share Extension for Safari, Photos, and text sources, embedded in `ClipInbox.app` with URL, web-page, text, and single-image activation rules.
- App Group file queue (`group.app.clipinbox.ClipInbox`) so the extension can save while the containing app is closed; the app imports queued clips whenever it becomes active.
- Shared-photo persistence and thumbnail rendering, including cleanup when a shared-image clip or all local data is deleted.
- Generated 1024px iOS app icon using the app's warm ivory, yellow, black, white, and soft-blue visual tokens.
- Generated an overlapping-clips fallback thumbnail for referenced images that fail to decode; clips with no image reference remain text-only.
- Direct note editing and persistence from the clip detail screen.
- Official Pretendard v1.3.9 fonts: Regular/SemiBold/Bold OTF faces for the app, Regular for the Share Extension, and a self-hosted variable WOFF2 for the web prototype, with SIL OFL license files.
- `ClipInboxTests` unit-test target with regression coverage for tag/search filtering, persisted recent searches, and primary data mutations across reload.

### Changed

- Share image loading now prefers a temporary file representation, validates metadata without decoding full pixels, and enforces 50 MB/100 MP limits while preserving accepted original bytes.
- Share provider requests now time out and cancel after 10 seconds; quick-save confirmation returns after 650 ms instead of a fixed 2 seconds.
- Pending Share items now sort by capture time, quarantine corrupt/expired files, enforce 200-item/250-MB/30-day limits, and persist their UUID into imported clips for idempotency.
- Fresh installs now open an empty clip library. Unrecoverable and future-version snapshots show a blocking recovery/update state instead of silently loading sample clips.
- Image shares now take priority over accompanying file/web URLs and retain the provider's original supported image bytes, format, and pixel dimensions instead of a 1600px JPEG conversion.
- Share Extension configuration now uses an atomic App Group JSON file, with a direct legacy-plist migration path.
- The bottom navigation now hides instead of moving above the keyboard. Every non-tag-selection input screen dismisses the keyboard when the user taps outside a text input.
- Workflow sheets now use content-aware detents: 58% for short actions, 76% for medium selectors, and full height for destination/move/edit flows, all with explicit top and bottom insets.
- Setting-detail screens no longer show the duplicated "설정 설명" block. Short option/action screens use deliberate top spacing, while the longer default-folder and tag lists begin near the header.
- Fresh/reset folder defaults are now `전체`, `기본 폴더`, and rename-oriented `폴더 1` through `폴더 5` in that order.
- Fresh-install defaults are now App Lock off and immediate Share save on.
- Quick Share capture now shows only one compact localized success card for about 2 seconds; review capture uses a focused folder/memo form.
- Keyboard policy: the keyboard now opens only from a direct tap on the search field or a text editor. Search-tab entry and the new-folder/rename sheets no longer request focus programmatically, tapping outside the search field or switching bottom tabs dismisses the keyboard, and the keyboard process is prewarmed once at launch so the first tap presents it without cold-start delay.
- Expanded the detail content rhythm to a 16pt stack (badges, title, source, media, description) and added line spacing to multi-line titles, body text, editors, and meta descriptions across detail, edit, add, sort, settings, and state/empty panels.
- Unified folder and settings destination rows behind one divider rule — a hairline inset to the icon column with no divider after the last row — keeping both screens' icons on an identical vertical axis (measured center x 126px on the 3x simulator).
- Compressed the detail screen so the whole read flow through the 링크 열기 action fits one viewport without scrolling: preview images are 140pt, the note editor opens at a 72pt minimum, and the 16pt content rhythm is preserved instead of oversized media.
- Selectable action rows (Sort Later categories, option lists, folder pickers) now accept taps across the entire row, not only on the label or icon.
- Designated the native SwiftUI implementation under `ios/` as the production source of truth; the root web prototype is now reference-only unless web work is explicitly requested.
- Reworked the native UI into a productive-minimal, list-first system with one warm canvas, row dividers, compact radii, quieter metadata, and no hard shadows.
- Reduced the native main title, removed the duplicated lower Inbox label, and made the full clip row open detail while preserving the independent quick menu.
- Removed the duplicate inbox filter modal; inbox, search, tag editor, and folder-tag selection now share a two-row selector with five equal-width controls per row and yellow selection underlines.
- Changed menu, move, edit, and picker sheets from one 68% default to compact/standard/expanded detents with 20pt top/bottom content insets.
- Flattened the detail, folder, search-result, Sort Later, settings, and share-action hierarchy; detail media now has deliberate surrounding space and bottom actions stay above the tab bar.
- Removed the count-only inbox header and Settings app-icon preview, and aligned Inbox/Folders/Add/Search/Settings titles to the same fixed header slot.
- Changed Share Extension capture to save immediately after Clip Inbox is selected, without a second Save/OK step.
- Added ten practical default filter/tag options; options beyond the first ten continue horizontally without changing the two-row layout.
- Replaced static recent-search examples with newest-first, deduplicated, five-item local history recorded from submitted searches or opened results.

### Fixed

- App Lock no longer unlocks content when LocalAuthentication cannot evaluate the device-owner policy.
- Retried queue removal can no longer import the same shared payload twice.
- The Add tab no longer creates a hardcoded brunch sample.
- Main-data mutations no longer report success after a failed disk write; in-memory clips, folders, preferences, and tag state roll back together.
- JSON import now rejects unsupported snapshot versions before mutation and rolls back if the durable commit fails.
- Photos/image shares no longer become URL-only link clips when the provider exposes both representations, and full-screen zoom now reads the original stored raster.
- Removed the synthetic launch-time keyboard prewarm responsible for private text-input reporter disconnect messages; the keyboard remains tap-only.
- Detail images no longer crop their source ratio, and folder-move plus other long modals no longer appear cut at the top or bottom.
- Keyboard presentation no longer lifts and animates the five-item bottom menu above the keyboard.
- Completed the iPad orientation declarations so generic iPhoneOS Xcode validation no longer warns about an unsupported interface orientation.
- Workflow sheets no longer crowd the grabber or leave a mostly empty full-height canvas; the duplicate filter sheet was removed entirely.
- Yellow-button and bookmark/save feedback labels no longer render with duplicated black hard shadows.
- Text-only clips no longer fabricate media placeholders, while broken referenced images receive the generated fallback.
- Detail note changes now save explicitly and on exit, with persisted-data feedback.
- Long tag sets no longer stop at six or clip at the trailing edge; the first ten fill a 5x2 grid and later options continue horizontally.
- Inbox images, text, and quick menus no longer share an overlay layer; media and no-media rows now keep identical content heights in inbox and compact results.
- The `containerToPush is nil` keyboard warning no longer appears: it was raised by programmatic focus requests racing view attachment, and keyboard focus now comes only from user taps (confirmed with a full simulator log capture during keyboard interaction).
- Shared-image thumbnails no longer re-read their file from disk on every row render; decoded images are memoized in an in-memory `NSCache`.
- Fill-mode thumbnails no longer overflow their frame: `aspectRatio(.fill)` reported an oversized layout that covered the detail source row and crowded titles under Sort Later photos; images are now composited as an overlay on a proposal-sized surface and clipped at the real boundary.

### Verified

- Twenty-eight native XCTest regressions pass, including provider timeout/cancellation, queue order/quarantine/quota/idempotency, file-backed image byte preservation and size rejection, real manual capture, and fail-closed authentication. The embedded Share Extension validates in the same build.
- Simulator interaction verified labelled Add type/field/actions, a durable manual URL save, Photo capture policy state, and an opaque Clip Inbox app-switcher card. Evidence is stored in `.superloopy/evidence/frontend/20260711-audit-phase2`.
- Twenty native XCTest regressions pass, including corrupt-current recovery from the previous snapshot, quarantine preservation, unsupported-version blocking, empty first run, and mutation/import rollback on forced write failures. The same simulator build validates the embedded `ClipInboxShare.appex`.
- Fourteen native XCTest regressions pass, including exact-byte/format/dimension preservation for a 2400×1800 PNG and link-opening preference persistence.
- A live Photos share retained PNG, 2400×1800 pixels, 1,472,067 bytes, and SHA-256 `21ff962ce36c3187e03afd4d99f9d8a267b9f3a85c969797cbfb375cd9fb44fa` before and after App Group storage; the payload and imported clip were both image type with no URL.
- Settings direct/confirm selection, the confirmation dialog, host-app return after sharing, first keyboard presentation, and full-screen image rendering were exercised on the iOS 26.5 iPhone 17 Pro simulator. Targeted logs contained none of the reported App Group or reporter-disconnect strings after the change.
- Twelve native XCTest regressions pass, including tag-catalog rename/delete propagation, generic folder ordering, and dark-theme persistence.
- Light inbox, dark settings/folders/tag management, aspect-fit/full-screen image, expanded card/move sheets, outside-tap keyboard dismissal, and hidden keyboard navigation were exercised on the iOS 26.5 iPhone 17 Pro simulator. Evidence is stored in `.superloopy/evidence/frontend/20260711-ux-theme-tags`.
- Ten native XCTest regressions pass, including default lock/share behavior and Japanese/review preference persistence.
- Korean, English, and Japanese were switched live on the iPhone 17 Pro simulator; Safari quick and review Share paths both completed, and the review payload appeared in the inbox. Evidence is stored in `.superloopy/evidence/frontend/20260711-localization-share-release`.
- `xcodebuild` succeeds for the iOS 26.5 simulator and validates the embedded `ClipInboxShare.appex`.
- Safari `example.com` share completed through the extension and appeared as a new link card in the app.
- A Photos image share completed through the extension, persisted a JPEG in the App Group, and rendered as the new inbox card thumbnail.
- Runtime evidence is stored in `.superloopy/evidence/ios/20260710-share-extension`.
- Redesign evidence is stored in `.superloopy/evidence/frontend/20260710-ios-list-first-redesign`.
- Final density, typography, modal, tag-scroll, and zero-confirm Safari share evidence is stored in `.superloopy/evidence/frontend/20260710-ios-density-alignment-refinement`.
- Three native XCTest regressions pass on the iOS 26.5 iPhone 17 Pro simulator, with the embedded `ClipInboxShare.appex` validated during the same build.
- Simulator smoke coverage passed for inbox filters, detail, card menu, share options, folders/new-folder, add/tag editor, search/recent history, Sort Later, and settings. Evidence is stored in `.superloopy/evidence/frontend/20260710-ios-tag-search-audit`.
- Keyboard policy, detail-spacing, tag-edit, and folder/settings alignment changes were exercised live on the iOS 26.5 iPhone 17 Pro simulator (seven XCTest regressions passing, `containerToPush` absent from captured logs, icon centers pixel-matched). Evidence is stored in `.superloopy/evidence/frontend/20260711-keyboard-lock-folder`.

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
