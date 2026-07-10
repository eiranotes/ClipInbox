# Clip Inbox UI audit target

## Design thesis

Clip Inbox is a productive minimal application for people who repeatedly capture and sort links, images, screenshots, and notes. Preserve the existing warm ivory canvas, black-outline card ownership, yellow primary action, and compact Korean utility rhythm. The memorable structural idea is a mobile card stack that becomes a two-column clipping workbench on wider screens without turning into a generic dashboard.

Design Read: mobile-first personal clipping utility, warm-bold board language, leaning iOS utility rhythm with Trello-like card ownership. `DESIGN_VARIANCE 4`, `MOTION_INTENSITY 3`, `VISUAL_DENSITY 7`.

Reference boundary: structured adaptation. The local screenshots supply hierarchy, density, touch rhythm, and screen anatomy. The v1.5 written specification and live source remain authoritative for tokens and behavior.

## Reference map

- Reference 1: inbox hierarchy, filter rhythm, clip-card anatomy, persistent bottom navigation.
- Reference 2: save flow, large primary CTA, clear field grouping.
- Reference 3: readable detail hierarchy and organization controls.
- Reference 4: folder rows with visible counts and generous targets.
- Reference 5: search input, filters, recent searches, compact results.
- Reference 6: grouped settings with clear values and disclosure.
- Reference 7: lightweight sequential sorting with one selected destination.
- Project source: dependency-free HTML, CSS, and JavaScript architecture; state and CTA behavior.

## Observed audit findings

### P1

- The app shell remains 430px wide at 768px and 1280px viewports, leaving most space unused and making the desktop experience read as a tiny phone preview.
- Interactive filter chips, tag chips, and card menu controls are 32px high, below the 44px touch-target target for primary mobile interaction.
- Edit, move, delete, folder creation, and settings choice CTAs route to screens or notices but do not commit the displayed data.
- Share, browser-open, JSON export/import, and contact CTAs describe a prepared action without executing the browser capability.
- Clip cards use a button role on an `article` that also contains nested buttons, producing an invalid interactive hierarchy for keyboard and assistive technology users.

### P2

- Inbox and folder counts are fixed copy rather than live values, so mutation feedback would drift from the visible list.
- Folder detail renders the same clips for every folder.
- Sort Later loops fixed sample items and reports a hard-coded total instead of completing the selected classification.
- Several empty, validation, and completed states are missing from mutation flows.
- Desktop and tablet layouts do not adapt content density beyond centering the phone shell.

## Preserve

- Existing Apple system font stack because the product explicitly targets an iOS utility.
- Current four-color state vocabulary, border-first depth, real reference thumbnails, and bottom navigation.
- Dependency-free static architecture and centralized CSS token layer.
- Mobile single-column reading order and restrained transform/opacity motion.

## Target layout and component rules

- 320px to 699px: one-column mobile stack; no horizontal overflow; cards keep media beside text from 375px upward and stack media below text only at the narrowest width.
- 700px to 859px: wider application shell; inbox and folder content may use two balanced columns when each card remains at least 340px wide.
- 860px and above: shell expands to a 960px maximum and uses a two-column card workbench; secondary workflows keep a readable 720px measure.
- Interactive chips are at least 40px high; icon buttons and card menus are at least 44px square; primary and row actions remain at least 52px high.
- Long Korean titles use natural word boundaries and two-line clamping only where scan speed requires it.
- Hover, active, focus-visible, disabled, selected, empty, error, and completion states remain visibly distinct.
- Motion uses transform and opacity with the existing fast/base timing and honors reduced motion.

## Functional acceptance

- Adding a clip inserts it into the inbox, updates counts, and persists locally.
- Editing changes the selected clip title and memo; moving changes its folder; deleting removes it.
- Creating a folder uses the entered name and rejects blank or duplicate names.
- Folder screens show matching sample clips and an intentional empty state.
- Sort Later commits the selected folder and reaches a completed state.
- Setting options visibly select, save, and remain reflected on the settings screen.
- Link copy writes to the clipboard; browser open launches the stored URL; web share falls back to clipboard; image-card export downloads a generated card.
- JSON export downloads current local data; JSON import validates and restores supported data; delete-all clears local data only after confirmation.
- Every CTA has a navigation, mutation, browser capability, or clearly disabled state.

## Asset map

- Existing local clip thumbnails: preserve, responsive crop with `object-fit: cover`.
- Missing preview: preserve domain fallback as a valid state.
- App icon preview: preserve code-native token illustration; it is not presented as a screenshot.
- Share-card export: compose from the selected real thumbnail and current text at runtime.

## Verification checklist

- Static build and CTA source validation pass.
- Design-system compliance reports no undeclared colors or off-scale spacing.
- Browser QA covers add, edit, move, delete, folder creation, settings selection, sort completion, clipboard, and responsive layout.
- Screenshots captured at 390, 768, and 1280 widths with no horizontal overflow.
- Keyboard focus order and focus-visible presentation checked on card, chips, menus, fields, navigation, and destructive confirmation.
- Lighthouse mobile and desktop medians remain at least 90 in every measured category.
- Anti-slop pre-flight passes with no visible em dash, orphan accent, fake screenshot, template copy, or broken state.
