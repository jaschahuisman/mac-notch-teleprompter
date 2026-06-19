#!/bin/bash
# Builds NotchTeleprompter and assembles a runnable .app bundle.
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP_NAME="Notch Teleprompter"
EXEC_NAME="NotchTeleprompter"
BUILD_DIR=".build/$CONFIG"
APP_DIR="dist/$APP_NAME.app"

echo "▶ Building ($CONFIG)…"
swift build -c "$CONFIG"

echo "▶ Assembling app bundle…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/$EXEC_NAME" "$APP_DIR/Contents/MacOS/$EXEC_NAME"
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

echo "▶ Ad-hoc code signing (so camera/mic permission persists)…"
codesign --force --deep --sign - \
  --options runtime \
  --entitlements Resources/entitlements.plist \
  "$APP_DIR" 2>/dev/null || codesign --force --deep --sign - "$APP_DIR"

echo "✓ Built: $APP_DIR"
echo "  Run with:  open \"$APP_DIR\""
