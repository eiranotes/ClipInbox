# Native Quality Gate

## Design-system compliance

Command:

```sh
node /Users/tofu/.codex-shared/state/plugins/cache/personal/superloopy/0.7.2+codex.20260702112448/skills/superloopy-frontend/scripts/ds-compliance.mjs DESIGN.md ios/ClipInbox/DesignSystem/Tokens.swift ios/ClipInbox/DesignSystem/Components.swift ios/ClipInbox/Views/ClipCardView.swift ios/ClipInbox/Views/SearchView.swift ios/ClipInbox/Views/AddClipView.swift ios/ClipInbox/Views/FoldersView.swift
```

Result: pass. `ok: true`, base spacing 4, 13 declared colors, zero violations.

## Native build and tests

- XcodeGen project regeneration: pass.
- iOS 26.5 iPhone 17 Pro simulator build: pass.
- Embedded `ClipInboxShare.appex` validation: pass.
- XCTest: 3 tests, 0 failures.
- XCTest coverage: default tag filters/search, persisted real recent searches, and core mutations across reload.

Lighthouse is not applicable because the production surface under test is a native SwiftUI application, not a served web build.
