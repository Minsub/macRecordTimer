#!/bin/bash
set -euo pipefail

swift build -c release
app="RecordTimer.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" .build/RecordTimer.iconset
cp .build/release/RecordTimer "$app/Contents/MacOS/RecordTimer"
iconset=".build/RecordTimer.iconset"
swift Assets/RecordTimerIcon.swift "$iconset/icon_512x512@2x.png"
sips -z 16 16 "$iconset/icon_512x512@2x.png" --out "$iconset/icon_16x16.png" >/dev/null
sips -z 32 32 "$iconset/icon_512x512@2x.png" --out "$iconset/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$iconset/icon_512x512@2x.png" --out "$iconset/icon_32x32.png" >/dev/null
sips -z 64 64 "$iconset/icon_512x512@2x.png" --out "$iconset/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$iconset/icon_512x512@2x.png" --out "$iconset/icon_128x128.png" >/dev/null
sips -z 256 256 "$iconset/icon_512x512@2x.png" --out "$iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$iconset/icon_512x512@2x.png" --out "$iconset/icon_256x256.png" >/dev/null
sips -z 512 512 "$iconset/icon_512x512@2x.png" --out "$iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$iconset/icon_512x512@2x.png" --out "$iconset/icon_512x512.png" >/dev/null
iconutil -c icns -o "$app/Contents/Resources/AppIcon.icns" "$iconset"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>RecordTimer</string>
    <key>CFBundleIdentifier</key><string>com.local.RecordTimer</string>
    <key>CFBundleIconFile</key><string>AppIcon.icns</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundleName</key><string>RecordTimer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --deep --sign - "$app"
printf 'Created %s\n' "$app"
