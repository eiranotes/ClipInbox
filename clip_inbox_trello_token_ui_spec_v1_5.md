# Clip Inbox / Clip Stack — Trello-Inspired Design Token Spec v1.5

## 0. Revision Note

This version corrects the previous UI direction.

The product **does not adopt a sports dashboard, ranking, prediction, or gamified interface**.
The app keeps the existing feature scope and only borrows the following visual system from the uploaded reference:

- Trello-like board/card structure
- Warm neutral background
- Thick black outlines
- Rounded cards
- Clear labels/chips
- Yellow action accents
- Simple top utility controls
- High-contrast, playful-but-clean information blocks

The product remains a lightweight one-tap clipping app.

---

## 1. Fixed Product Scope

The feature set remains unchanged.

### Included

- One-tap save from Safari / iOS Share Sheet
- URL, text, image, screenshot, and memo saving
- Automatic link preview generation
- Fallback preview cards when metadata is unavailable
- Inbox-first capture
- Folder and tag organization
- Title / URL / host / memo / tag search
- Local heuristic classification from title, URL, host, and user behavior
- JSON export/import
- App lock
- No login
- No server
- No subscription
- One-time paid app positioning

### Excluded

- Sports-style ranking UI
- Prediction cards
- Voting UI
- Leaderboard UI
- Gamification
- Social features
- AI tagging
- Full article scraping
- Server-side preview rendering
- Account system
- Team collaboration
- Desktop-first board workflow

---

## 2. Design Direction

### Design Sentence

```text
A Trello-like personal clip board where every saved link, image, and memo becomes a clean card.
```

### Product Feeling

The UI should feel like:

```text
Trello card board
+ iOS utility app
+ bold Korean web-app visual identity
```

It should **not** feel like:

```text
Generic iOS Notes
Generic bookmark manager
Sports dashboard
Game ranking panel
Heavy productivity suite
```

---

## 3. Visual References to Borrow

From the uploaded KBOYOMI-style reference, borrow only these:

| Borrow | Usage in Clip App |
|---|---|
| Thick black card borders | Saved clips, panels, buttons |
| Warm off-white background | Main app background |
| Yellow accent | Primary action, active state, important label |
| Rounded rectangular cards | Clip cards and folder panels |
| Badge/chip structure | Link type, folder suggestion, tags |
| Top utility controls | Filter, settings, theme, sort |
| Modular card layout | Inbox, folder, search, detail |

Do **not** borrow:

| Avoid | Reason |
|---|---|
| Ranking numbers | Not part of product function |
| Prediction percentages | Would imply AI/confidence scoring |
| Sports metaphors | Breaks app category clarity |
| Dense multi-column desktop layout | Mobile app first |
| Emoji-heavy identity | Can look toy-like |
| Overuse of yellow | Reduces readability |
| Heavy shadow on every card | Makes mobile UI crowded |

---

## 4. Naming Direction

The name can remain either:

| Candidate | Direction |
|---|---|
| **Clip Inbox** | More immediately understandable |
| **Clip Stack** | Better fit for card-stack visual identity |

Recommended for this design direction:

```text
Clip Inbox
```

Reason:
- The app is still an inbox-first capture tool.
- “Clip” communicates the saving action.
- “Inbox” communicates “save now, sort later.”
- It is easier to understand than “Stack” for non-technical users.

### App Store Name

```text
Clip Inbox - Save Links Fast
```

### Tagline

```text
Clip now. Sort later.
```

### Share Extension Label

```text
Save to Clip Inbox
```

---

## 5. Design Tokens

## 5.1 Color Tokens

| Token | Hex | Use |
|---|---|---|
| `color.bg.app` | `#F3EFE7` | Main app background |
| `color.bg.board` | `#EEE8DD` | Board/section background |
| `color.bg.card` | `#FFFFFF` | Clip card background |
| `color.bg.cardMuted` | `#FAF8F2` | Secondary panels |
| `color.text.primary` | `#080808` | Main text |
| `color.text.secondary` | `#5F6368` | Metadata |
| `color.text.tertiary` | `#9AA0A6` | Low-priority text |
| `color.border.strong` | `#080808` | Card/button border |
| `color.accent.yellow` | `#FFD900` | Primary CTA, active chip |
| `color.accent.green` | `#9BE7B0` | Saved/success state |
| `color.accent.blue` | `#BBD7FF` | Link/info label |
| `color.accent.purple` | `#D9C8FF` | Memo/note label |
| `color.accent.pink` | `#FFC8D8` | Image/reference label |
| `color.accent.orange` | `#FFBD67` | Warning/needs review |
| `color.danger` | `#FF4B4B` | Delete/destructive action |
| `color.shadow.hard` | `#080808` | Optional hard shadow |

