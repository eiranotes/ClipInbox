# Clip Inbox Design System

## 1. Atmosphere / Signature

Clip Inbox uses a warm Korean productive-minimal utility style. The signature is one continuous ivory canvas, list rows divided by quiet hairlines, two-row five-column text filters, content-led typography, and yellow reserved for the current selection or primary action. It should feel quick, editorial, and native rather than assembled from repeated cards.

Design Read: Reading this as a high-frequency personal clipping utility, productive-minimal language, leaning compact list-first native iOS rhythm. DESIGN_VARIANCE 3, MOTION_INTENSITY 2, VISUAL_DENSITY 8.

## 2. Color

All production color values are declared here and mirrored as CSS variables.

| Token | CSS Variable | Light | Dark | Role |
|---|---|---:|---:|---|
| color.bg.app | `--color-bg-app` | `#F3EFE7` | `#171714` | Main app background |
| color.bg.board | `--color-bg-board` | `#EEE8DD` | `#211F1B` | Board and section background |
| color.bg.card | `--color-bg-card` | `#FFFFFF` | `#2B2924` | Focused controls and clip cards |
| color.bg.cardMuted | `--color-bg-card-muted` | `#FAF8F2` | `#24221E` | Secondary panels and bottom navigation |
| color.text.primary | `--color-text-primary` | `#171714` | `#F4F1E9` | Main text and icons |
| color.text.secondary | `--color-text-secondary` | `#5F6368` | `#B5B1A8` | Metadata and secondary rows |
| color.text.tertiary | `--color-text-tertiary` | `#9AA0A6` | `#817D75` | Low priority text and placeholders |
| color.text.onAccent | native only | `#171714` | `#171714` | Text and icons on yellow accent surfaces |
| color.border.strong | `--color-border-strong` | `#292824` | `#ECE8DF` | Emphasized control borders only |
| color.border.soft | `--color-border-soft` | `#D8D1C4` | `#44413B` | Inner separators and quiet controls |
| color.accent.yellow | `--color-accent-yellow` | `#FFD900` | `#F4D21F` | Primary actions, selected controls, and needs-review state |
| color.accent.blue | `--color-accent-blue` | `#BBD7FF` | `#8FB8EE` | Informational type marker and focus ring |
| color.accent.green | `--color-accent-green` | `#9BE7B0` | `#68C982` | Compact saved-state metadata only; never feedback surfaces |
| color.danger | `--color-danger` | `#FF4B4B` | `#FF6B6B` | Destructive action |
| color.shadow.hard | `--color-shadow-hard` | `#292824` | `#ECE8DF` | Legacy token; native application surfaces do not use hard shadows |

Contrast note: Primary and secondary text pairs pass normal-text contrast in both themes. Dark mode uses warm near-black surfaces and warm off-white text rather than pure black or pure white. Yellow keeps near-black text in both themes.

Do not use pure white for the app background. Do not add purple gradients, glow fields, hard shadows, sports/ranking colors, or per-content pastel colors beyond yellow, blue, green, and danger.

## 3. Typography

Use Pretendard v1.3.9 from the official `orioncactus/pretendard` release. The native app bundles the Regular, SemiBold, and Bold OTF faces so the app and Share Extension do not depend on a network connection; the web prototype self-hosts the official variable WOFF2. Letter spacing is always `0`. System fonts are fallback-only, while SF Symbols retain native icon metrics.

| Token | CSS Variable | Size | Weight | Line Height | Role |
|---|---|---:|---:|---:|---|
| type.screenTitle | `--type-screen-title-size` | 26px | 700 | 1.12 | Main screen title |
| type.sectionTitle | `--type-section-title-size` | 18px | 700 | 1.2 | Section title |
| type.cardTitle | `--type-card-title-size` | 17px | 600 | 1.28 | Clip row title |
| type.body | `--type-body-size` | 15px | 400 | 1.55 | Description, note, and row copy |
| type.meta | `--type-meta-size` | 13px | 400 | 1.4 | Host, date, folder, and inline tags |
| type.chip | `--type-chip-size` | 12px | 600 | 1 | Compact filters and state labels |
| type.button | `--type-button-size` | 16px | 600 | 1 | Button labels |
| type.nav | `--type-nav-size` | 11px | 600 | 1 | Bottom navigation |

