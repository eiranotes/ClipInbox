#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/ios"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/ClipInbox-ReleaseGate}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$DERIVED_DATA_PATH/ClipInbox.xcarchive}"
RUN_TESTS="${RUN_TESTS:-1}"
RUN_UNSIGNED_ARCHIVE="${RUN_UNSIGNED_ARCHIVE:-1}"
REQUIRE_SIGNED_ARCHIVE="${REQUIRE_SIGNED_ARCHIVE:-0}"
REQUIRE_OWNED_METADATA="${REQUIRE_OWNED_METADATA:-0}"
EXPECTED_APP_ID="app.eiradev.ClipInbox"
EXPECTED_EXTENSION_ID="app.eiradev.ClipInbox.Share"
EXPECTED_APP_GROUP="group.app.eiradev.ClipInbox"

log() {
  printf '[release-gate] %s\n' "$*"
}

fail() {
  printf '[release-gate] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command is missing: $1"
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

require_file() {
  [[ -f "$1" ]] || fail "required file is missing: $1"
}

require_command xcodebuild
require_command xcodegen
require_command xcrun
require_command python3
require_command plutil
require_command rg

log "validating source entitlements and privacy manifests"
for plist in \
  "$IOS_DIR/ClipInbox/ClipInbox.entitlements" \
  "$IOS_DIR/ClipShareExtension/ClipInboxShare.entitlements" \
  "$IOS_DIR/ClipInbox/PrivacyInfo.xcprivacy" \
  "$IOS_DIR/ClipShareExtension/PrivacyInfo.xcprivacy"; do
  plutil -lint "$plist" >/dev/null
done

app_group="$(plist_value "$IOS_DIR/ClipInbox/ClipInbox.entitlements" 'com.apple.security.application-groups:0')"
extension_group="$(plist_value "$IOS_DIR/ClipShareExtension/ClipInboxShare.entitlements" 'com.apple.security.application-groups:0')"
[[ "$app_group" == "$EXPECTED_APP_GROUP" ]] || fail "unexpected app App Group: $app_group"
[[ "$extension_group" == "$EXPECTED_APP_GROUP" ]] || fail "unexpected extension App Group: $extension_group"

log "regenerating the Xcode project"
(cd "$IOS_DIR" && xcodegen generate --spec project.yml)
if ! git -C "$ROOT_DIR" diff --quiet -- ios/ClipInbox.xcodeproj; then
  fail "ios/ClipInbox.xcodeproj is not synchronized with ios/project.yml"
fi

if [[ "$RUN_TESTS" == "1" ]]; then
  simulator_id="${SIMULATOR_ID:-}"
  if [[ -z "$simulator_id" ]]; then
    simulator_id="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
data = json.load(sys.stdin)
devices = [device for runtime in data.get("devices", {}).values() for device in runtime]
iphones = [
    device for device in devices
    if device.get("isAvailable") and ".iPhone-" in device.get("deviceTypeIdentifier", "")
]
booted = next((device for device in iphones if device.get("state") == "Booted"), None)
selected = booted or (iphones[0] if iphones else None)
if selected:
    print(selected["udid"])
')"
  fi
  [[ -n "$simulator_id" ]] || fail "no available iPhone simulator was found"

  log "running the simulator test suite on $simulator_id"
  xcodebuild \
    -quiet \
    -project "$IOS_DIR/ClipInbox.xcodeproj" \
    -scheme ClipInbox \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    COMPILER_INDEX_STORE_ENABLE=NO \
    test
fi

if [[ "$RUN_UNSIGNED_ARCHIVE" == "1" ]]; then
  log "creating an unsigned Release archive at $ARCHIVE_PATH"
  rm -rf "$ARCHIVE_PATH"
  xcodebuild \
    -quiet \
    -project "$IOS_DIR/ClipInbox.xcodeproj" \
    -scheme ClipInbox \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    archive
fi

[[ -d "$ARCHIVE_PATH" ]] || fail "archive is unavailable: $ARCHIVE_PATH"
app_path="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -type d -name '*.app' -print -quit)"
[[ -n "$app_path" ]] || fail "archived app bundle was not found"
extension_path="$(find "$app_path/PlugIns" -maxdepth 1 -type d -name '*.appex' -print -quit)"
[[ -n "$extension_path" ]] || fail "embedded Share Extension was not found"

log "inspecting the archived app and Share Extension"
app_id="$(plist_value "$app_path/Info.plist" CFBundleIdentifier)"
extension_id="$(plist_value "$extension_path/Info.plist" CFBundleIdentifier)"
[[ "$app_id" == "$EXPECTED_APP_ID" ]] || fail "unexpected app bundle identifier: $app_id"
[[ "$extension_id" == "$EXPECTED_EXTENSION_ID" ]] || fail "unexpected extension bundle identifier: $extension_id"

for manifest in "$app_path/PrivacyInfo.xcprivacy" "$extension_path/PrivacyInfo.xcprivacy"; do
  require_file "$manifest"
  plutil -lint "$manifest" >/dev/null
done

for locale in ko en ja; do
  require_file "$app_path/$locale.lproj/Localizable.strings"
  require_file "$extension_path/$locale.lproj/Localizable.strings"
done

if codesign --verify --deep --strict "$app_path" >/dev/null 2>&1; then
  log "signed archive detected; checking signed App Group entitlements"
  app_entitlements="$(codesign -d --entitlements :- "$app_path" 2>/dev/null || true)"
  extension_entitlements="$(codesign -d --entitlements :- "$extension_path" 2>/dev/null || true)"
  grep -q "$EXPECTED_APP_GROUP" <<<"$app_entitlements" || fail "signed app is missing the expected App Group"
  grep -q "$EXPECTED_APP_GROUP" <<<"$extension_entitlements" || fail "signed extension is missing the expected App Group"
else
  if [[ "$REQUIRE_SIGNED_ARCHIVE" == "1" ]]; then
    fail "a distribution-signed archive is required but the inspected archive is unsigned"
  fi
  log "external gate pending: distribution-signed archive and provisioning entitlement validation"
fi

placeholder_matches="$(rg -n 'support@clipinbox\.local|<HTTPS_[A-Z_]+>' "$IOS_DIR" "$ROOT_DIR/docs/app-store" || true)"
if [[ -n "$placeholder_matches" ]]; then
  if [[ "$REQUIRE_OWNED_METADATA" == "1" ]]; then
    printf '%s\n' "$placeholder_matches" >&2
    fail "owned support/privacy metadata is required but placeholders remain"
  fi
  log "external gate pending: published HTTPS policy/support URLs"
fi

log "local release gate passed"
log "archive: $ARCHIVE_PATH"
log "remaining external gates: signed validation/upload and physical-device Share/App Lock checks"