### Color Rules

- App background should never be pure white.
- Cards are white for readability.
- Yellow is only for primary action, selected tab/chip, or important status.
- Use soft pastel labels for content type differentiation.
- Destructive actions are red and visually isolated.

---

## 5.2 Border Tokens

| Token | Value | Use |
|---|---:|---|
| `border.card` | `2px solid #080808` | Main clip cards |
| `border.panel` | `2px solid #080808` | Board/section panels |
| `border.button` | `2px solid #080808` | Buttons |
| `border.chip` | `1.5px solid #080808` | Labels/chips |
| `border.input` | `2px solid #080808` | Search/input fields |

### Border Rules

- Mobile card border: 2px.
- Primary CTA border: 2px.
- Avoid 3px+ borders except for app icon or marketing graphics.
- Use consistent stroke width across components.

---

## 5.3 Radius Tokens

| Token | Value | Use |
|---|---:|---|
| `radius.card` | `18px` | Saved clip cards |
| `radius.panel` | `22px` | Section containers |
| `radius.button` | `14px` | Buttons |
| `radius.chip` | `999px` | Labels/chips |
| `radius.input` | `14px` | Search/input fields |
| `radius.thumbnail` | `12px` | Preview images |

---

## 5.4 Spacing Tokens

| Token | Value |
|---|---:|
| `space.screenX` | `16px` |
| `space.screenTop` | `14px` |
| `space.cardPadding` | `14px` |
| `space.panelPadding` | `16px` |
| `space.cardGap` | `12px` |
| `space.sectionGap` | `20px` |
| `space.chipGap` | `6px` |
| `space.rowGap` | `8px` |

---

## 5.5 Typography Tokens

Use system fonts.

| Token | Size | Weight | Use |
|---|---:|---:|---|
| `type.screenTitle` | `30-34pt` | `800` | Main screen title |
| `type.sectionTitle` | `18-20pt` | `800` | Board/section title |
| `type.cardTitle` | `16-18pt` | `700` | Clip title |
| `type.body` | `14-15pt` | `500` | Description/memo |
| `type.meta` | `12-13pt` | `500` | Host/date/folder |
| `type.chip` | `11-12pt` | `700` | Badges/chips |
| `type.button` | `15-16pt` | `800` | Button label |

---

## 5.6 Shadow Tokens

Use hard shadows sparingly.

| Token | Value | Use |
|---|---|---|
| `shadow.none` | none | Default |
| `shadow.hard.sm` | `2px 2px 0 #080808` | CTA / highlighted card |
| `shadow.hard.md` | `3px 3px 0 #080808` | Marketing screenshots only |

App screens should mostly use borders, not shadows.

---

## 6. Core Design Components

## 6.1 Board Container

A board container groups related cards.

```text
┌──────────────────────────────┐
│ INBOX                    12  │
│ ───────────────────────────  │
│ [Clip Card]                  │
│ [Clip Card]                  │
└──────────────────────────────┘
```

### Rules

- Used for screen sections.
- Has thick border and warm/white surface.
- Should not create desktop-style Trello columns on iPhone.
- On iPhone, board sections stack vertically.

---

## 6.2 Clip Card

The main saved item component.

```text
┌──────────────────────────────┐
│ [LINK] [UNSORTED]             │
│                              │
│ Minimal Web Design Reference  │
│ dribbble.com · 2m ago         │
│                              │
│ [Design] [UI] [Later]         │
└──────────────────────────────┘
```

### Required Fields

| Field | Required |
|---|---:|
| Type badge | Yes |
| Title | Yes |
| Source/host | Yes |
| Saved time | Yes |
| Preview image/icon | Optional |
| Suggested folder chips | Optional |
| Quick menu | Optional |

### Type Badge Colors

| Type | Color |
|---|---|
| Link | Blue |
| Image | Pink |
| Memo | Purple |
| Screenshot | Orange |
| Saved | Green |
| Unsorted | Yellow or Gray |

---

## 6.3 Mini Preview Card

Used inside the add/share screen.

