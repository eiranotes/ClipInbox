# Project Status

## Current State

Clip Inbox's production source of truth is now the native SwiftUI iOS app under `ios/`. The dependency-free web implementation under `src/` is retained as a historical design prototype and is no longer a target for product-logic changes unless web work is explicitly requested. The native app uses a productive-minimal, list-first interface: one warm canvas, hairline-separated rows, quieter metadata, and yellow reserved for selection and primary actions.

Implemented screens:

- Inbox with a two-row, five-column equal-width filter grid, full-row clip navigation, optional thumbnails, and text-only rows that keep the same height as media rows.
- Share Extension that saves immediately after the user taps Clip Inbox in the system share sheet; there is no second Save/OK confirmation.
- Detail view with optional preview, directly editable note, flat organization rows, and actions kept above the bottom navigation.
- Folder list with flat rows and counts.
- Search with immediate field focus, the shared 5x2 category selector, persisted real recent searches, results, and empty state.
- Sort Later classification flow without scores or percentages.
- Settings with app lock, theme, language, default folder, JSON export/import, app info, contact, and delete; the decorative app-icon preview was removed.
- CTA destination screens for card menu, share, more actions, external link confirmation, folder move, clip edit, delete confirmation, save destination, tag editor, new folder, folder detail, and setting detail. Inbox filtering is direct and bookmark is an immediate toggle.
- Native iOS Share Extension exposed in Safari and Photos, with App Group delivery into the app for links, text, and images.

## Completed Work

- Initialized Git repository and renamed the branch to `main`.
- Read the v1.5 spec and local reference image set.
- Started Open Design tools-dev and attempted MCP access.
- Authored `DESIGN.md` as the token contract.
- Cropped real thumbnail assets from the local reference images.
- Built the interactive static prototype source and QA script.
- Captured responsive and state screenshots.
- Ran static validation, design-system compliance, browser QA, and Lighthouse.
- Reworked CTA routing so every button template has an action, navigation target, or detail target.
- Reduced badge/tag accent usage to yellow, blue, green, and danger while keeping neutral chip styling.
- Captured updated responsive and CTA-state screenshots in `.superloopy/evidence/frontend/20260709-cta-token-polish`.
- Re-ran the Open Design refinement (now succeeded) and ported the refined clip-card layout: full-height thumbnail, two-line title clamp, non-truncating source host, top-row time and quick menu, and inbox cards on the app background instead of a bordered board.
- Localized detail-screen section labels to Korean and fixed the bookmark action to toggle on and off.
- Captured a fresh Playwright QA pass and screenshots in `.superloopy/evidence/frontend/20260709-card-redesign` (no horizontal overflow at 390/768/1280).
- Applied the supplied `reference-driven-ui-builder` audit workflow and the Superloopy frontend token/evidence gates.
- Expanded the app shell from a fixed 430px phone preview to a responsive 390px single-column, 736px tablet two-column, and 960px desktop two-column workbench.
- Raised interactive chips to 40px and card menus to 44px while preserving compact static badges.
- Added local persistence and real mutations for add, edit, tag edit, move, bookmark, delete, folder creation, settings, and Sort Later.
- Connected clipboard copy, system-share fallback, external URL open, share-card PNG export, JSON export/import, and delete-all restore testing to browser capabilities.
- Hardened JSON import and editable content against stored markup injection, unsafe URL schemes, external image paths, unsupported clip types/states, and invalid preferences.
- Replaced the nested interactive clip-card structure with a semantic card hit target plus independent menu/tag controls.
- Captured complete evidence in `.superloopy/evidence/frontend/20260710-full-ui-functional-audit`.

