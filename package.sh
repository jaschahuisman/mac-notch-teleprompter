#!/bin/bash
# Builds a universal (Apple Silicon + Intel) release .app and zips it for distribution.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Notch Teleprompter"
EXEC_NAME="NotchTeleprompter"
APP_DIR="dist/$APP_NAME.app"
ZIP_PATH="dist/NotchTeleprompter.zip"

echo "▶ Building arm64…"
swift build -c release --arch arm64
echo "▶ Building x86_64…"
swift build -c release --arch x86_64

ARM=".build/arm64-apple-macosx/release/$EXEC_NAME"
X86=".build/x86_64-apple-macosx/release/$EXEC_NAME"

echo "▶ Assembling universal app bundle…"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
lipo -create -output "$APP_DIR/Contents/MacOS/$EXEC_NAME" "$ARM" "$X86"
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
printf 'APPL????' > "$APP_DIR/Contents/PkgInfo"

echo "▶ Ad-hoc code signing…"
codesign --force --deep --sign - \
  --options runtime --entitlements Resources/entitlements.plist \
  "$APP_DIR" 2>/dev/null || codesign --force --deep --sign - "$APP_DIR"

echo "▶ Zipping…"
rm -f "$ZIP_PATH"
# ditto preserves the bundle + resource forks so the .app stays launchable after unzip.
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "✓ Universal slices: $(lipo -archs "$APP_DIR/Contents/MacOS/$EXEC_NAME")"
echo "✓ $ZIP_PATH"