The native app implements the multi-line line heights with additive `lineSpacing` tokens: +3pt on multi-line titles, +6pt on body text and text editors, +4pt on multi-line meta text. Single-line labels stay at the font's natural height.

## 4. Spacing

Base unit: 4px. Component spacing follows the product spec through named tokens.

| Token | CSS Variable | Value | Role |
|---|---|---:|---|
| space.1 | `--space-1` | 4px | Smallest stack gap |
| space.chipGap | `--space-chip` | 8px | Filter and metadata gap |
| space.rowGap | `--space-row` | 8px | Metadata and compact row gap |
| space.cardGap | `--space-card-rhythm` | 12px | Card list gap |
| space.cardPadding | `--space-card-pad` | 12px | Clip row and control padding |
| space.detailGap | native only | 16px | Detail content stack rhythm (badges, title, source, media, description) |
| space.screenX | `--space-screen-x` | 16px | Screen side inset |
| space.panelPadding | `--space-panel-pad` | 16px | Focused form surface padding only |
| space.sectionGap | `--space-section` | 24px | Screen section gap |
| space.emptyGuideTop | native only | 16px | Breathing room between the inbox filter grid and first-capture guidance |
| space.formSectionGap | native only | 16px | Compact form rhythm between adjacent input sections |
| space.screenTop | `--space-screen-start` | 12px | Top offset below status bar |
| space.bottomSafe | `--space-bottom-safe` | 24px | Content breathing room; nav uses safe-area inset |
| space.bottomNavigationClearance | native only | 72px | Extra final-scroll clearance for long root screens above bottom navigation |
| space.sheetTop | native only | 20px | Workflow-sheet content inset below the grabber |
| space.sheetBottom | native only | 20px | Workflow-sheet content inset after the final action |
| space.settingChoiceTop | native only | 72px | Breathing room before short setting option groups |
| space.settingActionTop | native only | 132px | Breathing room before one-action setting details |

Responsive and control-size tokens:

| Token | CSS Variable | Value | Role |
|---|---|---:|---|
| size.chipTarget | `--size-chip-target` | 40px | Minimum interactive chip height |
| size.touchTarget | `--size-touch-target` | 44px | Icon and card-menu touch target |
| size.iconBody | native only | 16px | Standard row and compact-action SF Symbol size |
| size.actionTarget | `--size-action-target` | 52px | Primary, secondary, input, and row target |
| size.headerHeight | native only | 44px | Shared root-screen header height and title baseline |
| size.selectionIndicator | native only | 2px | Active text-filter underline |
| count.selectionColumns | native only | 5 | Equal-width selector cells visible per row |
| count.selectionRows | native only | 2 | Visible selector rows |
| count.manualCaptureSelectionRows | native only | 1 | Compact Add-screen type selector rows |
| scale.selectionTextMinimum | native only | 0.72 | Minimum label scale inside a fixed-width selector cell |
| ratio.sheetDetentCompact | native only | 0.58 | Short action-sheet height relative to the available screen |
| ratio.sheetDetentStandard | native only | 0.76 | Medium workflow height relative to the available screen |
| size.iconColumn | native only | 28px | Leading icon column in list and action rows |
| size.destinationIcon | native only | 34px | Highlighted destination icon container |
| size.clipThumbnailWidth | native only | 80px | Inbox clip thumbnail width |
| size.clipThumbnailHeight | native only | 64px | Inbox clip thumbnail height |
| size.clipRowContentHeight | native only | 68px | Fixed inbox row content height with or without media |
| size.resultThumbnailWidth | native only | 64px | Search/folder thumbnail width |
| size.resultThumbnailHeight | native only | 48px | Search/folder thumbnail height |
| size.resultRowContentHeight | native only | 48px | Fixed compact-result content height with or without media |
| size.detailImageHeight | native only | 140px | Detail/sort/save preview maximum image height, sized so detail fits one screen |
| size.noteEditorMinHeight | native only | 72px | Detail note editor minimum height |
| size.shareQuickHeight | native only | 132px | Compact Share Extension saving/saved card host height |
| size.shareReviewHeight | native only | 390px | Share Extension folder and memo review form height |
| size.onboardingImageHeight | native only | 300px | Generated onboarding illustration maximum height |
| size.lockIllustration | native only | 228px | Friendly lock-screen illustration footprint |
| size.privacyMark | native only | 88px | Compact privacy mark shown while the app is inactive |
| layout.appMax | `--layout-app-max` | 960px | Wide application-shell maximum |
| layout.contentMax | `--layout-content-max` | 720px | Readable secondary-workflow measure |
| layout.gridBreakpoint | `--layout-grid-breakpoint` | 760px | Two-column workbench threshold |
| layout.desktopBreakpoint | `--layout-desktop-breakpoint` | 860px | Framed desktop-shell threshold |

