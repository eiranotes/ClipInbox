# Tasks

## Done

- [x] Initialize Git repository.
- [x] Read `clip_inbox_trello_token_ui_spec_v1_5.md`.
- [x] Inspect all local reference images.
- [x] Attempt Open Design MCP access and start Open Design tools-dev.
- [x] Create `DESIGN.md` token contract.
- [x] Extract real thumbnail assets from references.
- [x] Implement Inbox, Share Save, Detail, Folder, Search, Sort Later, Settings, and app icon preview.
- [x] Add browser QA script.
- [x] Convert to dependency-free static app after package installation blocked on this external volume.
- [x] Run static validation, token compliance, browser QA, and Lighthouse.
- [x] Record `VISUAL_QA.md` and `PERF.md`.
- [x] Commit verified implementation.
- [x] Remove no-op CTA buttons by adding concrete screens or state destinations.
- [x] Reduce badge/tag accent tokens to yellow, blue, green, and danger.
- [x] Update browser QA to click through CTA destination screens.
- [x] Attempt Open Design MCP refinement through `clip-inbox-cta-token-refinement`; blocked by Fable 5 usage limit.
- [x] Re-run Open Design refinement (succeeded) and port the refined clip-card layout into the app.
- [x] Fix cramped inbox cards: full-height thumbnail, two-line title clamp, non-truncating source, top-row time and menu, cards on the app background.
- [x] Localize detail-screen section labels to Korean.
- [x] Fix the bookmark action to toggle on and off and reflect state on the detail header.
- [x] Re-run Playwright QA and confirm no horizontal overflow across viewports.
- [x] Apply the supplied reference-driven UI audit skill and Superloopy frontend quality gates.
- [x] Expand tablet and desktop layouts beyond the fixed 430px phone shell.
- [x] Raise interactive chip and quick-menu targets for mobile readability and touch use.
- [x] Add local persistence and real add/edit/tag/move/bookmark/delete/folder/settings/sort mutations.
- [x] Implement clipboard, external open, share-card PNG, JSON export/import, and delete-all flows.
- [x] Sanitize imported records and escape/encode all editable or imported UI output.
- [x] Remove nested interactive card semantics and verify keyboard focus targets.
- [x] Extend browser QA to validate mutation results, downloads, delete-all, restore, and responsive dimensions.
- [x] Run design-system compliance and three Lighthouse runs per mobile/desktop form factor.
- [x] Record `TARGET_SPEC.md`, `DESIGN_TOKENS.md`, `VISUAL_QA.md`, and `PERF.md` under the 20260710 evidence directory.

- [x] Create the `ios/` Xcode project (XcodeGen) and port models, store, and design tokens to Swift.
- [x] Implement all SwiftUI screens: inbox, filter, detail, share, move, edit, delete, save flow, destination, tag editor, folders, new folder, folder detail, search, sort, settings, and setting detail.
- [x] Keep native persistence and file import/export compatible with the web version-2 backup JSON.
- [x] Implement the LocalAuthentication app-lock gate.
- [x] Build on the iOS simulator, launch, and capture inbox/app-lock evidence under `.superloopy/evidence/ios/20260710-swiftui-port`.
- [x] Add and embed the `ClipInboxShare` iOS Share Extension with URL, text, web-page, and image activation rules.
- [x] Add App Group queue delivery and import queued shares when the containing app becomes active.
- [x] Preserve shared Photos images as App Group JPEGs and render them as native clip thumbnails.
- [x] Generate and apply the token-matched 1024px iOS app icon.
- [x] Verify Safari link and Photos image saves end to end on the iOS 26.5 simulator; record evidence under `.superloopy/evidence/ios/20260710-share-extension`.
- [x] Apply the supplied design skill as a structured native-iOS adaptation and document the productive-minimal visual target.
- [x] Replace card-heavy inbox/detail/folder/share/settings structures with continuous list surfaces and hairline separators.
- [x] Make every clip row open detail while keeping the quick menu independently actionable.
- [x] Remove the duplicate filter sheet and present nested workflow sheets at a 68% default detent with a large expansion option and 20pt content insets.
- [x] Add direct detail-note editing with durable save behavior and visible save feedback.
- [x] Render clips without media as text only; bundle a generated overlapping-clips fallback only for referenced images that fail to load.
- [x] Audit yellow/black CTA and bookmark feedback rendering to remove duplicated hard-shadow text.
- [x] Build, install, and exercise the redesigned app on the iPhone 17 Pro simulator; record visual and interaction evidence.
- [x] Render inbox, search, tag-editor, and folder-tag selectors as two rows with five equal-width controls per visible row and an 8pt rhythm.
- [x] Remove the count-only inbox header, hide tags/time/type/state from inbox rows, and align all five root-screen titles to the same 44pt header slot.
- [x] Remove the Settings app-icon preview and re-check short sheet top/bottom spacing.
- [x] Convert Share Extension capture to zero-confirm auto-save after the app is selected in the system share sheet.
- [x] Bundle official Pretendard v1.3.9 for the native app, Share Extension, and self-hosted web font, including OFL license files.
- [x] Verify Safari share-sheet visibility, auto-dismiss, App Group payload creation/consumption, imported clip rendering, two-row tag scrolling, and final modal layouts on the iOS 26.5 simulator.
- [x] Make native iOS SwiftUI the project source of truth and document the XcodeGen plus simulator-build workflow for future changes.
- [x] Regenerate the Xcode project and pass both simulator and generic iPhoneOS builds with the embedded Share Extension.
- [x] Separate inbox navigation, thumbnail, and quick-menu layout regions so media cannot overlap text or menu controls.
- [x] Fix inbox and compact-result content heights so image and no-image clips occupy the same row size.
- [x] Add ten practical default filter/tag options and keep every visible selector cell the same width regardless of label length.
- [x] Focus the Search field as the tab opens, persist only real submitted/opened queries, deduplicate them, and cap recent history at five.
- [x] Add and pass native unit regressions for default tag filters, search history persistence, and primary mutation reloads.
- [x] Smoke-test inbox filters, detail, card menu, share options, folders/new-folder, add/tag editor, search, Sort Later, and settings on the iPhone 17 Pro simulator.

