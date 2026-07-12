# Clip Inbox Korean Panorama UI Set

## Goal

Lead the App Store gallery with one continuous three-panel story that proves the real product flow: share a link, receive immediate confirmation, and find the saved item in the Inbox. Each frame must still communicate a complete benefit when shown alone.

## Final Copy

| Frame | Headline | Supporting copy | Product proof |
|---|---|---|---|
| 1 | `공유 한 번으로 링크 저장` | `Safari 공유 시트에서 클립 인박스로 바로` | Real iOS Safari link share sheet with the Clip Inbox action visible; ImageGen removed only the later save-confirmation toast from the source capture |
| 2 | `메모 없이도 바로 보관` | `제목과 주소를 인식해 인박스에 저장` | Real yellow save-confirmation state over the share sheet |
| 3 | `인박스에 모아두고 나중에 정리` | `필요할 때 검색하고 폴더로 분류` | Real populated Korean Inbox with filters and folders/search navigation |

## Visual Contract

- Canvas: `1320 x 2868` per frame, `3960 x 2868` continuous master.
- Palette: `color.bg.app`, `color.bg.cardMuted`, `color.text.primary`, `color.text.secondary`, `color.border.soft`, and `color.accent.yellow` from `DESIGN.md`.
- Typography: bundled Pretendard Bold at `128px` for the hero and Pretendard Regular at `50px` for support copy.
- Background: one ImageGen-created warm paper panorama with a continuous yellow paperclip cord. The generated layer contains no text, logos, devices, or UI.
- Product proof: upright real iOS screenshots only. No fake phone hardware, perspective transform, status bar, Dynamic Island, or home indicator is added.
- Composition: large copy in the upper third, a real screenshot in the lower two thirds, and enough edge continuity for the yellow cord and paper objects to cross both slice boundaries.

## Anti-Slop Check

- No purple or glow effects.
- No generated Korean text.
- No decorative pills, fake metrics, endorsements, prices, or version labels.
- One palette, one radius scale, one type family, and one yellow accent across all three frames.
- Real screenshots remain the dominant evidence; generated paper props stay secondary.

## Outputs

- Master: `docs/app-store/generated/aso-panorama-v2/triptych-ko-KR.png`
- Upload slices: `docs/app-store/generated/aso-panorama-v2/upload/ko-KR/`
- Contact sheet: `docs/app-store/generated/aso-panorama-v2/contact-sheet-ko-KR.png`
- ImageGen prompt log: `docs/app-store/generated/aso-panorama-v2/source/IMAGEGEN_PROMPTS.md`
- Reproduction: `./scripts/generate_aso_panorama_ui_v2.sh`
