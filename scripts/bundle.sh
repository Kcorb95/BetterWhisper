#!/bin/bash
set -euo pipefail

# Developer script — builds, signs, and notarizes BetterWhisper.app for distribution.
# End users should download pre-built releases from GitHub.
#
# Requires:
#   - "Developer ID Application" certificate in Keychain
#   - App Store Connect credentials stored via:
#     xcrun notarytool store-credentials "BetterWhisper" \
#       --apple-id YOUR_APPLE_ID --team-id A3N5FYR5T6

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SWIFT_DIR="$PROJECT_ROOT/macos/BetterWhisper"
DIST_DIR="$PROJECT_ROOT/dist"
APP_BUNDLE="$DIST_DIR/BetterWhisper.app"

SIGN_IDENTITY="Developer ID Application: Kevin Corbett (A3N5FYR5T6)"
NOTARIZE_PROFILE="BetterWhisper"

echo "==> Building release binary..."
cd "$SWIFT_DIR"
swift build -c release

echo "==> Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Binary
cp .build/release/BetterWhisper "$APP_BUNDLE/Contents/MacOS/"

# Info.plist
cp Info.plist "$APP_BUNDLE/Contents/"

# Resources (menu bar icon, etc.)
if [ -d "$SWIFT_DIR/Resources" ]; then
    find "$SWIFT_DIR/Resources" -type f \( -name "*.png" -o -name "*.pdf" \) -exec cp {} "$APP_BUNDLE/Contents/Resources/" \;
fi

# App icon
if [ -f "$SWIFT_DIR/AppIcon.icns" ]; then
    cp "$SWIFT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
else
    echo ""
    echo "Warning: No AppIcon.icns found at macos/BetterWhisper/AppIcon.icns"
    echo "  Create a 1024x1024 PNG and run:"
    echo "  ./scripts/create-icns.sh your-icon.png macos/BetterWhisper/AppIcon.icns"
    echo ""
fi

# Strip extended attributes before signing
xattr -cr "$APP_BUNDLE"

# Code signing with Developer ID
echo "==> Signing with Developer ID..."
codesign --force --deep --options runtime \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$SWIFT_DIR/BetterWhisper.entitlements" \
    "$APP_BUNDLE"

echo "==> Verifying signature..."
codesign --verify --deep --strict "$APP_BUNDLE"

# Notarize
echo "==> Notarizing (this may take a few minutes)..."
ZIP_PATH="$DIST_DIR/BetterWhisper-notarize.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

if xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait; then
    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$APP_BUNDLE"
    rm -f "$ZIP_PATH"
    echo "==> Done: $APP_BUNDLE (signed + notarized)"
else
    rm -f "$ZIP_PATH"
    echo ""
    echo "WARNING: Notarization failed. The app is signed but not notarized."
    echo "Users will need to right-click → Open on first launch."
    echo ""
    echo "To set up notarization credentials, run:"
    echo "  xcrun notarytool store-credentials \"BetterWhisper\" \\"
    echo "    --apple-id YOUR_APPLE_ID --team-id A3N5FYR5T6"
    echo ""
    echo "==> Done: $APP_BUNDLE (signed only)"
fi
