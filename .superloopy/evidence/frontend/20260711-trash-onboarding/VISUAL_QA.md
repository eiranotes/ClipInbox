# Visual QA — Trash, Feedback, and Onboarding

Date: 2026-07-11

Device: iPhone 17 Pro simulator, iOS 26.5

Build: native SwiftUI `ClipInbox` with embedded `ClipInboxShare`

## Gate Results

| Surface | Check | Result | Evidence |
|---|---|---|---|
| Settings | Final destructive action scrolls fully above the persistent bottom navigation | Pass | `settings-delete-visible.png` |
| Add | Four clip types fit one row and the title begins on the compact form rhythm | Pass | `add-compact-type-spacing.png` |
| Trash | 30-day retention panel, deleted count, restore action, and empty action remain readable without clipping | Pass | `trash-populated.png` |
| Onboarding | Generated illustration, heading, body, page indicator, and CTA fit one phone viewport; Settings re-entry clears the bottom navigation | Pass | `onboarding-1.png`, `onboarding-final.png` |
| Share success | Real Safari Share flow displays the exact yellow success card with near-black content, then returns to Safari | Pass | `share-success-yellow.png` |

## Interaction Checks

- Folder counts and Inbox/Search results exclude trashed clips.
- Restore returns a clip to its original folder; Empty Trash permanently removes entries and image assets.
- The Trash panel states that items are deleted automatically after 30 days.
- Manual Add accepts the same URL more than once and shows no duplicate-warning branch.
- Selected controls, app feedback, deletion Undo, and Share success reuse `color.accent.yellow` with `color.text.onAccent`.
- First-run onboarding and Settings re-entry both traverse all three pages with native localized copy and generated text-free illustrations.

## Anti-Slop Review

- No nested card stacks or excessive rounded containers were introduced.
- One yellow accent role is used consistently; green is limited to compact metadata.
- Onboarding contains one focal illustration and one action per page, without fake screenshot text or decorative gradients.
- Existing Pretendard typography, list density, hairline separators, compact radii, and bottom navigation hierarchy are preserved.

## Platform Boundary

iOS Share extensions return to their host app after completion. The tested automatic containing-app launch option was removed because public Share Extension APIs do not support it; no misleading no-op setting remains.
