#!/bin/bash
set -euo pipefail

swift build -c release
app="RecordTimer.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/RecordTimer "$app/Contents/MacOS/RecordTimer"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>RecordTimer</string>
    <key>CFBundleIdentifier</key><string>com.local.RecordTimer</string>
    <key>CFBundleName</key><string>RecordTimer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --deep --sign - "$app"
printf 'Created %s\n' "$app"
