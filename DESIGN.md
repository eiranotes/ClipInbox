# Clip Inbox Design System

## 1. Atmosphere / Signature

Clip Inbox uses a warm Korean mobile utility style with Trello-like card ownership. The signature is a soft ivory app surface, strong black outlines, large confident Korean titles, rounded white cards, quiet neutral chips, and a restrained four-color state set. It should feel useful, quick, and slightly playful without becoming a game board.

Design Read: Reading this as a mobile-first clipping utility for personal capture, warm-bold board language, leaning Trello cards plus iOS utility rhythm. DESIGN_VARIANCE 4, MOTION_INTENSITY 3, VISUAL_DENSITY 7.

## 2. Color

All production color values are declared here and mirrored as CSS variables.

| Token | CSS Variable | Hex | Role |
|---|---|---:|---|
| color.bg.app | `--color-bg-app` | `#F3EFE7` | Main app background |
| color.bg.board | `--color-bg-board` | `#EEE8DD` | Board and section background |
| color.bg.card | `--color-bg-card` | `#FFFFFF` | Clip card background |
| color.bg.cardMuted | `--color-bg-card-muted` | `#FAF8F2` | Secondary panels |
| color.text.primary | `--color-text-primary` | `#080808` | Main text and icons |
| color.text.secondary | `--color-text-secondary` | `#5F6368` | Metadata and secondary rows |
| color.text.tertiary | `--color-text-tertiary` | `#9AA0A6` | Low priority text and placeholders |
| color.border.strong | `--color-border-strong` | `#080808` | Card, button, and icon borders |
| color.border.soft | `--color-border-soft` | `#D8D1C4` | Inner separators and quiet controls |
| color.accent.yellow | `--color-accent-yellow` | `#FFD900` | Primary actions, selected controls, and needs-review state |
| color.accent.blue | `--color-accent-blue` | `#BBD7FF` | Informational type marker and focus ring |
| color.accent.green | `--color-accent-green` | `#9BE7B0` | Saved and success state |
| color.danger | `--color-danger` | `#FF4B4B` | Destructive action |
| color.shadow.hard | `--color-shadow-hard` | `#080808` | Hard shadow color |

Contrast note: Primary text on app, board, card, and yellow backgrounds passes normal text contrast. Secondary text is reserved for metadata on card or app backgrounds.

Do not use pure white for the app background. Do not add purple gradients, glow fields, sports/ranking colors, or per-content pastel colors beyond yellow, blue, green, and danger.

## 3. Typography

Use a deliberate Apple system stack because the product spec targets an iOS utility app. Letter spacing is always `0`.

| Token | CSS Variable | Size | Weight | Line Height | Role |
|---|---|---:|---:|---:|---|
| type.screenTitle | `--type-screen-title-size` | 32px | 800 | 1.08 | Main screen title |
| type.sectionTitle | `--type-section-title-size` | 20px | 800 | 1.15 | Board and section title |
| type.cardTitle | `--type-card-title-size` | 18px | 800 | 1.2 | Clip title |
| type.body | `--type-body-size` | 15px | 500 | 1.55 | Description, note, and row copy |
| type.meta | `--type-meta-size` | 13px | 500 | 1.35 | Host, date, and folder metadata |
| type.chip | `--type-chip-size` | 12px | 800 | 1 | Badges and chips |
| type.button | `--type-button-size` | 16px | 800 | 1 | Button labels |
| type.nav | `--type-nav-size` | 12px | 700 | 1 | Bottom navigation |

## 4. Spacing

Base unit: 4px. Component spacing follows the product spec through named tokens.

| Token | CSS Variable | Value | Role |
|---|---|---:|---|
| space.1 | `--space-1` | 4px | Smallest stack gap |
| space.chipGap | `--space-chip` | 6px | Chip row gap |
| space.rowGap | `--space-row` | 8px | Metadata and compact row gap |
| space.cardGap | `--space-card-rhythm` | 12px | Card list gap |
| space.cardPadding | `--space-card-pad` | 14px | Clip card padding |
| space.screenX | `--space-screen-x` | 16px | Screen side inset |
| space.panelPadding | `--space-panel-pad` | 16px | Board panel padding |
| space.sectionGap | `--space-section` | 20px | Screen section gap |
| space.screenTop | `--space-screen-start` | 14px | Top offset below status bar |
| space.bottomSafe | `--space-bottom-safe` | 112px | Scroll space above nav |

## 5. Components

Board section: `--color-bg-board`, `--border-panel`, `--radius-panel`, `--space-panel-pad`. It groups related cards and stacks on mobile.

Clip card: `--color-bg-card`, `--border-card`, `--radius-card`, `--space-card-pad`, no default shadow. Highlighted cards may use `--shadow-hard-sm`.

Badge and chip: pill radius, soft token border, mostly neutral fill, and a small state dot when the badge needs meaning. Interactive chips have hover translate, active yellow fill, focus ring, and at least 32px height. Content type badges share the blue informational marker; unsorted/new use yellow; saved uses green.

Primary box button: yellow fill, black text, black border, button radius, optional hard shadow. Disabled state uses card-muted fill and tertiary text.

Secondary box button: white fill, black text, black border, button radius. Destructive variant uses danger text and isolated placement.

Utility icon button: square 44px target, card fill, black 2px border, 14px radius, simple black icon.

Bottom navigation: white/card-muted surface, top separator, five stable tabs, yellow selected icon fill.

Thumbnail: 12px radius, 2px black border on large detail imagery, soft border on compact thumbnails.

## 6. Motion

Motion is light and functional: `--motion-fast` 140ms, `--motion-base` 200ms, `--motion-ease` cubic-bezier(0.2, 0.8, 0.2, 1). Buttons and cards use transform and opacity only. Reduced-motion removes transforms and transitions.

## 7. Depth

Depth is border-first. Default cards do not shadow. Yellow primary buttons and selected cards may use a hard shadow: `2px 2px 0 #080808`. Marketing-only large shadow remains `3px 3px 0 #080808` and is not used in the app surface.

Radius tokens:

| Token | CSS Variable | Value |
|---|---|---:|
| radius.card | `--radius-card` | 18px |
| radius.panel | `--radius-panel` | 22px |
| radius.button | `--radius-button` | 14px |
| radius.chip | `--radius-chip` | 999px |
| radius.input | `--radius-input` | 14px |
| radius.thumbnail | `--radius-thumbnail` | 12px |

Border tokens:

| Token | CSS Variable | Value |
|---|---|---|
| border.card | `--border-card` | 2px solid `#080808` |
| border.panel | `--border-panel` | 2px solid `#080808` |
| border.button | `--border-button` | 2px solid `#080808` |
| border.chip | `--border-chip` | 1px solid `#D8D1C4` |
| border.input | `--border-input` | 2px solid `#080808` |

Do not introduce extra shadows, lone dark sections, or a second accent color.
