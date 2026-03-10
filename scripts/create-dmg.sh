#!/bin/bash
set -euo pipefail

# Creates a DMG with the classic "drag to Applications" layout.
# Requires: brew install create-dmg

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/../dist"
APP_BUNDLE="$DIST_DIR/BetterWhisper.app"
DMG_PATH="$DIST_DIR/BetterWhisper.dmg"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found. Run ./scripts/bundle.sh first."
    exit 1
fi

echo "==> Creating DMG..."
rm -f "$DMG_PATH"

create-dmg \
    --volname "BetterWhisper" \
    --window-pos 200 120 \
    --window-size 540 380 \
    --icon-size 96 \
    --icon "BetterWhisper.app" 140 180 \
    --app-drop-link 400 180 \
    --no-internet-enable \
    --hide-extension "BetterWhisper.app" \
    "$DMG_PATH" \
    "$APP_BUNDLE"

echo "==> Done: $DMG_PATH"
