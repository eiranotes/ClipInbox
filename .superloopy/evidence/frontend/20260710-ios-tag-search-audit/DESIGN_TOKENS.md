# Design Token Evidence

Source of truth: `DESIGN.md`

## Applied tokens

- Selection layout: 5 columns, 2 rows, 8pt gap, 44pt touch target.
- Selection label behavior: equal cell width, one line, 0.72 minimum scale, 2pt active underline.
- Inbox media: 80x64pt thumbnail inside a fixed 68pt content region.
- Compact result media: 64x48pt thumbnail inside a fixed 48pt content region.
- Search focus: default focus plus an 80ms next-runloop handoff.
- Surface system: warm app canvas, divider-first rows, no card shadow, yellow reserved for active selection.

## Compliance

The design-system compliance script reported 13 declared colors and zero violations across the changed Swift token, component, clip-row, search, tag-editor, and folder-tag files.
