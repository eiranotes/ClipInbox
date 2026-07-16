# App Store Release Checklist

## Proven in the repository

- Native SwiftUI app and embedded Share Extension build together.
- The iPhone-only app uses `app.eiradev.ClipInbox`; the Share Extension uses `app.eiradev.ClipInbox.Share`, both under Apple Developer Team `83BB7YWQHU`.
- App Group entitlement `group.app.eiradev.ClipInbox` matches both targets.
- App icon asset exists at 1024 px.
- Share Extension icon is compiled from the same yellow paperclip mark and is visible in the iOS share sheet.
- Both production targets are restricted to iPhone (`TARGETED_DEVICE_FAMILY = 1`).
- Korean, English, and Japanese app resources are bundled.
- Face ID purpose text is localized.
- App Lock defaults to off.
- Share capture defaults to immediate save.
- Share capture can be changed to folder-and-note review.
- Privacy manifests exist in both executables. The app declares its UserDefaults required-reason access; the file-backed extension currently declares no required-reason API categories.
- No tracking domains or collected-data types are declared by the current local-only implementation.
- JSON export/import and delete-all controls exist.
- The in-app support email is `eiradev000@gmail.com`.
- Trilingual Notion-ready Terms, Support, and Privacy copy exists under `docs/app-store/notion/`.
- Published HTTPS Privacy Policy, Support, and Terms of Use URLs are recorded in `ASO_COPY.md` and open from localized Settings rows.

## Must be completed outside the repository

- Confirm `app.eiradev.ClipInbox`, the extension ID, and the App Group are registered in the distribution team account.
- Create or confirm App Store Connect app record and SKU.
- Choose the primary category and optional secondary category that best describe the app.
- Enter the published Privacy Policy and Support URLs in App Store Connect.
- Confirm the seller name and copyright text.
- Complete age rating, export compliance, content rights, and availability.
- Determine the export-compliance answer for the app's use of system HTTPS; `ITSAppUsesNonExemptEncryption` is not currently declared in the generated Info.plist.
- Complete App Privacy answers so they match the local-only behavior and bundled privacy manifests.
- Enter the required App Review contact name, email, and phone number. Add review notes explaining that no login is required, App Lock is off by default, and Share Extension testing starts from another app's share sheet.
- If distributing in the EU, complete the App Store Connect trader-status declaration and any required public contact details.
- Verify the distribution provisioning profiles include the same App Group for both executables.
- [x] Use `MARKETING_VERSION 1.0.0` and `CURRENT_PROJECT_VERSION 1` for the first upload; increment the build number for every subsequent upload.
- Archive with the Release configuration, run Xcode validation, and upload from the account holder's signed environment.
- Select the uploaded build, choose the version release option, add it to the review submission, and submit it.
- Test Safari URL, plain text, and Photos image sharing on a physical device before submission.
- Test Face ID after enabling App Lock on a physical Face ID device.
- Optionally publish accurate iPhone Accessibility Nutrition Labels after completing a common-task accessibility audit; Apple currently describes these labels as voluntary but planned to become mandatory later.

## Upfront paid app at target ₩1,900

- [x] Keep the binary fully usable after download with no StoreKit product, subscription, paywall, or restore-purchase UI.
- [ ] Account Holder accepts the latest Paid Apps Agreement and completes required banking and tax information.
- [ ] In App Store Connect, open Monetization > Pricing and Availability > Add Pricing.
- [ ] Choose South Korea as the base country or region and confirm `₩1,900` exists as an exact current price point. If it does not, choose the nearest intentional Apple price point and update the launch plan.
- [ ] Review Apple's automatically generated prices for other storefronts; override only regions the account holder intends to manage manually.
- [ ] Set the tax category, public availability regions, and price start date before submitting for review.
- [ ] Keep exact price copy out of descriptions and screenshots so future storefront/tax changes do not stale the creative.

## Metadata and creative

- Paste the three localized metadata sets from `ASO_COPY.md`.
- Verify keyword byte counts in App Store Connect; Korean and Japanese are byte-limited.
- Upload the finalized seven-frame set per localization. Put the strongest one to three first because they can appear in search results.
- Use one of the release-approved portrait sizes: 1242 x 2688 or 1284 x 2778. This release uses 1284 x 2778.
- Do not state prices in the description.
- Do not put search keywords into promotional text merely for ranking.
- Final Korean, English, and Japanese upload-ready screenshots are versioned in `docs/app-store/generated/final-aso/{ko-KR,en-US,ja-JP}/`: seven opaque 8-bit sRGB 1284 x 2778 PNGs per locale. Their final simulator sources live in `final-aso-raw/`; intermediate generated candidates and contact sheets remain outside the upload directory.

## Final binary checks

- [x] `scripts/verify_ios_release.sh` regenerates the project and rejects Xcode project drift.
- [x] Simulator build and all 59 unit tests pass with DerivedData on the local disk and index store disabled.
- [x] Unsigned generic iPhoneOS Release archive passes and contains the embedded `ClipInboxShare.appex`.
- [x] Both `PrivacyInfo.xcprivacy` files are valid and present in the archived bundle.
- [x] Korean, English, and Japanese `Localizable.strings` are present in both app and extension bundles.
- [ ] Distribution-signed archive passes strict App Group entitlement checks for both executables.
- [ ] Xcode Validate App and upload pass for the release build number.
- [x] No placeholder HTTPS URL remains in the repository metadata.

Run the strict external gate against the signed archive as documented in `docs/runbooks/RELEASE_VALIDATION.md`.
