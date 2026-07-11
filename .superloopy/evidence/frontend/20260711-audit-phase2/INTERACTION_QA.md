# Interaction QA

Environment: iPhone 17 Pro, iOS 26.5 Simulator.

- Add tab exposes Link, Text, Photo, and Memo as labelled, selectable controls.
- Entered `https://example.com/phase2-proof`; the URL field accepted the value and the save CTA committed a real link to `기본 폴더`.
- After durable save, the CTA became disabled, the saved toast appeared, and `새로 저장하기` reset the form.
- Photo selection state exposes a native PhotosPicker CTA plus the 50 MB / 100 megapixel original-file policy.
- App switcher shows an opaque Clip Inbox card instead of the Add form or clip list.
- Accessibility inspection confirmed labels for every Add type, field, destination/tag action, save action, and bottom tab.
- During QA, duplicate copy rendered as `기본 폴더 폴더`; the localized format was corrected to quote the destination without appending another noun.