```text
┌──────────────────────────────┐
│ [thumbnail]  Page title       │
│              example.com      │
│              Short metadata   │
└──────────────────────────────┘
```

Rules:
- Small and readable.
- Do not block save if metadata is not loaded.
- Replace thumbnail with domain fallback if image is missing.

---

## 6.4 Label / Chip

Used for tags, content type, suggested folders, filters.

```text
[ LINK ] [ DESIGN ] [ UNSORTED ]
```

Rules:
- Pill shape.
- Black border.
- Small uppercase or short title.
- Tap targets should be at least 32px high when interactive.
- Do not show more than 4 chips in one card row.

---

## 6.5 Primary Button

```text
┌──────────────────────────────┐
│ SAVE TO INBOX                 │
└──────────────────────────────┘
```

Style:
- Yellow fill
- Black border
- Bold label
- Slight hard shadow optional

Use for:
- Save
- Open link
- Apply sort
- Export

---

## 6.6 Secondary Button

```text
┌──────────────┐
│ SKIP          │
└──────────────┘
```

Style:
- White fill
- Black border
- Bold label

Use for:
- Cancel
- Skip
- Move
- Edit

---

## 6.7 Top Utility Buttons

Small rounded square buttons, matching the uploaded reference.

```text
[filter icon] [calendar/sort icon] [settings icon]
```

Use for:
- Filter
- Sort
- Settings
- Theme

Rules:
- 38-44px square.
- White background.
- 2px black border.
- Simple black icon.

---

## 7. Screen Layouts

## 7.1 Inbox Screen

Function remains the same: show saved items, newest first.

### Layout

```text
CLIP INBOX                 [filter] [sort] [settings]

[ALL 84] [UNSORTED 12] [LINK 48] [IMAGE 9] [MEMO 5]

┌──────────────────────────────┐
│ [LINK] [UNSORTED]             │
│                              │
│ Minimal UI Reference          │
│ dribbble.com · 2m ago         │
│                              │
│ [Design] [UI] [Later]         │
└──────────────────────────────┘

┌──────────────────────────────┐
│ [MEMO] [NEW]                  │
│                              │
│ Goods detail page idea        │
│ Personal memo · 15m ago       │
│                              │
│ [Idea] [Work]                 │
└──────────────────────────────┘
```

### Notes

- Use a single vertical stack on mobile.
- Cards should feel like Trello cards, not iOS table rows.
- Suggested folder chips are quick actions, not mandatory fields.
- Bottom tab navigation can remain.

---

## 7.2 Share Extension Save Screen

Function remains one-tap save.

### Layout

```text
CLIP INBOX                     SAVE

┌──────────────────────────────┐
│ [LINK]                        │
│                              │
│ Minimal UI Reference          │
│ dribbble.com                  │
│                              │
│ Preview loading...            │
└──────────────────────────────┘

┌──────────────────────────────┐
│ Save destination              │
│ Inbox                         │
└──────────────────────────────┘

[SAVE TO INBOX]
```

### Fast Path

If the user chooses quick save:

```text
Safari Share
→ Save to Clip Inbox
→ Saved toast
→ Dismiss
```

Do not wait for preview image fetch.

---

## 7.3 Detail Screen

Function remains item detail/edit/move/open.

### Layout

```text
← CLIP DETAIL                    ···

┌──────────────────────────────┐
│ [LINK]                         │
│ Minimal UI Reference           │
│ dribbble.com                   │
│                                │
│ [preview image / fallback]      │
│                                │
│ Short description from metadata │
└──────────────────────────────┘

┌──────────────────────────────┐
│ NOTE                           │
│ Optional user note             │
└──────────────────────────────┘

┌──────────────────────────────┐
│ ORGANIZE                       │
│ Folder: Inbox                  │
│ Tags: Design, UI               │
└──────────────────────────────┘

[OPEN LINK]
[MOVE] [EDIT] [DELETE]
```

---

## 7.4 Folder Screen

Function remains folder navigation and management.

### Layout

```text
FOLDERS                         [edit]

┌──────────────────────────────┐
│ Inbox                     152 │
└──────────────────────────────┘

┌──────────────────────────────┐
│ Design                     36 │
└──────────────────────────────┘

┌──────────────────────────────┐
│ Shopping                   15 │
└──────────────────────────────┘

┌──────────────────────────────┐
│ + New Folder                  │
└──────────────────────────────┘
```

Rules:
- Do not use ranking numbers unless they are actual folder order.
- Counts can appear on the right.
- Folder rows should be card-like.

