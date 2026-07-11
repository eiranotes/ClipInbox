# Share Queue Runbook

## Scope

Use this runbook when Safari, Photos, or another app reports a successful Clip Inbox share but the clip does not appear, appears twice, or an image cannot be imported.

## Queue contract

- The Share Extension writes payload metadata and supported original image bytes to the shared App Group container.
- The app imports payloads in `createdAt` order.
- Payload UUID is persisted into the imported clip so a failed queue removal cannot create a duplicate on retry.
- Corrupt or expired payloads are quarantined.
- The queue is limited to 200 items, 250 MB, and 30 days.
- Image providers have a 10-second deadline and accept at most 50 MB and 100 megapixels.

## Operator procedure

1. Record source app, payload type, file format, dimensions, byte size, and the localized extension result.
2. Confirm the app and extension use the same App Group entitlement.
3. Preserve the App Group queue directory before retrying or deleting data.
4. Open Clip Inbox once and inspect whether the queue count drops and whether a quarantine notice appears.
5. For duplicate reports, compare the queue payload UUID with the imported clip identity; do not deduplicate by title alone.
6. For image failures, check size/dimension limits and whether the provider supplied a file representation before considering conversion.
7. For timeout reports, reproduce with the same provider and confirm its load operation is cancelled at the deadline.

## Success criteria

- A durable extension save is either imported once or retained/quarantined for diagnosis.
- The app never reports an imported payload before its main snapshot commit succeeds.
- Unsupported, corrupt, oversized, or expired payloads do not block later valid payloads.
- Original supported image bytes remain unchanged through queue storage and import.
