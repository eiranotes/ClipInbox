# App Store Release Checklist

## Proven in the repository

- Native SwiftUI app and embedded Share Extension build together.
- App and extension bundle IDs are declared under Apple Developer Team `83BB7YWQHU`.
- App Group entitlement `group.app.clipinbox.ClipInbox` matches both targets.
- App icon asset exists at 1024 px.
- iPhone and iPad orientation declarations are complete.
- Korean, English, and Japanese app resources are bundled.
- Face ID purpose text is localized.
- App Lock defaults to off.
- Share capture defaults to immediate save.
- Share capture can be changed to folder-and-note review.
- Privacy manifests exist in both executables. The app declares its UserDefaults required-reason access; the file-backed extension currently declares no required-reason API categories.
- No tracking domains or collected-data types are declared by the current local-only implementation.
- JSON export/import and delete-all controls exist.

## Must be completed outside the repository

- Confirm `app.clipinbox.ClipInbox`, the extension ID, and the App Group are registered in the distribution team account.
- Create or confirm App Store Connect app record and SKU.
- Provide an owned HTTPS Privacy Policy URL. This is required for iOS apps.
- Provide an owned HTTPS Support URL.
- Replace `support@clipinbox.local` with an owned, monitored email address.
- Confirm the seller name and copyright text.
- Complete age rating, export compliance, content rights, and availability.
- Complete App Privacy answers so they match the local-only behavior and bundled privacy manifests.
- Verify the distribution provisioning profiles include the same App Group for both executables.
- Increment `CURRENT_PROJECT_VERSION` for every uploaded build.
- Decide whether `MARKETING_VERSION 0.3.0` is the public release version or should become `1.0.0`.
- Archive with the Release configuration, run Xcode validation, and upload from the account holder's signed environment.
- Test Safari URL, plain text, and Photos image sharing on a physical device before submission.
- Test Face ID after enabling App Lock on a physical Face ID device.

## Metadata and creative

- Paste the three localized metadata sets from `ASO_COPY.md`.
- Verify keyword byte counts in App Store Connect; Korean and Japanese are byte-limited.
- Upload one to ten real UI screenshots per localization. Put the strongest one to three first because they can appear in search results.
- Use an accepted 6.9-inch screenshot size. Current accepted portrait sizes include 1260 x 2736, 1290 x 2796, and 1320 x 2868.
- Do not state prices in the description.
- Do not put search keywords into promotional text merely for ranking.

## Final binary checks

- [x] `scripts/verify_ios_release.sh` regenerates the project and rejects Xcode project drift.
- [x] Simulator build and all 30 unit tests pass with DerivedData on the local disk and index store disabled.
- [x] Unsigned generic iPhoneOS Release archive passes and contains the embedded `ClipInboxShare.appex`.
- [x] Both `PrivacyInfo.xcprivacy` files are valid and present in the archived bundle.
- [x] Korean, English, and Japanese `Localizable.strings` are present in both app and extension bundles.
- [ ] Distribution-signed archive passes strict App Group entitlement checks for both executables.
- [ ] Xcode Validate App and upload pass for the release build number.
- [ ] No placeholder `.local` email or placeholder HTTPS URL remains in product UI or submitted metadata.

Run the strict external gate against the signed archive as documented in `docs/runbooks/RELEASE_VALIDATION.md`.
