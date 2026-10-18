#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building release application bundle..."
./package_app.sh

APP_NAME="NOX WHISHPER RED"
DMG_NAME="NOX-WHISPER-RED-v1.0.0.dmg"
DMG_STAGING="$SCRIPT_DIR/dmg_staging"

echo "Preparing DMG staging directory..."
rm -rf "$DMG_STAGING" "$DMG_NAME"
mkdir -p "$DMG_STAGING"

# Copy the .app bundle
cp -R "$SCRIPT_DIR/$APP_NAME.app" "$DMG_STAGING/"

# Add Applications symlink for drag-and-drop install
ln -s /Applications "$DMG_STAGING/Applications"

echo "Generating compressed DMG..."
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_NAME"
rm -rf "$DMG_STAGING"

echo "✅ Successfully created $DMG_NAME"
