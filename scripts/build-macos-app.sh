#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ClaudeGatewayTray"
APP_SOURCE_DIR="$ROOT_DIR/macos-app/$APP_NAME"
APP_BUILD_DIR="$ROOT_DIR/dist/$APP_NAME.app"
APP_BINARY_DIR="$APP_BUILD_DIR/Contents/MacOS"
APP_RESOURCES_DIR="$APP_BUILD_DIR/Contents/Resources"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

mkdir -p "$APP_BINARY_DIR" "$APP_RESOURCES_DIR"

xcrun swiftc \
  -sdk "$SDK_PATH" \
  -target arm64-apple-macos13.0 \
  -parse-as-library \
  -framework SwiftUI \
  -framework AppKit \
  -framework Foundation \
  "$APP_SOURCE_DIR"/Sources/*.swift \
  -o "$APP_BINARY_DIR/$APP_NAME"

cp "$APP_SOURCE_DIR/Info.plist" "$APP_BUILD_DIR/Contents/Info.plist"
cp -R "$APP_SOURCE_DIR/Resources/." "$APP_RESOURCES_DIR/"
codesign --force --sign - "$APP_BUILD_DIR" >/dev/null 2>&1 || true

echo "Built $APP_BUILD_DIR"