---

## 7.5 Search Screen

Function remains global search.

### Layout

```text
SEARCH

┌──────────────────────────────┐
│ Search clips...               │
└──────────────────────────────┘

[ALL] [LINK] [IMAGE] [MEMO] [TAG]

┌──────────────────────────────┐
│ [LINK]                         │
│ Scandinavian Interior Ideas    │
│ pinterest.com · May 20         │
└──────────────────────────────┘
```

---

## 7.6 Sort Later Screen

Function remains “review unsorted items later.”

### Layout

```text
SORT LATER                    12 LEFT

┌──────────────────────────────┐
│ [UNSORTED] [LINK]             │
│ Scandinavian Interior Ideas   │
│ pinterest.com                 │
│                               │
│ Suggested folders             │
│ [Interior] [Design] [Idea]     │
└──────────────────────────────┘

[INTERIOR]
[DESIGN] [SKIP]
```

Important:
- Do not show percentages unless the app actually computes meaningful scores.
- Suggested folders are shown as chips/buttons.
- Keep the action lightweight.

---

## 7.7 Settings Screen

Function remains settings/export/import/app lock.

### Layout

```text
SETTINGS

┌──────────────────────────────┐
│ App Lock              Face ID │
│ Default Folder         Inbox  │
│ Default Tag             None  │
└──────────────────────────────┘

┌──────────────────────────────┐
│ Export Data             JSON  │
│ Import Data             JSON  │
└──────────────────────────────┘

┌──────────────────────────────┐
│ Delete All Data               │
└──────────────────────────────┘
```

---

## 8. Link Preview Behavior

No functional change.

### Flow

```text
URL received
→ Save immediately
→ Generate preview in background
→ Update card
```

### Preview Source Priority

```text
1. iOS LinkPresentation metadata
2. Open Graph metadata
3. Twitter Card metadata
4. favicon
5. domain fallback card
```

### Fallback UI

```text
┌──────────────────────────────┐
│ [LINK]                         │
│ example.com/article/123        │
│ example.com                    │
│ [No preview image]             │
└──────────────────────────────┘
```

Fallback is a valid card state, not an error state.

---

## 9. Auto Classification UI

Function remains rule-based local classification.

### Inputs

- Page title
- Host
- URL path
- Description
- User folder behavior

### UI

```text
Suggested
[Design] [Article] [Later]
```

Do not expose internal scoring unless needed for debugging.

---

## 10. App Icon Direction

The icon should use the same design tokens.

### Concept

```text
Cream background
Black outlined tray/card
Yellow clipped card
No text
```

### Shape

```text
┌─────────────┐
│             │
│   ▰         │
│     ↘       │
│  ┌───────┐  │
│  │       │  │
│  └───────┘  │
│             │
└─────────────┘
```

### Rules

- No gradients.
- No small text.
- No complex illustration.
- Strong silhouette at small size.
- Yellow should be limited to one card shape.

---

## 11. Implementation Guidance

### SwiftUI Component Names

```text
BoardSectionView
ClipCardView
ClipPreviewView
ClipBadgeView
ClipChipView
PrimaryBoxButton
SecondaryBoxButton
UtilityIconButton
FallbackDomainCard
SortLaterCard
FolderCardRow
```

### Design Token File

Centralize visual values.

```swift
enum DesignToken {
    enum Color {
        static let appBackground = "#F3EFE7"
        static let boardBackground = "#EEE8DD"
        static let cardBackground = "#FFFFFF"
        static let textPrimary = "#080808"
        static let textSecondary = "#5F6368"
        static let borderStrong = "#080808"
        static let yellow = "#FFD900"
        static let green = "#9BE7B0"
        static let blue = "#BBD7FF"
        static let purple = "#D9C8FF"
        static let pink = "#FFC8D8"
        static let orange = "#FFBD67"
        static let danger = "#FF4B4B"
    }

    enum Radius {
        static let card = 18
        static let panel = 22
        static let button = 14
        static let thumbnail = 12
        static let chip = 999
    }

    enum Border {
        static let card = 2
        static let button = 2
        static let chip = 1.5
    }
}
```

---

## 12. Final Rule

The app must preserve the existing functional architecture.

Only the visual language changes:

```text
Default iOS list UI
→ Trello-like bold card UI
```

The user should still experience:

```text
Save instantly.
Preview automatically.
Sort later.
Search locally.
Own the data.
```
