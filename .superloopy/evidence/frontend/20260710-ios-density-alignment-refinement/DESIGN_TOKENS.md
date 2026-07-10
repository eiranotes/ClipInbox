# Clip Inbox Design System

## 1. Atmosphere / Signature

Clip Inbox uses a warm Korean productive-minimal utility style. The signature is one continuous ivory canvas, list rows divided by quiet hairlines, two-row horizontally scrolling text filters, content-led typography, and yellow reserved for the current selection or primary action. It should feel quick, editorial, and native rather than assembled from repeated cards.

Design Read: Reading this as a high-frequency personal clipping utility, productive-minimal language, leaning compact list-first native iOS rhythm. DESIGN_VARIANCE 3, MOTION_INTENSITY 2, VISUAL_DENSITY 8.

## 2. Color

All production color values are declared here and mirrored as CSS variables.

| Token | CSS Variable | Hex | Role |
|---|---|---:|---|
| color.bg.app | `--color-bg-app` | `#F3EFE7` | Main app background |
| color.bg.board | `--color-bg-board` | `#EEE8DD` | Board and section background |
| color.bg.card | `--color-bg-card` | `#FFFFFF` | Clip card background |
| color.bg.cardMuted | `--color-bg-card-muted` | `#FAF8F2` | Secondary panels |
| color.text.primary | `--color-text-primary` | `#171714` | Main text and icons |
| color.text.secondary | `--color-text-secondary` | `#5F6368` | Metadata and secondary rows |
| color.text.tertiary | `--color-text-tertiary` | `#9AA0A6` | Low priority text and placeholders |
| color.border.strong | `--color-border-strong` | `#292824` | Emphasized control borders only |
| color.border.soft | `--color-border-soft` | `#D8D1C4` | Inner separators and quiet controls |
| color.accent.yellow | `--color-accent-yellow` | `#FFD900` | Primary actions, selected controls, and needs-review state |
| color.accent.blue | `--color-accent-blue` | `#BBD7FF` | Informational type marker and focus ring |
| color.accent.green | `--color-accent-green` | `#9BE7B0` | Saved and success state |
| color.danger | `--color-danger` | `#FF4B4B` | Destructive action |
| color.shadow.hard | `--color-shadow-hard` | `#292824` | Legacy token; native application surfaces do not use hard shadows |

Contrast note: Primary text on app, board, card, and yellow backgrounds passes normal text contrast. Secondary text is reserved for metadata on card or app backgrounds.

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

## 4. Spacing

Base unit: 4px. Component spacing follows the product spec through named tokens.

| Token | CSS Variable | Value | Role |
|---|---|---:|---|
| space.1 | `--space-1` | 4px | Smallest stack gap |
| space.chipGap | `--space-chip` | 8px | Filter and metadata gap |
| space.rowGap | `--space-row` | 8px | Metadata and compact row gap |
| space.cardGap | `--space-card-rhythm` | 12px | Card list gap |
| space.cardPadding | `--space-card-pad` | 12px | Clip row and control padding |
| space.screenX | `--space-screen-x` | 16px | Screen side inset |
| space.panelPadding | `--space-panel-pad` | 16px | Focused form surface padding only |
| space.sectionGap | `--space-section` | 24px | Screen section gap |
| space.screenTop | `--space-screen-start` | 12px | Top offset below status bar |
| space.bottomSafe | `--space-bottom-safe` | 24px | Content breathing room; nav uses safe-area inset |
| space.sheetTop | native only | 20px | Workflow-sheet content inset below the grabber |
| space.sheetBottom | native only | 20px | Workflow-sheet content inset after the final action |

Responsive and control-size tokens:

