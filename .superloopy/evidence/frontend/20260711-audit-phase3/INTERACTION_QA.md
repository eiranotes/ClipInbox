# Interaction QA

- Fresh install starts with zero clips and a three-step Share-to-Inbox guide plus a real `직접 추가` CTA.
- `deleteClip` commits removal, exposes a five-second pending deletion, and `undoDelete` re-commits the original clip at its prior index.
- Original image deletion is delayed until the Undo window closes.
- Recovery and quarantined-queue messages use persistent top banners with explicit dismiss controls.
- Storage summary separates snapshot bytes, original image bytes/count, pending payload bytes/count, and quarantined count.
- Backup copy explicitly states that JSON is unencrypted and excludes original images, recent searches, the tag catalog, and link-opening preference.
- XCTest verifies undo persistence and storage-summary accounting.
