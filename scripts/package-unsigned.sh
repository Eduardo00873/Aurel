#!/bin/bash
set -euo pipefail

# Builds an ad-hoc signed Aurel.app and packages it as a drag-to-install DMG for web
# downloads. Ad-hoc signing needs no Apple Developer account, but macOS Gatekeeper
# will ask the user to approve the app on first launch (see README › Install).
# For signed and notarized releases use scripts/build-dmg.sh instead.
#
# Requires only Xcode. Output: build/Aurel.dmg (stable name, so releases/latest/download/Aurel.dmg always works)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED="$BUILD_DIR/DerivedData"
STAGE="$BUILD_DIR/dmg"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$STAGE"

echo "==> Building Release..."
xcodebuild build \
    -project "$PROJECT_DIR/FineTune.xcodeproj" \
    -scheme FineTune \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
    -quiet

APP="$DERIVED/Build/Products/Release/Aurel.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")

echo "==> Ad-hoc signing (keeps entitlements)..."
# Re-sign the app and its embedded frameworks together. The hardened runtime is left
# off: with ad-hoc signatures there is no Team ID, so its library validation would
# refuse to load Sparkle. The runtime is only required for notarized releases.
codesign --force --deep --sign - \
    --preserve-metadata=entitlements \
    "$APP"
codesign --verify --deep --strict "$APP"

echo "==> Creating DMG..."
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="$BUILD_DIR/Aurel.dmg"
hdiutil create -volname "Aurel" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" -quiet

shasum -a 256 "$DMG" | tee "$DMG.sha256"
echo "==> Done: $DMG (version $VERSION)"
