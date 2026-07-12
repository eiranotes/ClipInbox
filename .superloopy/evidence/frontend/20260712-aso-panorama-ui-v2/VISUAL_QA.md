# Visual QA: Korean App Store Panorama UI v2

## Artifacts

- Master: `docs/app-store/generated/aso-panorama-v2/triptych-ko-KR.png`
- Contact sheet: `docs/app-store/generated/aso-panorama-v2/contact-sheet-ko-KR.png`
- Upload slices: `docs/app-store/generated/aso-panorama-v2/upload/ko-KR/`

## Result

PASS for candidate review.

## Verified

- All three slices are exactly 1320 x 2868 and have no alpha channel.
- Re-appending the three slices changes zero pixels compared with the 3960 x 2868 master.
- Frame 1 shows a Safari link Share sheet with the Clip Inbox action.
- Frame 2 shows the yellow immediate-save confirmation over the same Safari flow.
- Frame 3 shows a populated Korean Inbox with filters and visible search/folder destinations.
- Each Korean headline is complete and readable on the 330px-wide contact sheet.
- The generated paper layer contains no text, logo, UI, device, purple, glow, or fake metric.
- The yellow cord and paper surface cross both slice boundaries without a jump.
- Screens remain upright with no perspective transform or fake phone hardware.

## Anti-Slop Preflight

- Zero em dashes in visible marketing copy: pass.
- Pretendard is used instead of a default web font: pass.
- Product palette and one yellow accent are consistent: pass.
- Generated props remain secondary to real product evidence: pass.
- No decorative pills, version labels, fake ratings, prices, endorsements, or generic statistics: pass.
- Layout-family and interactive-state checks are not applicable to a three-image raster marketing artifact.

## Known Limitation

The Safari source capture contains the English demo page title `Example Domain` and the system app label `Clip Inbox`. This is fictional, non-personal data and does not affect the Korean marketing copy; a final App Store capture can replace it after the Korean localized Share sheet is recaptured on the release simulator.
