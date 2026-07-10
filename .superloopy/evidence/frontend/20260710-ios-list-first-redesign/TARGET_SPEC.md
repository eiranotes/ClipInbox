# Clip Inbox iOS List-First Target

Reference boundary: structured adaptation. Preserve the current SwiftUI navigation, local data, Share Extension imports, and five-tab bottom navigation while replacing the box-heavy presentation.

## Visual targets

- `target-inbox.png`: list-first inbox structure.
- `target-detail.png`: content-led detail and inline note editing.
- Project source: exact Korean copy, CTA behavior, data, and accessibility constraints.

## Extracted design rules

1. Canvas and grid
   - One continuous warm-ivory canvas.
   - 16px horizontal gutter and 12 to 24px vertical rhythm.
   - Bottom navigation owns the safe area; scroll content never sits beneath it.
2. Typography
   - Screen title 26px/700, section title 18px/700, row title 17px/650.
   - Metadata and inline tags are 13px/450, never bold pills.
3. Surfaces and shape
   - Clip collection is a list with 1px dividers, not repeated cards.
   - Filters use 8px rectangular segments. No 999px pill radius in the native app.
   - Inputs and the primary CTA may use a contained surface; most sections remain transparent.
4. Clip anatomy
   - Metadata, title, source, and tags form one left-aligned scan path.
   - Thumbnail is optional and right-aligned. No image reference means no media block.
   - If an image reference fails, show the generated stacked-clips fallback.
   - Every non-menu point in the row enters detail; the menu remains a separate 44px target.
5. Detail anatomy
   - Title and real content lead; no outer detail card.
   - Real imagery has breathing room, 8px radius, and no black border.
   - Note text is editable in place with an explicit small save action and save-on-exit safety.
   - Folder and tags are clean metadata rows with hairlines.
   - The link CTA and secondary actions stay in normal scroll content above the bottom safe area.
6. Color and depth
   - Yellow is used only for selection and the primary action.
   - No hard shadows. No shadow may be applied to a view containing text.
   - Blue, green, and danger are semantic marks only.
7. States
   - Empty rows remain text-led.
   - Image-reference load failure has a real bundled fallback asset.
   - Pressed states change opacity only; disabled text never overlaps or blurs.

## Asset map

- `clip-image-fallback.png`: generated bitmap, 1024x768, bundled in `clip-image-fallback.imageset`.
- Existing clip thumbnails: retained.
- Shared Photos images: retained in the App Group and rendered directly.

## Acceptance checks

- Filter sheet opens at full height and the apply CTA is fully visible.
- No duplicated `인박스` heading below the inbox filters.
- Yellow buttons and bookmark feedback have one crisp text raster.
- Tapping card metadata, blank padding, title, source, or thumbnail opens detail; menu tap opens only the menu.
- No-image clips show no fabricated media box in inbox or detail.
- Detail note can be edited and persisted without opening the full edit sheet.
- No detail CTA is obscured by the bottom navigation.
