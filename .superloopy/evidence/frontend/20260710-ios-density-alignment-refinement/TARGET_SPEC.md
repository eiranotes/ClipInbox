# Density and Alignment Refinement

Mode: Productive minimal application  
Reference boundary: Structured adaptation of the live iPhone simulator surface  
Device target: 402 x 874 pt iPhone viewport

## Design thesis

The inbox is a reading list, not a metadata dashboard. One direct filter control stays visible, rows show only the information needed to identify a clip, and secondary attributes move to detail. Every root tab shares one title baseline.

## Inbox anatomy

- Header: fixed 44 pt height at the shared 12 pt screen top inset; only the Sort action remains.
- Filter: six text tabs split across two independently scrollable horizontal rows. Labels include counts. Rows keep the 8 pt item rhythm and selection uses bold text plus a 2 pt yellow underline, not a filled box.
- List start: no standalone `7개 클립` row. The first clip begins 8 pt below the filter grid.
- Clip row: title, source, optional thumbnail, independent menu. No type label, state label, tag line, or time.
- Media absence: text-only, with no fabricated image.

## Tag anatomy

- Inbox: tags hidden.
- Detail: tags remain in the existing organization row.
- Add/Edit: one summary row opens the tag editor.
- Tag editor and New Folder: the same two independently scrollable underline-based text rows as the main filter; no six-item visual cap.
- Search categories: reuse the same two independently scrollable text rows. Recent searches use flat rows.

## Root alignment

Inbox, Folders, Add, Search, and Settings use the same `ScreenHeader` fixed height. `Add` uses the title `추가` to match the tab label. Presence of trailing buttons must not change the title's vertical center.

## Settings

Remove the app-icon preview section. The destructive data action follows the final settings group with the shared 24 pt section gap.

## Workflow sheets

- Default to a 68% detent, selected from simulator inspection so both tag-editor and card-menu primary actions stay visible without a full-height empty lower region.
- Preserve the large detent for long edit forms and manual expansion.
- Apply 20 pt content insets above the header and after the final action.
- Keep the drag indicator visible and the same warm canvas as the app.

## Acceptance checks

- No clipped filter label at 402 pt.
- No visible gap created by a count-only row.
- Inbox rows expose title, source, optional image, and menu only.
- Tag values are absent from inbox rows and present in detail.
- All five root titles share the same top/baseline position.
- Filter interaction works without a filter icon or filter sheet.
- Short workflow sheets do not open as mostly empty full-height canvases, and their headers do not crowd the grabber.