| Token | CSS Variable | Value | Role |
|---|---|---:|---|
| size.chipTarget | `--size-chip-target` | 40px | Minimum interactive chip height |
| size.touchTarget | `--size-touch-target` | 44px | Icon and card-menu touch target |
| size.actionTarget | `--size-action-target` | 52px | Primary, secondary, input, and row target |
| size.headerHeight | native only | 44px | Shared root-screen header height and title baseline |
| size.selectionIndicator | native only | 2px | Active text-filter underline |
| ratio.sheetDetent | native only | 0.68 | Default workflow-sheet height relative to the available screen |
| size.iconColumn | native only | 28px | Leading icon column in list and action rows |
| size.destinationIcon | native only | 34px | Highlighted destination icon container |
| size.clipThumbnailWidth | native only | 80px | Inbox clip thumbnail width |
| size.clipThumbnailHeight | native only | 64px | Inbox clip thumbnail height |
| size.resultThumbnailWidth | native only | 64px | Search/folder thumbnail width |
| size.resultThumbnailHeight | native only | 48px | Search/folder thumbnail height |
| size.detailImageHeight | native only | 220px | Detail image viewport height |
| layout.appMax | `--layout-app-max` | 960px | Wide application-shell maximum |
| layout.contentMax | `--layout-content-max` | 720px | Readable secondary-workflow measure |
| layout.gridBreakpoint | `--layout-grid-breakpoint` | 760px | Two-column workbench threshold |
| layout.desktopBreakpoint | `--layout-desktop-breakpoint` | 860px | Framed desktop-shell threshold |

## 5. Components

Section block: transparent on the app canvas. A section heading sits above content; hairline dividers and spacing create grouping. Use a filled surface only for an active text editor, input, confirmation, or empty/error state.

Root screen header: every tab starts at the same 12px top inset and uses a fixed 44px header height. Titles share one vertical center whether trailing utilities are present or absent.

Clip row: full-width navigation target with 12px vertical padding and a soft bottom divider. The inbox hierarchy is title first, source second, then an optional 80x64 thumbnail. Type, state, time, and tags are detail-only metadata. The menu remains an independent 44px trailing target. There is no outer row card or shadow.

Badge and filter: type/state metadata is plain text with an optional semantic mark and appears only in focused/detail contexts. Inbox and search filters use two horizontally scrollable text rows with an 8px item gap, a 44px touch target, and a 2px yellow active underline. There is no per-filter box or duplicate filter modal.

Tags: read-only tags appear only in detail. Editing screens show the selected value in one summary row, and tag selection uses the same two independently scrollable underline-based text rows as the main filter. Custom tags can grow beyond the initial suggestions. Tags never render as pill collections or irregular boxes.

Primary button: flat yellow fill, near-black text, 10px radius, no shadow and no text raster shadow. Disabled state uses card-muted fill and tertiary text.

Secondary button: transparent or white fill, near-black text, soft 1px border, 10px radius. Destructive actions use danger text and isolated placement.

Utility icon button and row menu: square 44px hit target with no visible container in the default state. Only a selected state may use a compact yellow 8px-radius fill. Use a simple near-black icon and no heavy border.

Bottom navigation: white/card-muted surface, top separator, five stable tabs, yellow selected icon fill.

Workflow sheet: opens at 68% of the available height and can expand to large. Content receives 20px top and bottom insets inside the sheet so the header does not crowd the grabber, primary actions remain visible, and short workflows do not leave a full-screen empty field.

Responsive shell: mobile stays a single card stack. At 760px and wider the inbox and folder collections may use two columns when each card remains at least 340px wide. At 860px and wider the shell expands to 960px; secondary workflows keep a centered 720px reading measure.

Thumbnail: 8px radius with no border for large detail imagery and an optional soft 1px border for compact rows. No-image clips are text-only. The generated stacked-clips fallback is reserved for an image reference that fails to load.

## 6. Motion

Motion is light and functional: `--motion-fast` 140ms, `--motion-base` 180ms, `--motion-ease` cubic-bezier(0.2, 0.8, 0.2, 1). Buttons and rows use opacity only; sheets use the system transition. Reduced-motion removes custom transitions.

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
