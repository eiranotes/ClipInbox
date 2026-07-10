# Clip Inbox token evidence

Canonical contract: `/Volumes/AI/Clip/DESIGN.md`

SHA-256 at verification: `1ff97918ee027e7392c057d2345e35f3ba5e58e8d3d5f39487bd2d43d7f8c4fa`

## Atmosphere

Warm Korean productive-minimal utility. Ivory canvas, white owned cards, strong near-black borders, one yellow primary accent, restrained blue/green/danger states. Mobile-first card stack becomes a two-column clipping workbench on wider screens.

## Color

- App `#F3EFE7` via `--color-bg-app`
- Board `#EEE8DD` via `--color-bg-board`
- Card `#FFFFFF` via `--color-bg-card`
- Card muted `#FAF8F2` via `--color-bg-card-muted`
- Primary text and strong border `#080808`
- Secondary text `#5F6368`
- Tertiary text `#9AA0A6`
- Soft border `#D8D1C4`
- Primary yellow `#FFD900`
- Informational blue `#BBD7FF`
- Success green `#9BE7B0`
- Danger `#FF4B4B`

## Typography

Apple system stack with Korean system fallbacks. Screen 32/800, section 20/800, card 18/800, body 15/500, metadata 13/500, chip 12/800, button 16/800, navigation 12/700.

## Spacing and sizing

- Base unit 4px
- Screen inset 16px, panel padding 16px, card padding 14px
- Compact gaps 4/6/8/12px, section gap 20px
- Interactive chip target 40px
- Icon and card-menu target 44px
- Primary action target 56px
- Tablet grid threshold 760px
- Desktop shell threshold 860px
- Wide shell maximum 960px
- Secondary workflow measure 720px

## Components

Cards, boards, buttons, inputs, chips, rows, bottom navigation, empty states, error messages, file picker, and toast states all use the canonical CSS variables. Buttons cover hover, active, focus-visible, disabled, selected, and destructive states. Static badges stay compact; only interactive chips use the 40px target.

## Motion

140ms fast and 200ms base transitions with `cubic-bezier(0.2, 0.8, 0.2, 1)`. Transform and opacity are the motion properties. Reduced-motion collapses transitions and removes hover transforms.

## Depth

Border-first system. Default cards have no shadow; selected and primary elements may use the single hard 2px shadow token. Desktop shell uses the existing restrained surface shadow and a strong border.
