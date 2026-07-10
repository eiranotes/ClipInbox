# Project Status

## Current State

Clip Inbox is a new local static prototype repository initialized on `main`. The current implementation follows `clip_inbox_trello_token_ui_spec_v1_5.md` and focuses on the Trello-like visual token system for a mobile-first clipping app.

Implemented screens:

- Inbox with filter chips, utility controls, clip cards, thumbnails, and fallback domain card.
- Share extension save flow with preview-loading state, save destination, tags, memo, disabled saved state, and toast.
- Detail view with preview, note, organization, and actions.
- Folder list with card-like rows and counts.
- Search with input, recent chips, results, and empty state.
- Sort Later classification flow without scores or percentages.
- Settings with app lock, theme, language, default folder, JSON export/import, app info, contact, delete, and icon preview.
- CTA destination screens for filter, card menu, bookmark, share, more actions, external link confirmation, folder move, clip edit, delete confirmation, save destination, tag editor, new folder, folder detail, and setting detail.

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

## Next Steps

- Optionally port the prototype into SwiftUI components if the native app source becomes available.
- Optionally port local persistence, JSON import/export, app lock, and iOS Share Sheet integration into a native implementation.

## Known Risks

- The Open Design refinement now succeeds: project `clip-inbox-cta-token-refinement` produced `clip-card.html`, which was ported into the app. The earlier Fable 5 usage-limit failure is resolved.
- This is a static web prototype of the UI spec, not a native SwiftUI app or iOS share extension binary.
- Native Face ID/app-lock and iOS Share Extension behavior cannot execute in this web prototype; their selected settings are stored locally without claiming OS integration.
- Lighthouse was rerun three times per form factor after import hardening: mobile median 99/100/100/100 and desktop median 100/100/100/100. The remaining mobile performance point is limited by source minification, cache headers, and alternate image encoding in the dependency-free static serving path.
