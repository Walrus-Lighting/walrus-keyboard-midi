#!/bin/bash
# Builds "Walrus Keyboard MIDI.app" with the Swift compiler from the Command Line Tools (no Xcode needed).
set -euo pipefail
cd "$(dirname "$0")"
APP="Walrus Keyboard MIDI.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -parse-as-library \
  -target arm64-apple-macos13.0 \
  -o "$APP/Contents/MacOS/WalrusKeyboardMIDI" \
  Sources/*.swift \
  -framework SwiftUI -framework AppKit -framework CoreMIDI -framework IOKit -framework ApplicationServices

cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Walrus Keyboard MIDI</string>
  <key>CFBundleDisplayName</key><string>Walrus Keyboard MIDI</string>
  <key>CFBundleIdentifier</key><string>com.walruslighting.keyboardmidi</string>
  <key>CFBundleExecutable</key><string>WalrusKeyboardMIDI</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Signing: set SIGN_IDENTITY to the name of a code-signing certificate in your keychain and macOS keeps the
# permissions you grant across rebuilds. Without one, the app gets an ad-hoc signature and macOS asks for
# Accessibility / Input Monitoring again after every build. SIGN_IDENTITY=- forces ad-hoc.
IDENTITY="${SIGN_IDENTITY:--}"
if [ "$IDENTITY" != "-" ] && security find-identity -p codesigning | grep -q "$IDENTITY"; then
  codesign --force --deep --sign "$IDENTITY" "$APP"
else
  echo "Certificate '$IDENTITY' not found - using ad-hoc signature"
  codesign --force --deep --sign - "$APP"
fi
echo "Built: $(pwd)/$APP"
