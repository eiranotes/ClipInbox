# Clip Inbox Korean Onboarding Panorama v3

## Direction

Use the first three App Store frames as one dense onboarding-style illustration instead of forcing product screenshots into every frame. Oversized benefit copy, a bold yellow support band, and artwork that starts immediately below the copy eliminate the previous dead zone while each frame still carries a complete Korean message.

Design Read: a welcoming App Store opening story for people who save links casually, using Clip Inbox's tactile paper-craft onboarding language. `DESIGN_VARIANCE 5`, `MOTION_INTENSITY 0`, `VISUAL_DENSITY 3`.

## Story and Copy

| Frame | Headline | Supporting copy | Illustration |
|---|---|---|---|
| 1 | `링크 저장, 공유 한 번이면 끝` | `보고 있던 페이지를 바로 보내세요` | A blank webpage clipping and one yellow Share action |
| 2 | `입력 없이 인박스에 쏙` | `제목과 주소는 알아서 담아줘요` | Link cards entering a near-black Inbox tray |
| 3 | `저장한 링크, 바로 찾아요` | `검색하고 폴더로 가볍게 정리` | A magnifying glass retrieving one card from folders |

## Visual Contract

- Canvas: 1320 x 2868 per frame, 3960 x 2868 continuous master.
- Typography: bundled Pretendard Bold at 156px and two-line Pretendard SemiBold at 68px.
- Palette: warm ivory, paper white, near-black, soft taupe, and product yellow only.
- Illustration: one continuous ImageGen scene derived from the existing onboarding art style. No generated text, logo, app name, screenshot, or fake device UI.
- Connection: one yellow paper cord crosses both frame boundaries and the three dominant objects form capture, collect, retrieve.
- Composition: the headline occupies the upper 470px, the supporting statement sits on a yellow paper band, and the illustration begins at 1068px and fills the remaining canvas to the bottom.

## Web Research Applied

- [Apple product-page guidance](https://developer.apple.com/app-store/product-page/) states that the first one to three portrait screenshots can appear in search results when no app preview is present, so the opening set must communicate the app's essence immediately.
- [AppTweak's current screenshot guidance](https://www.apptweak.com/en/aso-blog/how-to-optimize-your-app-screenshots) recommends prioritizing the first two or three frames, using short benefit-led copy, maintaining strong contrast, and preserving consistent branding.
- [AppTweak's iOS checklist](https://www.apptweak.com/en/aso-blog/app-store-optimization-aso-checklist-for-ios) recommends connecting the first three portrait screenshots through recurring graphic elements for continuity and storytelling.
- [SplitMetrics' documented Prisma test](https://splitmetrics.com/cases/prisma-optimizes-app-store-images/) moved captions to the top, increased font weight and contrast, and reported a 12.3% conversion uplift for the optimized variant. This is directional evidence, not a guaranteed result for Clip Inbox.
- The preferred design should be validated with [App Store Connect Product Page Optimization](https://developer.apple.com/help/app-store-connect-analytics/acquisition/product-page-optimization/) after launch rather than treated as proven from visual judgment alone.

## Outputs

- Master: `docs/app-store/generated/aso-onboarding-panorama-v3/triptych-ko-KR.png`
- Upload slices: `docs/app-store/generated/aso-onboarding-panorama-v3/upload/ko-KR/`
- Contact sheet: `docs/app-store/generated/aso-onboarding-panorama-v3/contact-sheet-ko-KR.png`
- ImageGen source: `docs/app-store/generated/aso-onboarding-panorama-v3/source/panorama-onboarding-imagegen.png`
- Reproduction: `./scripts/generate_aso_onboarding_panorama_v3.sh`
