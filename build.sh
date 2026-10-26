#!/bin/bash
# Build NusaMac.app from Swift Package Manager and pack it as NusaMac.dmg.
# Requires macOS with Xcode Command Line Tools (swift, codesign, hdiutil).
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="NusaMac.app"
rm -rf "$APP" NusaMac.dmg
mkdir -p "$APP/Contents/MacOS"
cp .build/release/NusaMac "$APP/Contents/MacOS/NusaMac"
cp packaging/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --deep --sign - "$APP"
hdiutil create -volname NusaMac -srcfolder "$APP" -ov -format UDZO NusaMac.dmg
echo "Built: NusaMac.dmg"