- Ported the full prototype to a native SwiftUI iOS app under `ios/` (XcodeGen `project.yml` → `ClipInbox.xcodeproj`, iOS 17+, version 0.3.0): design tokens, all screens (inbox/filter/detail/share/move/edit/delete/save flow/destination/tag editor/folders/new folder/folder detail/search/sort/settings/setting detail), local JSON persistence compatible with the web version-2 backup format, fileExporter/fileImporter backup, UIPasteboard/ShareLink/ImageRenderer share card, and LocalAuthentication app lock.
- Verified the native build on the iOS 26.5 simulator (iPhone 17 Pro): build succeeds, the app launches, the app-lock gate renders, and a web-format backup JSON seeded into the app container loads through the shared normalization path. Evidence in `.superloopy/evidence/ios/20260710-swiftui-port`.
- Added and embedded `ClipInboxShare.appex`, configured concrete URL/text/image activation rules, and connected it to the containing app through `group.app.clipinbox.ClipInbox`.
- Verified Safari link and Photos image saves end to end: the extension is visible with the generated icon, payloads leave the App Group queue after import, and both link metadata and shared image thumbnails render in the inbox. Evidence in `.superloopy/evidence/ios/20260710-share-extension`.
- Applied the supplied `reference-driven-ui-builder` workflow as a structured adaptation and rebuilt the native surface around a quiet editorial/productive-minimal direction.
- Removed nested card/panel treatments from inbox, detail, folders, settings, share actions, and Sort Later; normalized primary/secondary/list CTAs and consolidated workflow-sheet presentation behind one modifier.
- Added direct note editing and persistence in detail, list-wide detail hit targets with an independent quick menu, text-only no-image rendering, and an image-load-failure-only generated fallback asset.
- Verified the redesigned native app on the iOS 26.5 iPhone 17 Pro simulator: clean build, no-image and image detail states, full-row navigation, bookmark/save feedback, and note-edit persistence. Evidence in `.superloopy/evidence/frontend/20260710-ios-list-first-redesign`.
- Removed the duplicate filter modal and count-only list header, moved inbox/search/tag selection to two independently scrollable text rows, aligned all five root headers to the same 44pt slot, removed the Settings icon preview, and set workflow sheets to a compact 68% default with 20pt content insets.
- Bundled official Pretendard v1.3.9 Regular/SemiBold/Bold OTF faces in the app, Regular in the Share Extension, and the official variable WOFF2 in the web prototype; both bundles include the SIL OFL license.
- Changed the Share Extension from a compose controller to one-shot auto-save. Safari `example.com` now follows Share → Clip Inbox → immediate return to Safari, and the containing app imports the queued link without another confirmation.
- Rebuilt and exercised the complete refinement on the iOS 26.5 iPhone 17 Pro simulator. Evidence in `.superloopy/evidence/frontend/20260710-ios-density-alignment-refinement`.
- Declared `ios/` SwiftUI and Share Extension code as the sole production implementation path, documented the XcodeGen/build workflow in the project-level `AGENTS.md`, and retained `src/` as reference-only.
- Regenerated the Xcode project and verified both simulator and unsigned generic iPhoneOS builds; completed the iPad orientation declaration so Xcode validation no longer reports the incomplete-orientation warning.
- Replaced overlay-based inbox card composition with sibling navigation, thumbnail, and menu regions; image and text no longer compete for the same layer, and image/no-image inbox and compact-result rows now use fixed content heights.
- Expanded inbox/search filters and tag suggestions to ten practical defaults rendered as five equal-width controls per row across two rows, with horizontal continuation only beyond ten items.
- Added persisted, deduplicated, five-item recent search history and default/next-runloop focus handoff; verified the caret is active immediately on Search tab entry and the submitted `거실` query survives app restart.
- Added `ClipInboxTests` and passed three XCTest regressions covering tag filtering/search, recent-search persistence, and core mutation reload behavior. Runtime screenshots and CTA smoke evidence are in `.superloopy/evidence/frontend/20260710-ios-tag-search-audit`.

## Next Steps

- Replace the static `time` strings with `Date`-based values and a relative formatter once real capture exists.
- Run the app on a Face ID-enrolled device/simulator session to exercise the interactive unlock path end to end.
- Verify the same App Group capability with the distribution team's signing profile on a physical device before release.

## Known Risks

- The Open Design refinement now succeeds: project `clip-inbox-cta-token-refinement` produced `clip-card.html`, which was ported into the app. The earlier Fable 5 usage-limit failure is resolved.
- The bottom-tab `추가` screen remains a demo/manual-entry flow; real external capture now uses the Share Extension.
- Simulator registration and data transfer are proven. A physical-device build still requires the same Apple Developer team and App Group capability on both the app and extension provisioning profiles.
- On the external volume, `xcodebuild` fails with index-store rename errors unless DerivedData lives on the local disk and `COMPILER_INDEX_STORE_ENABLE=NO` is set (see DECISIONS).
- The headless simulator cannot complete the Face ID prompt, so the interactive unlock path is verified only up to the lock screen and automatic fallback; the settings-driven lock/unlock logic itself is exercised.
- Lighthouse was rerun three times per form factor after import hardening: mobile median 99/100/100/100 and desktop median 100/100/100/100. The remaining mobile performance point is limited by source minification, cache headers, and alternate image encoding in the dependency-free static serving path.
