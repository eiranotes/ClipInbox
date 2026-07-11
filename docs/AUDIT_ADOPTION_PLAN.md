# Clip Inbox Audit Adoption Plan

## Goal

Apply the 2026-07-11 A-to-Z audit without changing Clip Inbox into a general-purpose knowledge manager. The product remains a native, local-only, account-free Share-to-Inbox utility whose primary flow is capture first and organize later.

## Product boundaries to preserve

- `ios/` remains the only production implementation.
- Share Extension quick/review capture remains the primary input path.
- The five-tab shell, list-first hierarchy, warm productive-minimal design, 5x2 direct selectors, and normal-size one-viewport detail remain intact.
- Original supported image bytes remain the default storage contract.
- Direct link opening remains the default, with confirmation as an explicit preference.
- No account, server, analytics SDK, subscription UI, social features, background clipboard monitoring, AI scoring, or gamification enters the 1.0 scope.

## Adopt now

- Snapshot corruption detection, previous-backup recovery, version gating, and quarantine.
- Durable mutations with rollback and no false-success UI.
- Share image file ingestion, limits, timeout/cancellation, queue ordering, quarantine, idempotency, and quota.
- App Lock fail-closed behavior and app-switcher privacy cover.
- Removal of the demo Add flow in favor of real URL, text, photo, and memo capture.
- Honest first-run empty state, concise Share Extension guidance, actionable error/recovery states, and delete Undo.
- Dynamic Type, VoiceOver, 44pt hit targets, and accessibility-only layout variants that preserve the standard 5x2 and one-viewport contracts.
- Release build, signed archive, privacy manifest, extension embedding, support/privacy URL, and physical-device gates.

## Adopt with reduced scope

- Introduce a small repository boundary and typed errors, not a full framework or target explosion.
- Add immediate delete Undo first; add a 30-day Trash only after the data transaction layer is proven.
- Add storage totals, largest originals, and cleanup previews before any automatic retention policy.
- Start duplicate handling with exact/canonical URL matches; defer fuzzy text and perceptual image matching.
- Measure the current snapshot backend before considering SQLite or SwiftData.
- Keep iPad support, but change navigation structure only when split-view QA proves a concrete problem.

## Explicitly deferred or rejected for 1.0

- Replacing Folders with a broad Library information architecture.
- Replacing the 5x2 direct selector with a general filter sheet at standard text sizes.
- Turning normal detail screens into long reading pages.
- Automatic image recompression that breaks original-byte preservation.
- Immediate UUID-wide model migration, SQLite/SwiftData/GRDB migration, encrypted vaults, or password archives.
- OCR, semantic search, CloudKit, Mac/Android/web products, widgets, team collaboration, server AI, advertising, and subscription-first monetization.

## Sequential phases

### Phase 0: Baseline and scope lock

Status: complete on 2026-07-11.

- Decouple tests from production sample data using explicit version-2 fixtures.
- Record audit adoption boundaries, risks, verification, and documentation responsibilities.

Exit: existing build and tests pass with no product behavior change.

### Phase 1: Data-safe core

- Add a repository boundary, typed bootstrap/commit errors, version gate, current/previous/quarantine recovery, and rollback-backed mutations.
- Fresh install becomes an empty clip library rather than seeded production samples.

Exit: corrupt, future-version, and failing-write fixtures pass; false-success count is zero.

### Phase 2: Capture and privacy

- Harden Share image/provider/queue behavior, make App Lock fail closed, add privacy cover, and replace demo Add with real capture.

Exit: deterministic provider termination, no duplicate queue import, no auth-unavailable unlock, and no hardcoded Add payload.

### Phase 3: Trust UX and accessibility

- Add first-run/empty/recovery states, delete Undo, storage/export disclosure, semantic typography, VoiceOver, and accessibility layout variants.

Exit: core flows pass in Korean, English, and Japanese across light/dark and accessibility text sizes without weakening the standard layout.

### Phase 4: Release gate

- Add CI/release validation, signed archive checks, operational runbooks, policy URLs, metadata, and physical-device evidence.

Exit: P0 is zero and the signed app/extension/privacy/recovery matrix is green.

## Verification contract

Each phase requires focused tests first, then the full simulator suite and embedded Share Extension validation. UI phases additionally require token compliance, anti-slop review, simulator screenshots, input/state smoke tests, and an evidence artifact under `.superloopy/evidence/`.
