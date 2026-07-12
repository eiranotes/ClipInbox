# Visual QA

Status: PASS

## Evidence

- Reference inputs: `docs/app-store/aso/ASO_kr (1).png` through `(3).png`
- Final contact sheet: `docs/app-store/generated/aso-reference-refresh-v1/contact-sheet-ko-KR.png`
- Upload files: three 1320 x 2868 RGB PNG files without alpha
- Current app captures: Inbox, Folder, and Search from the booted iPhone 17 Pro simulator
- Share proof: `docs/app-store/generated/icon-reference-refresh/share-sheet-current.png`
- Lock proof: `docs/app-store/generated/icon-reference-refresh/lock-screen-current.png`

## Review

- All three frames keep the reference reading order: brand, benefit, yellow underline, product proof, footer.
- All visible product UI comes from the current native build; no outdated mock screen or generated UI remains.
- The same yellow paperclip appears in the app icon, lock/privacy surface, and Safari share sheet.
- Copy contains no em dash, AI cliché, price, endorsement, personal data, or placeholder person/brand.
- One accent, one radius family, one warm theme, and bundled Pretendard hold across the set.
- No purple glow, fake device frame, perspective transform, horizontal clipping, or generated text is present.
- Motion is not claimed because the deliverable is a static App Store image set.

The browser-only 390/768/1280 and Lighthouse gates do not apply to native iOS screenshots. Simulator captures at the production 1206 x 2622 device surface and upload validation at 1320 x 2868 replace them.
