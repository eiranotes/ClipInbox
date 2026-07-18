# Attachment Detail Visual QA

- `detail-multi-image.png`: normal-size Korean detail showing multiple gallery pages, a relative `2시간 전` label, the complete three-item attachment list, and the copy-all action.
- `detail-a11y-dark.png`: audit discovery capture at accessibility XXXL, dark appearance, and Increased Contrast before the bottom-tab label bound was added.
- `detail-a11y-dark-fixed.png`: the same stress state after the fix; bottom-tab labels remain inside their cells without changing the content screen's Dynamic Type behavior.

The simulator library, theme, contrast, and content-size settings were restored after capture. The macOS accessibility driver could capture but could not inject touches into the embedded iOS screen, so attachment-selection/copy behavior is verified by XCTest rather than claimed as automated touch evidence.
