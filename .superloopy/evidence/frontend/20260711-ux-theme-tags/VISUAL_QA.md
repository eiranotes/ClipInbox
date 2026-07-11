# Visual QA

Date: 2026-07-11

Device: iOS 26.5, iPhone 17 Pro simulator `64C7804C-355B-4444-90EE-C8ED0D9355CF`

## Captured states

- `01-inbox-light.png`: light-theme inbox and unchanged five-by-two filter rhythm.
- `02-settings-dark.png`: readable warm-neutral dark theme and settings hierarchy.
- `03-folders-dark.png`: `전체`, second-row `기본 폴더`, and `폴더 1` through `폴더 5` ordering.
- `04-image-viewer.png`: aspect-fit full-screen image viewer.
- `05-move-modal.png`: expanded folder-move sheet with visible header, all destinations, and final CTA.
- `06-share-success.png`: transparent quick-share overlay with a small green checkmark confirmation card.
- `07-keyboard-hidden-nav.png`: Add memo keyboard with the input visible and bottom navigation absent above the keyboard.
- `share-extension-flow.mp4`: real Safari Share to Clip Inbox sequence, including saving and saved states.

## Interaction checks

- PASS: tapping outside Add memo and Settings tag-name inputs dismisses the keyboard.
- PASS: the tag-selection sheet keeps its previous focus/dismiss behavior.
- PASS: the bottom navigation does not rise above the keyboard; the editor still scrolls into view.
- PASS: a leading-edge drag returns from Theme detail to Settings.
- PASS: tag management exposes visible edit and danger-colored delete targets.
- PASS: folder move and card-action sheets have top/bottom breathing room with no clipped content.
- PASS: detail preview uses aspect-fit and opens a pinch/double-tap full-screen viewer.
- PASS: Light, Dark, and System choices render as a spaced option group without the removed `설정 설명` block.
- PASS: Safari quick save shows the small loading card, transitions to the green checkmark confirmation, then returns to Safari.

## Anti-slop pre-flight

- [x] Zero visible em-dashes.
- [x] No AI-purple, glow, generic gradient, or extra accent system.
- [x] Pretendard remains the deliberate bundled typeface.
- [x] Warm ivory/near-black paired theme stays consistent across every captured surface.
- [x] One radius scale and one divider-first depth strategy remain in use.
- [x] Real source images are used; no fake screenshot blocks were introduced.
- [x] Visible copy contains no AI clichés, fake statistics, or micro-tell labels.
- [x] Every new color, spacing, radius, sheet size, and motion value traces to `DESIGN.md`.
- [x] Interactive, selected, destructive, empty, and confirmation states are represented.
- [x] Reduced-motion behavior remains system-led; no new layout animation was added.

Result: PASS
