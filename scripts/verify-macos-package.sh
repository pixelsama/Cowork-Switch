#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
TMP_DIR="$ROOT_DIR/.tmp/verify-macos"
ALLOW_UNNOTARIZED="${ALLOW_UNNOTARIZED:-0}"

require_file() {
  [[ -f "$1" ]] || {
    printf '[verify-macos] ERROR: Missing file: %s\n' "$1" >&2
    exit 1
  }
}

latest_zip="$(find "$RELEASE_DIR" -maxdepth 1 -name 'ClaudeGatewayTray-*-arm64-mac.zip' | sort | tail -n 1)"
latest_dmg="$(find "$RELEASE_DIR" -maxdepth 1 -name 'ClaudeGatewayTray-*-arm64-mac.dmg' | sort | tail -n 1)"

require_file "$latest_zip"
require_file "$latest_dmg"

check_spctl_status() {
  local target_path="$1"
  local output

  output="$(spctl -a -vv "$target_path" 2>&1 || true)"
  printf '%s\n' "$output"

  if [[ "$ALLOW_UNNOTARIZED" == "1" ]]; then
    return
  fi

  printf '%s\n' "$output" | grep -q "source=Notarized Developer ID" || {
    printf '[verify-macos] ERROR: Expected notarized artifact, got:\n%s\n' "$output" >&2
    exit 1
  }
}

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/zip" "$TMP_DIR/dmg"

unzip -q "$latest_zip" -d "$TMP_DIR/zip"
codesign -dvv "$TMP_DIR/zip/ClaudeGatewayTray.app"
check_spctl_status "$TMP_DIR/zip/ClaudeGatewayTray.app"

hdiutil attach "$latest_dmg" -mountpoint "$TMP_DIR/dmg/mount" -nobrowse >/dev/null
codesign -dvv "$TMP_DIR/dmg/mount/ClaudeGatewayTray.app"
check_spctl_status "$TMP_DIR/dmg/mount/ClaudeGatewayTray.app"
hdiutil detach "$TMP_DIR/dmg/mount" >/dev/null

printf '[verify-macos] Verified:\n'
printf '[verify-macos]   %s\n' "$latest_zip"
printf '[verify-macos]   %s\n' "$latest_dmg"
