#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building release binary..."
swift build -c release

RELEASE_BIN="$(swift build -c release --show-bin-path)/RubricLocal"
APP_BUNDLE="$SCRIPT_DIR/NOX WHISHPER RED.app"

echo "Creating application bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/NOX WHISHPER RED"
chmod +x "$APP_BUNDLE/Contents/MacOS/NOX WHISHPER RED"

# Copy AppIcon and menu bar icon assets
if [ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi
if [ -f "$SCRIPT_DIR/Resources/NoxMenuIcon.png" ]; then
    cp "$SCRIPT_DIR/Resources/NoxMenuIcon.png" "$APP_BUNDLE/Contents/Resources/NoxMenuIcon.png"
    cp "$SCRIPT_DIR/Resources/NoxMenuIcon@2x.png" "$APP_BUNDLE/Contents/Resources/NoxMenuIcon@2x.png"
fi

cat <<'EOF' > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>NOX WHISHPER RED</string>
    <key>CFBundleExecutable</key>
    <string>NOX WHISHPER RED</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.noxwhisper.red</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NOX WHISHPER RED</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>NOX WHISHPER RED captures the screen area around your cursor to inspect and solve questions.</string>
</dict>
</plist>
EOF

# Codesign with stable designated requirement so macOS TCC permissions persist across rebuilds
codesign -s - --force --deep -r='designated => identifier "com.noxwhisper.red"' "$APP_BUNDLE"

echo "Successfully packaged NOX WHISHPER RED.app at $APP_BUNDLE"

# Install to /Applications
INSTALL_DEST="/Applications/NOX WHISHPER RED.app"
echo "Installing to $INSTALL_DEST..."
killall "NOX WHISHPER RED" 2>/dev/null || true
killall RubricLocal 2>/dev/null || true
sleep 0.5
rm -rf "$INSTALL_DEST"
cp -R "$APP_BUNDLE" "$INSTALL_DEST"

echo "Launching updated $INSTALL_DEST..."
open "$INSTALL_DEST"

echo "Done! NOX WHISHPER RED is running."
