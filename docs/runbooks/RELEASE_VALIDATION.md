# Release Validation Runbook

## Local and CI gate

Run from the repository root:

```sh
scripts/verify_ios_release.sh
```

The script regenerates the Xcode project, rejects project drift, runs the native XCTest suite on an available iPhone simulator, creates an unsigned generic-device Release archive, and verifies:

- expected app and Share Extension bundle identifiers;
- embedded `ClipInboxShare.appex`;
- matching source App Group entitlements;
- app and extension `PrivacyInfo.xcprivacy` files;
- Korean, English, and Japanese resources in both bundles.

DerivedData and the archive default to the local user Library, not the external repository volume. CI runs the same command from `.github/workflows/ios-ci.yml`.

## Distribution-signed gate

Run in an Apple Developer account environment with distribution certificates and provisioning profiles available:

1. Register the app ID, extension ID, and `group.app.clipinbox.ClipInbox` in the same team.
2. Confirm both distribution profiles contain the App Group.
3. Create a Release archive without `CODE_SIGNING_ALLOWED=NO`.
4. Inspect or export the archive, then run:

```sh
RUN_TESTS=0 \
RUN_UNSIGNED_ARCHIVE=0 \
ARCHIVE_PATH=/absolute/path/to/ClipInbox.xcarchive \
REQUIRE_SIGNED_ARCHIVE=1 \
REQUIRE_OWNED_METADATA=1 \
scripts/verify_ios_release.sh
```

5. Run Xcode Validate App before upload and record the validation result with the build number.

## Physical-device matrix

Record pass/fail, device, OS, app build, and evidence for each case:

| Case | Required evidence |
| --- | --- |
| Safari URL quick save | Extension success, return to Safari, exactly one imported link |
| Safari URL review save | Folder/memo retained and exactly one import |
| Plain text share | Text clip content and source preserved |
| Photos image share | Original supported bytes/dimensions preserved and preview opens |
| Queue retry | Same payload UUID does not duplicate |
| App Lock | Enable, background privacy cover, Face ID success and failure |
| Recovery | Corrupt current snapshot restores previous and preserves quarantine |
| Delete Undo | Restore within five seconds and persist after relaunch |

## External release blockers

Repository verification cannot supply or approve:

- an owned HTTPS Privacy Policy URL and Support URL;
- an owned monitored support email;
- App Store Connect metadata, privacy answers, screenshots, and account agreements;
- distribution signing, Xcode validation/upload, and physical-device evidence.

Do not mark the release green until these items and the local/CI gate all pass for the same version and build.
