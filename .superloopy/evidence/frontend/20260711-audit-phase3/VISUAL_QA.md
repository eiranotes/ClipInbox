# Visual QA

Environment: clean temporary iPhone 17 Pro, iOS 26.5 Simulator. The temporary device was deleted after capture.

- `first-run.png`: standard-size empty Inbox keeps the existing 5x2 selector and shows the complete three-step guide and Add CTA without overflow.
- `accessibility-first-run.png`: Accessibility Extra Large prioritizes the first-capture guide before filters; content grows naturally and the bottom navigation stays fixed.
- `accessibility-selector-rows.png`: the same size category renders filter choices as full-width readable rows instead of shrinking the 5x2 cells.
- Standard-size 5x2 behavior was not changed.
- The accessibility variant intentionally gives up the one-screen density contract rather than shrinking text or truncating options.