- [x] Make the keyboard tap-only (no programmatic focus), prewarm it at launch, and dismiss it on outside taps and tab switches; confirm the `containerToPush is nil` warning is gone from captured logs.
- [x] Open the tag editor directly from the detail organize row and persist cleaned tags through a new `updateTags` mutation with regression coverage.
- [x] Unify folder and settings rows behind `DestinationRow` + `RowDivider` and verify the icon axes match pixel-for-pixel on the simulator.
- [x] Add line-spacing tokens and apply them to multi-line titles, body text, editors, and meta descriptions.
- [x] Fit the detail read flow through 링크 열기 into one viewport (140pt preview, 72pt note editor) and fix the fill-mode thumbnail overflow that covered the source row.
- [x] Show a compact saved-confirmation card in the Share Extension after zero-confirm capture.
- [x] Fix Korean 로/으로 particles in dynamic folder labels and make selectable action rows fully tappable.
- [x] Cache shared-image thumbnail decoding and re-verify the eight-test XCTest suite plus live simulator flows.
- [x] Implement Korean, English, and Japanese localization across the native app, shared UI, default sample content, toasts, Face ID purpose text, and Share Extension.
- [x] Add an App Group-backed Share save preference with immediate-save and folder-plus-memo review modes.
- [x] Change fresh-install defaults to App Lock off and immediate Share save on, with persistence regressions.
- [x] Replace the Share Extension's internal full-canvas feedback with a compact saved card and opt out of full-screen extension presentation.
- [x] Exercise both Share modes through Safari, confirm review-mode import in the inbox, and record localized visual evidence.
- [x] Add app and extension privacy manifests plus Korean, English, and Japanese App Store copy, privacy-policy draft, screenshot plan, and release checklist.
- [x] Keep the bottom navigation from moving above the keyboard and add outside-tap keyboard dismissal across non-tag-selection input screens.
- [x] Add persisted tag add/rename/delete management with clip and folder-reference propagation.
- [x] Replace the single workflow-sheet height with compact, standard, and expanded detents and verify long move/action sheets do not clip.
- [x] Preserve detail-image aspect ratio and add a tappable pinch/double-tap full-screen viewer.
- [x] Restyle the Share Extension quick-save feedback as a compact checkmark confirmation and pass the app theme through App Group configuration.
- [x] Remove setting-detail explanation cards, add deliberate short-screen spacing, enable leading-edge swipe back, and implement a readable adaptive dark theme.
- [x] Change fresh/reset folder defaults to `전체`, second-row `기본 폴더`, and `폴더 1` through `폴더 5`.
- [x] Diagnose App Group, launch-metrics, and keyboard reporter logs; replace App Group CFPrefs configuration with an atomic JSON file and remove the synthetic keyboard prewarm cycle.
- [x] Prioritize image providers over accompanying URLs and preserve original image bytes, format, and pixel dimensions through Share Extension storage and the full-screen viewer.
- [x] Add a persisted `바로 열기` / `열기 전 확인` link preference with direct opening as the default and exercise both setting and confirmation UI.
- [x] Verify the iOS platform limits for containing-app auto-launch and share-sheet ordering; keep host return as the supported default and document user-managed Favorites ordering.

## In Progress

- [ ] Phase 1: implement the data-safe repository, recovery, version, and rollback contract.
- [ ] Phase 2: harden Share capture and App Lock, then replace the demo Add flow.
- [ ] Phase 3: add trust states, Undo, storage/export disclosure, and accessibility variants.
- [ ] Phase 4: complete CI, signed archive, policy, and physical-device release gates.

## Deferred

- [ ] Date-based clip timestamps with a relative formatter.
- [ ] Interactive Face ID unlock verification on an enrolled device.
- [ ] Physical-device App Group/signing verification with the release Apple Developer team.
- [ ] Replace the placeholder support email and publish owned HTTPS support/privacy URLs before App Store submission.
- [ ] Complete App Store Connect metadata, screenshots, privacy answers, signed archive validation, and physical-device release checks.
- [ ] Production bundling/minification, cache headers, and alternate responsive image encoding if the static prototype becomes a deployed web app.
- [ ] Re-run Open Design agent refinement when model usage credits are available.
- [ ] Revisit full Trash retention, advanced duplicate detection, indexed search, OCR, Spotlight, Shortcuts, CloudKit, and Mac support only after the data-safe 1.0 gate.