## 5. Components

Section block: transparent on the app canvas. A section heading sits above content; hairline dividers and spacing create grouping. Use a filled surface only for an active text editor, input, confirmation, or empty/error state.

Root screen header: every tab starts at the same 12px top inset and uses a fixed 44px header height. Titles share one vertical center whether trailing utilities are present or absent.

Destination list (folders, settings): rows share the same `DestinationRow` anatomy — 12px horizontal padding, a 28px leading icon column, and a trailing value plus chevron. Rows are separated by a hairline divider inset to the icon column start (12px); the last row has no divider. Folder and settings icons therefore sit on one identical vertical axis.

Detail screen: the whole read flow — badges, title, source, preview, description, note, organize rows, and the primary link action — fits one viewport without scrolling on a 6.3" device. The preview stays 140px tall and the note editor opens at its 72px minimum; whitespace stays at the 16px detail rhythm instead of growing media.

Row hit areas: every selectable row (action rows, destination rows, selection rows) accepts taps across its full width and height, not only on the label or icon.

Share Extension feedback: saving is zero-confirm, then a compact yellow confirmation card ("Clip Inbox에 저장됨", checkmark, 10px radius, soft border) appears briefly before returning to the host app. The fill is exactly `color.accent.yellow`, matching selected menus and primary actions. A Share Extension does not attempt to launch its containing app because public iOS extension APIs do not permit that transition. Korean particles in dynamic labels and toasts follow the final consonant ("디자인으로", "인박스로").

Share Extension modes: quick save uses only one centered compact status card on a transparent host, constrained to `size.shareQuickHeight`; it never paints a full-screen app canvas. Review-before-save uses `size.shareReviewHeight` and shows one folder menu, one memo editor, and one primary save action. Both modes reuse the same radius, border, color, type, spacing, and motion tokens as the app.

Clip row: full-width navigation target with 12px vertical padding and a soft bottom divider. The inbox hierarchy is title first, source second, then an optional 80x64 thumbnail. Type, state, time, and tags are detail-only metadata. The menu remains an independent 44px trailing target. There is no outer row card or shadow.

Badge and filter: type/state metadata is plain text with an optional semantic mark and appears only in focused/detail contexts. Inbox and search filters show five equal-width cells per row across two visible rows, with an 8px gap, a 44px touch target, and a 2px yellow active underline. The first ten options fill the visible 5x2 grid; additional options continue horizontally in the same two-row grid. Label length never changes cell width. There is no per-filter box or duplicate filter modal.

Tags: tags appear in detail inside the organize group, and the tag row opens the tag editor directly so tags can be changed without entering full clip edit. Editing screens show the selected value in one summary row, and tag selection uses the same two-row, five-column, equal-width underline grid as the main filter. Custom tags can grow beyond the first ten options through horizontal continuation. Tags never render as pill collections or irregular boxes.

Primary button: flat yellow fill, near-black text, 10px radius, no shadow and no text raster shadow. Disabled state uses card-muted fill and tertiary text.

Secondary button: transparent or white fill, near-black text, soft 1px border, 10px radius. Destructive actions use danger text and isolated placement.

Utility icon button and row menu: square 44px hit target with no visible container in the default state. Only a selected state may use a compact yellow 8px-radius fill. Use a simple near-black icon and no heavy border.

Bottom navigation: white/card-muted surface, top separator, five stable tabs, yellow selected icon fill. Selected icon glyphs use `color.text.onAccent`; selected labels use `color.text.primary` so they remain visible in dark mode.

Workflow sheet: short action menus open at 58%, medium selectors at 76%, and destination/move/edit flows open at the large detent. Every sheet can expand when its content may grow. Content receives 20px top and bottom insets inside the sheet so the header does not crowd the grabber and the final action never touches or disappears below the sheet edge.

