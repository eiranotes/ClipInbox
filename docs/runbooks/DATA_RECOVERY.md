# Data Recovery Runbook

## Scope

Use this runbook when Clip Inbox reports that the local library was recovered, cannot be opened, or was created by a newer app version. The app is local-only: recovery operates on the device snapshot files and does not contact a server.

## Snapshot contract

- `clip-inbox-data.json` is the current version-2 snapshot.
- `clip-inbox-data.previous.json` is the last known-good snapshot retained before a successful replacement.
- Invalid current files are moved to a timestamped quarantine file instead of being overwritten.
- Images are separate original files and are not embedded in JSON backup exports.

## User-visible outcomes

1. Valid current snapshot: open normally.
2. Invalid current snapshot plus valid previous snapshot: restore the previous snapshot and keep a persistent recovery notice.
3. Unsupported future snapshot version: block the library and require a compatible app update; do not rewrite the file.
4. No valid current or previous snapshot: block normal use and preserve the quarantined input for diagnosis.

## Operator procedure

1. Record the app version, build number, device OS, and exact user-visible message.
2. Do not ask the user to reinstall or delete the app before preserving the app container.
3. Export JSON from Settings if the app still opens, noting that original images and pending Share payloads are excluded.
4. On a development device, copy the Application Support directory and App Group container before testing recovery.
5. Validate the JSON with `plutil` only if it is a plist; use a JSON parser for snapshot files. Never hand-edit the only copy.
6. Reproduce with copies of the current and previous snapshots. Confirm the original invalid file remains quarantined.
7. If the snapshot version is newer than the installed app supports, update the app rather than downgrading the data.

## Success criteria

- No invalid input is silently discarded.
- Recovery never reports success before the restored snapshot is durably written.
- A failed mutation leaves both the in-memory and on-disk library unchanged.
- Original files and quarantine evidence are preserved until the user explicitly deletes all local data.
