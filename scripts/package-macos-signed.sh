#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ClaudeGatewayTray"
APP_BUNDLE_NAME="${APP_NAME}.app"
APP_BUILD_DIR="$ROOT_DIR/dist/$APP_BUNDLE_NAME"
RELEASE_DIR="$ROOT_DIR/release"
TMP_DIR="$ROOT_DIR/.tmp/package-macos"
STAGE_DIR="$TMP_DIR/stage"
APP_STAGE_DIR="$STAGE_DIR/$APP_BUNDLE_NAME"
DMG_STAGE_DIR="$TMP_DIR/dmg-root"
KEYCHAIN_PROFILE="${APPLE_KEYCHAIN_PROFILE:-otakuclaw-notary}"
ZIP_SUBMISSION_PATH="$TMP_DIR/${APP_NAME}-for-notary.zip"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/macos-app/$APP_NAME/Info.plist")"
artifact_prefix="${APP_NAME}-${version}-arm64-mac"
final_zip_path="$RELEASE_DIR/${artifact_prefix}.zip"
final_dmg_path="$RELEASE_DIR/${artifact_prefix}.dmg"
checksums_path="$RELEASE_DIR/checksums-macos.txt"

log() {
  printf '[package-macos] %s\n' "$1"
}

fail() {
  printf '[package-macos] ERROR: %s\n' "$1" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

detect_csc_name() {
  if [[ -n "${CSC_NAME:-}" ]]; then
    printf '%s' "$CSC_NAME"
    return
  fi

  local detected
  detected="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application:/ { print $2; exit }')"

  [[ -n "$detected" ]] || fail "No Developer ID Application identity found. Install the certificate or set CSC_NAME."

  detected="${detected#Developer ID Application: }"
  printf '%s' "$detected"
}

normalize_identity() {
  local common_name="$1"

  if [[ "$common_name" == Developer\ ID\ Application:* ]]; then
    printf '%s' "$common_name"
    return
  fi

  printf 'Developer ID Application: %s' "$common_name"
}

detect_team_id() {
  if [[ -n "${APPLE_TEAM_ID:-}" ]]; then
    printf '%s' "$APPLE_TEAM_ID"
    return
  fi

  local csc_name="$1"
  local parsed
  parsed="$(printf '%s' "$csc_name" | sed -n 's/.*(\([A-Z0-9]\{10,\}\)).*/\1/p')"

  [[ -n "$parsed" ]] || fail "Could not infer APPLE_TEAM_ID from CSC_NAME='$csc_name'. Set APPLE_TEAM_ID explicitly."

  printf '%s' "$parsed"
}

verify_notary_profile() {
  if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
    log "Skipping notarization because SKIP_NOTARIZATION=1."
    return
  fi

  xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1 || fail \
    "Keychain profile '$KEYCHAIN_PROFILE' is unavailable. Store credentials with: xcrun notarytool store-credentials \"$KEYCHAIN_PROFILE\" --apple-id \"<APPLE_ID>\" --team-id \"<TEAM_ID>\" --password \"<APP_SPECIFIC_PASSWORD>\""
}

sign_app_bundle() {
  local identity="$1"

  log "Signing app bundle with identity: $identity"
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$identity" \
    "$APP_STAGE_DIR"
}

create_notary_submission_zip() {
  rm -f "$ZIP_SUBMISSION_PATH"
  ditto -c -k --sequesterRsrc --keepParent "$APP_STAGE_DIR" "$ZIP_SUBMISSION_PATH"
}

submit_for_notarization() {
  local target_path="$1"

  if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
    log "Skipping notarization for $(basename "$target_path")."
    return
  fi

  log "Submitting $(basename "$target_path") for notarization using profile '$KEYCHAIN_PROFILE'."
  xcrun notarytool submit "$target_path" --keychain-profile "$KEYCHAIN_PROFILE" --wait
}

staple_path() {
  local target_path="$1"

  if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
    log "Skipping stapler for $(basename "$target_path")."
    return
  fi

  xcrun stapler staple "$target_path"
  xcrun stapler validate "$target_path"
}

create_final_zip() {
  rm -f "$final_zip_path"
  ditto -c -k --sequesterRsrc --keepParent "$APP_STAGE_DIR" "$final_zip_path"
}

create_dmg() {
  rm -rf "$DMG_STAGE_DIR"
  mkdir -p "$DMG_STAGE_DIR"
  cp -R "$APP_STAGE_DIR" "$DMG_STAGE_DIR/$APP_BUNDLE_NAME"
  ln -s /Applications "$DMG_STAGE_DIR/Applications"
  rm -f "$final_dmg_path"
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGE_DIR" \
    -ov \
    -format UDZO \
    "$final_dmg_path" >/dev/null
}

verify_signed_app() {
  local team_id="$1"

  log "Verifying signed app bundle"
  codesign -dvv "$APP_STAGE_DIR" >/dev/null
  codesign --verify --deep --strict --verbose=2 "$APP_STAGE_DIR"
  spctl -a -vv "$APP_STAGE_DIR" >/dev/null || true

  if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
    spctl_output="$(spctl -a -vv "$APP_STAGE_DIR" 2>&1 || true)"
    printf '%s\n' "$spctl_output" | grep -q "source=Notarized Developer ID" || fail \
      "Expected notarized app. spctl output was: $spctl_output"
  fi

  codesign_output="$(codesign -dvv "$APP_STAGE_DIR" 2>&1 || true)"
  printf '%s\n' "$codesign_output" | grep -q "TeamIdentifier=$team_id" || fail \
    "Expected TeamIdentifier=$team_id in codesign output."
}

write_checksums() {
  (
    cd "$RELEASE_DIR"
    shasum -a 256 "$(basename "$final_zip_path")" "$(basename "$final_dmg_path")" > "$checksums_path"
  )
}

require_command security
require_command codesign
require_command xcrun
require_command ditto
require_command hdiutil
require_command shasum

mkdir -p "$RELEASE_DIR"
rm -rf "$TMP_DIR"
mkdir -p "$STAGE_DIR"

csc_name="$(detect_csc_name)"
full_identity="$(normalize_identity "$csc_name")"
team_id="$(detect_team_id "$csc_name")"

log "Using CSC_NAME=$csc_name"
log "Using APPLE_TEAM_ID=$team_id"
log "Using APPLE_KEYCHAIN_PROFILE=$KEYCHAIN_PROFILE"

verify_notary_profile

log "Building app bundle"
zsh "$ROOT_DIR/scripts/build-macos-app.sh"

rm -rf "$APP_STAGE_DIR"
cp -R "$APP_BUILD_DIR" "$APP_STAGE_DIR"

sign_app_bundle "$full_identity"
create_notary_submission_zip
submit_for_notarization "$ZIP_SUBMISSION_PATH"
staple_path "$APP_STAGE_DIR"
create_final_zip
create_dmg
submit_for_notarization "$final_dmg_path"
staple_path "$final_dmg_path"
verify_signed_app "$team_id"
write_checksums

log "Done."
log "Artifacts:"
log "  $final_zip_path"
log "  $final_dmg_path"
log "  $checksums_path"
