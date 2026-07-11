# Verification — Trash, Feedback, and Onboarding

- XcodeGen regenerated `ios/ClipInbox.xcodeproj` from `ios/project.yml`.
- `xcodebuild test` passed 31 of 31 native XCTest cases on the iPhone 17 Pro iOS 26.5 simulator with zero failures or skips.
- The same test build validated the embedded `ClipInboxShare.appex`.
- Design-system compliance passed with 25 declared colors and zero violations.
- Simulator interaction covered Settings bottom clearance, compact Add spacing, active-only folder counts, empty and populated Trash states, restore/empty controls, and all three onboarding pages.
- A real Safari Share flow showed the yellow `Clip Inbox에 저장됨` card and returned to Safari; the App Group queue was restored to zero pending test payloads afterward.
- Public-API testing confirmed that a Share Extension cannot launch the containing app. The unsupported option, URL scheme, and no-op launch path were removed.