Setting detail: the duplicated explanatory card is absent. Default-folder selection starts directly below the header because its list is long; short option groups begin after 72px and one-action details begin after 132px so their controls sit around the middle rhythm instead of clinging to the top edge.

Link opening: Settings offers `바로 열기` and `열기 전 확인`. Direct opening is the default; confirmation is an explicit user preference and applies consistently to detail and card-menu link actions.

Feedback surfaces: app toasts, recovery notices, shared-item notices, deletion Undo, and Share Extension success use the same `color.accent.yellow` fill. Green remains available only for compact saved-state metadata, never for a modal, banner, toast, or selected menu.

App Lock: the selected app mark, warm-white clipping cards held by one yellow paperclip in a near-black tray, appears at `size.lockIllustration` above a compact title/body stack and at `size.privacyMark` on the inactive privacy shield. Authentication copy and the unlock action remain native text and controls. The mark contains no text, device frame, or fake biometric UI. The screen uses the existing warm canvas, yellow accent, typography, button, and motion tokens.

Trash: the folder list ends with a fixed trash destination that cannot receive moved clips. Deleting a clip records its original folder and deletion time, hides it from every active list/search/count, and shows it in Trash with Restore and Empty Trash actions. A yellow information panel states that items are permanently removed after 30 days.

Onboarding: first launch uses three generated editorial illustrations in 4:3 frames. Each page has one image, one short heading, one supporting sentence, a restrained three-step underline indicator, and one yellow primary action. All instructional text remains native SwiftUI text; generated assets contain no text or fake branded screenshots. The same guide is available again from Settings.

Tag management: Settings exposes one flat tag list with explicit edit and delete icon targets. Renaming updates every clip and folder-default reference; deleting removes the tag from those references. Destructive affordances use danger text and never rely on swipe-only discovery.

Detail image: the full source image uses aspect-fit inside a maximum 140px preview, even when that leaves horizontal or vertical breathing room. Tapping it opens a dark-compatible full-screen viewer with close, pinch, and double-tap zoom controls.

Responsive shell: mobile stays a single card stack. At 760px and wider the inbox and folder collections may use two columns when each card remains at least 340px wide. At 860px and wider the shell expands to 960px; secondary workflows keep a centered 720px reading measure.

Thumbnail: 8px radius with no border for large detail imagery and an optional soft 1px border for compact rows. No-image clips are text-only. The generated stacked-clips fallback is reserved for an image reference that fails to load.

## 6. Motion

Motion is light and functional: `--motion-fast` 140ms, `--motion-base` 180ms, `--motion-ease` cubic-bezier(0.2, 0.8, 0.2, 1). The keyboard is raised only by a direct tap on a text field or editor; screens and workflow sheets never request focus programmatically and do not synthesize a launch-time first-responder cycle. Tapping outside an input dismisses the keyboard on every input surface except the intentionally unchanged tag-selection sheet; the bottom navigation hides while the keyboard is visible instead of being lifted above it. Search result evaluation follows input by 120ms so Korean composition and key events stay responsive while results update after the user pauses. Pushed detail screens support a left-edge swipe to return. Buttons and rows use opacity only; sheets use the system transition. Reduced-motion removes custom transitions.

## 7. Depth

Depth is tonal and divider-first. Native application surfaces use no drop shadows. White is reserved for focused controls, text editors, and explicit confirmation states; the continuous ivory canvas remains dominant.

Radius tokens:

| Token | CSS Variable | Value |
|---|---|---:|
| radius.card | `--radius-card` | 10px |
| radius.panel | `--radius-panel` | 12px |
| radius.button | `--radius-button` | 10px |
| radius.chip | `--radius-chip` | 8px |
| radius.input | `--radius-input` | 8px |
| radius.thumbnail | `--radius-thumbnail` | 8px |
| radius.shell | `--radius-shell` | 24px |

Border tokens:

| Token | CSS Variable | Value |
|---|---|---|
| border.card | `--border-card` | 1px solid `#D8D1C4` |
| border.panel | `--border-panel` | 1px solid `#D8D1C4` |
| border.button | `--border-button` | 1px solid `#D8D1C4` |
| border.chip | `--border-chip` | 1px solid `#D8D1C4` |
| border.input | `--border-input` | 1px solid `#D8D1C4` |

Do not introduce extra cards, pill tags, heavy outlines, shadows, lone dark sections, or a second accent color.
