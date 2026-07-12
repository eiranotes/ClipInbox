# Korean App Store Screenshot Strategy

## Release Set

- Preferred first-three candidate: `docs/app-store/generated/aso-onboarding-panorama-v3/upload/ko-KR/`
- Full seven-frame baseline: `docs/app-store/generated/aso-ko-v1/upload/ko-KR/`
- Format: seven portrait PNG files, `1320 x 2868`, no alpha
- Typography: bundled Pretendard Bold for 156px headlines and Pretendard SemiBold for two-line 68px supporting copy in the first three frames
- Palette: warm ivory, near-black, and the product yellow only
- Product proof: real iOS 26.5 simulator UI with the status bar, Dynamic Island, and home indicator cropped away
- Sample library: ten fictional but realistic clips across links, images, screenshots, and memos; no personal data, live account data, endorsements, or price claims

## Seven-Frame Story

1. `링크 저장, 공유 한 번이면 끝` leads with the product's fastest, easiest action.
2. `입력 없이 인박스에 쏙` continues the yellow cord into automatic Inbox collection.
3. `저장한 링크, 바로 찾아요` completes the continuous scene with search and folders.
4. `좋아하는 것을 한 곳에` combines the saved-items onboarding art with the populated real Inbox.
5. `기억 대신 검색하세요` combines the destination onboarding art with a real search for `디자인`.
6. `내 방식대로 가볍게 정리` combines the Share onboarding art with localized folders and real counts.
7. `계정 없이 내 기기 안에서` combines the saved-items art with real local lock, backup, and save settings.

## ASO Rationale

Apple notes that the first one to three portrait screenshots can appear in search results when there is no app preview. The first three therefore communicate the complete capture, collect, retrieve loop without relying on small UI text. Frames four through seven each focus on one product benefit and use real app UI as proof.

The continuous triptych is generated as one `3960 x 2868` master and sliced into three exact `1320px` panels. This keeps the visual flow continuous across gallery gaps while preserving valid standalone upload files.

## QA Gates

- Headline remains readable on the 330px-wide contact sheet.
- No phone frame, status bar, Dynamic Island, home indicator, angle, or perspective transform appears.
- First three slices reconstruct the master pixel-for-pixel.
- Every upload file is exactly `1320 x 2868` and has no alpha channel.
- Real simulator captures cannot be near-white launch screens; the capture script rejects and retries them.
- Visible copy contains no prices, fake ratings, unsupported claims, personal data, or third-party endorsements.

## Reproduction

```sh
./scripts/generate_aso_onboarding_panorama_v3.sh
```

The full seven-frame baseline remains reproducible with:

```sh
./scripts/generate_aso_screenshots.sh
```

Use `SKIP_CAPTURE=1` to recompose from already verified raw simulator captures.
