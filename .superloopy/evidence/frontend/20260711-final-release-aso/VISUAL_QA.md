# Final Release and ASO Visual QA

## Surface and target

- Product: native SwiftUI `ClipInbox` and embedded `ClipInboxShare`
- Device: booted `Adelie iPhone 17 Pro iOS 26.5`
- Native capture size: 1206 x 2622
- App Store upload size: 1320 x 2868, PNG, no alpha
- Design direction: warm productive-minimal stationery, one yellow accent, real UI over generated mock screens

## Verified states

- Light Inbox with 13 real simulator clips and a readable selected bottom tab.
- Dark Inbox with the selected `인박스` label visibly rendered in adaptive primary text.
- Honest empty Inbox with a dedicated 16pt gap below the two-row filter grid.
- Korean Share guide showing `클립 인박스`, including `클립 인박스를 선택해요` and the localized body/accessibility copy.
- English Share guide showing `Choose Clip Inbox` and Japanese Share guide showing `Clip Inboxを選択`; both retain the requested English product name.
- Search, Folders, and Settings in light mode.
- App Lock with the user-selected card/paperclip/tray artwork and native text/button.
- Explicit unlock tap presents system authentication; LocalAuthentication success remains fail-closed until the matching Face ID event.
- Existing 13-clip simulator data was backed up before the empty-state capture and restored afterward.

## Evidence

- `docs/app-store/generated/aso-contact-sheet.png`
- `docs/app-store/generated/raw/dark-bottom-nav-fixed.png`
- `docs/app-store/generated/raw/empty-state-gap.png`
- `docs/app-store/generated/raw/lock-screen-final.png`
- `docs/app-store/generated/upload/ko-KR/01-inbox.png` through `07-first-clip.png`
- `docs/app-store/generated/upload/en-US/` (three images) and `ja-JP/` (two images)
- `docs/app-store/generated/icon-candidates/icon-selected-cards-source.png`

## Anti-slop pre-flight

- [x] Zero em dashes in the new user-facing copy.
- [x] No uppercase eyebrow labels.
- [x] No purple or glow treatment.
- [x] Pretendard remains the production app font.
- [x] No beige-and-brass premium cliche; the existing warm canvas uses one saturated yellow and near-black product mark.
- [x] Color, shape, theme, icon, and type consistency locks hold.
- [x] No generated fake app screenshots; all App Store UI images are real simulator captures.
- [x] Copy is implementation-grounded and contains no fake metrics or placeholder product names.
- [x] No decorative status dots, fake version badges, or other catalogue micro-tells were introduced.
- [x] No new motion claim was added.
- [x] New spacing and image sizes trace to `DESIGN.md` tokens.
- [x] Empty, populated, locked, light, dark, and localization states were exercised.
- [x] The native iPhone surface has no horizontal page scroll; the two-row selector alone intentionally continues horizontally beyond ten items.

## Quality and release gate

- `plutil -lint` passed for Korean, English, and Japanese app/share strings.
- 31 of 31 native XCTest cases passed.
- The shared local release gate passed: XcodeGen drift check, simulator tests, unsigned generic iOS Release archive, embedded Share Extension, privacy manifests, localizations, expected bundle IDs, and source App Group agreement.
- Remaining external gates: distribution signing, owned HTTPS/privacy/support metadata, App Store Connect pricing/availability, validation/upload, and physical-device Share/App Lock matrix.

## Result

PASS for repository-owned release and visual QA. External account and device gates remain explicitly open.
