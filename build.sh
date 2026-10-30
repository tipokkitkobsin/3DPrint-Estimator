#!/bin/bash
set -euo pipefail
APP_NAME="3DPrint Estimator"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
EXEC_NAME="PrintCostCalc"
SDK="$(xcrun --show-sdk-path)"

echo "Cleaning previous build..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "Compiling Swift sources..."
find "$ROOT/Sources" -name '*.swift' -print0 | xargs -0 \
  swiftc -sdk "$SDK" -target arm64-apple-macosx14.0 -O -parse-as-library \
  -o "$APP/Contents/MacOS/$EXEC_NAME"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "Ad-hoc code signing..."
xattr -cr "$APP" 2>/dev/null || true
rm -rf "$APP/Contents/_CodeSignature"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
if ! codesign --verify "$APP" >/dev/null 2>&1; then
  # iCloud Drive sometimes re-tags files mid-sign; clear and retry once.
  xattr -cr "$APP" 2>/dev/null || true
  rm -rf "$APP/Contents/_CodeSignature"
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "Built: $APP"
