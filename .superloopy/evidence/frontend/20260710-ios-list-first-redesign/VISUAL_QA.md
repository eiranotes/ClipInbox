# Native iOS Visual QA

Date: 2026-07-10  
Device: Adelie iPhone 17 Pro, iOS 26.5 simulator  
Viewport: 402 x 874 pt (1206 x 2622 px at 3x)  
Mode: Productive minimal / Quiet Editorial Utility  
Reference method: `reference-driven-ui-builder` structured adaptation

## Build and bundle

- `xcodegen generate --spec project.yml`: pass.
- `xcodebuild` Debug simulator build with local DerivedData and index store disabled: pass.
- Embedded `ClipInboxShare.appex` validation: pass.
- Existing dependency-free web prototype `npm run build`: pass (9 files, 20 screens, 13 declared colors).
- Existing web prototype `npm run qa` with its preview server running: pass at 390 / 768 / 1280 px, no horizontal overflow, 1 / 2 / 2 columns, minimum button height 40 px.

## Visual checks

- Inbox: one continuous warm canvas, row dividers instead of outer cards, smaller 26 pt title, no duplicated lower Inbox label, container-free top utility icons, quiet dot metadata, and optional right-side media only when a clip has an image reference.
- Filter: sheet accessibility state is `Expanded`; all filters and the yellow apply CTA are visible in one full-height workflow. Yellow button text is a single crisp layer.
- Image detail: media has 16 pt screen gutters, 8 pt radius, a light one-pixel outline, and clear spacing before the inline note editor.
- Text detail: Example Domain contains no fabricated preview block. The link CTA and secondary actions remain above the safe-area bottom navigation.
- Bookmark/save feedback: flat green status feedback uses one text layer with no hard shadow or doubled glyphs.
- Folders/settings/search/add: flat action-row grammar and hairline separators are consistent; accessibility exposes every named row and CTA as an independent button.
- No horizontal clipping or CTA/tab overlap was observed in the inspected 402 pt phone viewport.

## Interaction checks

- Full clip row: accessibility exposes a single `... 상세 보기` button spanning each row plus a separate `... 메뉴` button; a tap on the row navigated to detail.
- Note editing: actual keyboard input changed the note, enabled Save, persisted `note edit QA` into `Library/Application Support/clip-inbox-data.json`, and displayed `노트를 저장했습니다`. The test value was then restored to `Example Domain` and persistence was rechecked.
- Bookmark: toggled off and on; `북마크에서 해제했습니다` feedback appeared without doubled text, then original state was restored.
- Broken image fallback: a temporary `/public/images/clip-missing.png` reference made the generated overlapping-clips fallback appear. The original JSON was restored and checked after capture.
- No-image behavior: the same Example Domain clip has no thumbnail when its image key is absent.
- Add and Search: all visible destination, tag, save, filter, recent-query, and result-row controls were exposed as actionable accessibility elements.

## Evidence

- `inbox-final.png`
- `filter-final.png`
- `detail-image-final.png`
- `detail-text-final.png`
- `bookmark-toast-final.png`
- `fallback-runtime.png`
- `folders-final.png`
- `settings-final.png`
- `target-inbox.png`
- `target-detail.png`

## Remaining external gate

This pass proves simulator UI, persistence, app/extension bundling, and prior simulator Share Extension registration. Distribution signing and App Group provisioning still require the release Apple Developer team on a physical device.
