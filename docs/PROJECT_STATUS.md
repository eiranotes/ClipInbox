# Project Status

## Current State

Clip Inbox's production source of truth is now the native SwiftUI iOS app under `ios/`. The dependency-free web implementation under `src/` is retained as a historical design prototype and is no longer a target for product-logic changes unless web work is explicitly requested. The native app uses a productive-minimal, list-first interface: one warm canvas, hairline-separated rows, quieter metadata, and yellow reserved for selection and primary actions.

Implemented screens:

- Inbox with a two-row, five-column equal-width filter grid, full-row clip navigation, optional thumbnails, and text-only rows that keep the same height as media rows.
- Share Extension with two user-selectable behaviors: immediate save shows one compact localized checkmark card for about 2 seconds before returning, while review mode exposes only folder, memo, save, and cancel controls.
- Detail view with a 16pt content rhythm that fits one viewport through the 링크 열기 action (140pt aspect-fit preview, 72pt note editor), a zoomable full-screen image viewer, directly editable note and tags, flat organization rows, and actions kept above the bottom navigation.
- Folder list with flat rows and counts, using `전체`, second-row `기본 폴더`, and rename-oriented `폴더 1` through `폴더 5` on fresh/reset data.
- Search with the shared 5x2 category selector, persisted real recent searches, results, and empty state. The keyboard opens only from a direct field tap and dismisses on outside taps or tab switches; synthetic launch-time prewarming was removed after runtime log diagnosis.
- Sort Later classification flow without scores or percentages.
- Settings with app lock, functional light/dark/system theme, Korean/English/Japanese language selection, default folder, global tag management, Share save behavior, direct/confirm link opening, JSON export/import, app info, contact, and delete. Link opening defaults to direct. Detail screens omit the redundant explanation panel and use content-aware vertical spacing.
- CTA destination screens for card menu, share, more actions, external link confirmation, folder move, clip edit, delete confirmation, save destination, tag editor, new folder, folder detail, and setting detail. Inbox filtering is direct and bookmark is an immediate toggle.
- Native iOS Share Extension exposed in Safari and Photos, with App Group delivery into the app for links, text, and images.

## Completed Work

- Completed audit Phase 1 with a small file-repository boundary, typed bootstrap/commit errors, version-2 gating, atomic current/previous snapshots, corrupt-file quarantine, previous-snapshot recovery, and rollback-backed mutations. Fresh installs now start with an empty clip library; unrecoverable and future-version libraries show a blocking recovery/update state instead of sample data.
- Locked the A-to-Z audit adoption boundary in `docs/AUDIT_ADOPTION_PLAN.md` and moved data-dependent XCTest setup to explicit version-2 fixtures without changing production behavior.
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
- Reworked the keyboard policy (tap-only focus, launch prewarm, outside-tap and tab-switch dismissal), which also removed the `containerToPush is nil` warning; added direct tag editing from detail with an `updateTags` mutation; unified folder/settings destination rows behind `DestinationRow` + `RowDivider` with pixel-matched icon axes; and added line-spacing tokens for multi-line text.
- Compressed detail to a one-viewport read flow (140pt preview, 72pt note editor), fixed fill-mode thumbnail overflow via overlay-and-clip composition, cached shared-image decoding in `NSCache`, added the Share Extension saved-confirmation card, made action rows fully tappable, and corrected Korean 로/으로 particles with a tested helper. Eight XCTest regressions pass; evidence in `.superloopy/evidence/frontend/20260711-keyboard-lock-folder`.
- Added bundle-backed Korean, English, and Japanese localization across the production app and Share Extension; language changes take effect immediately and include default samples, accessibility labels, errors, toasts, and Face ID purpose text.
- Added App Group-backed immediate/review Share modes. Safari review-save imported `Example Domain` and raised the live inbox count from 5 to 6; quick-save displayed only the compact English success card and auto-returned. Evidence in `.superloopy/evidence/frontend/20260711-localization-share-release`.
- Added privacy manifests for both executables and prepared localized ASO copy, screenshot storyboard, release checklist, and a trilingual privacy-policy draft under `docs/app-store/`.
- Added a persisted tag catalog with global add/rename/delete actions, reference propagation across clip tags and folder defaults, and XCTest coverage while retaining version-2 JSON backup compatibility.
- Added adaptive dark tokens, working light/dark/system selection, content-aware workflow-sheet detents, aspect-fit/zoomable detail media, leading-edge swipe back, and a compact checkmark Share confirmation.
- Reworked keyboard behavior so non-input taps dismiss it across input screens, the tag-selection sheet remains unchanged, and the bottom navigation hides rather than moving above the keyboard. Runtime evidence is in `.superloopy/evidence/frontend/20260711-ux-theme-tags`.
- Fixed image Share ingestion so an image-plus-URL payload is stored as an image, preserves the provider's original PNG/JPEG/HEIC-compatible bytes and dimensions, and remains full resolution in the zoom viewer. Added a direct/confirm link-opening preference, moved extension configuration from App Group CFPrefs to an atomic JSON file, and removed launch-time keyboard prewarming. Runtime and hash evidence is in `.superloopy/evidence/frontend/20260711-share-image-link-settings`.

## Next Steps

- Execute audit Phase 2: harden Share provider/queue limits and idempotency, make App Lock fail closed with an app-switcher privacy cover, and replace the hardcoded Add payload with real URL/text/photo/memo capture.
- Replace the static `time` strings with `Date`-based values and a relative formatter once real capture exists.
- Run the app on a Face ID-enrolled device/simulator session to exercise the interactive unlock path end to end.
- Verify the same App Group capability with the distribution team's signing profile on a physical device before release.
- Replace `support@clipinbox.local`, publish owned HTTPS support/privacy pages, and complete App Store Connect metadata, privacy answers, screenshots, archive validation, and upload.

## Known Risks

- The Open Design refinement now succeeds: project `clip-inbox-cta-token-refinement` produced `clip-card.html`, which was ported into the app. The earlier Fable 5 usage-limit failure is resolved.
- The bottom-tab `추가` screen remains a demo/manual-entry flow; real external capture now uses the Share Extension.
- Simulator registration and data transfer are proven. A physical-device build still requires the same Apple Developer team and App Group capability on both the app and extension provisioning profiles.
- On the external volume, `xcodebuild` fails with index-store rename errors unless DerivedData lives on the local disk and `COMPILER_INDEX_STORE_ENABLE=NO` is set (see DECISIONS).
- Original shared images now intentionally retain their source bytes, so very large Photos files consume their full local size until the clip or all app data is deleted.
- iOS does not let a `com.apple.share-services` extension open its containing app through supported APIs, and the app cannot force itself to the first share-sheet position. The current default returns to the host app; users can place Clip Inbox first through the share sheet's More → Edit → Favorites order.
- The headless simulator cannot complete the Face ID prompt, so the interactive unlock path is verified only up to the lock screen and automatic fallback; the settings-driven lock/unlock logic itself is exercised.
- Store submission is blocked until an owned support email and HTTPS support/privacy URLs are supplied; placeholders are documented but intentionally not invented.
- Audit Phase 1 removed the false-success and corrupt-snapshot sample-fallback paths. Demo Add, Share image/provider memory limits, queue hardening, and fail-open App Lock remain Phase 2 risks; accepted scope and explicit exclusions stay tracked in `docs/AUDIT_ADOPTION_PLAN.md`.
- Lighthouse was rerun three times per form factor after import hardening: mobile median 99/100/100/100 and desktop median 100/100/100/100. The remaining mobile performance point is limited by source minification, cache headers, and alternate image encoding in the dependency-free static serving path.
