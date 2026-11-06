#!/bin/bash
# Builds "G's Avengers.app" into ../dist. Usage: bash mac/build.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD; APP="$ROOT/dist/G's Avengers.app"; BUILD="$ROOT/dist/.build"
mkdir -p "$BUILD"
# icon (drawn in code)
if [ ! -f "$BUILD/AppIcon.icns" ] || [ tools/make_icon.swift -nt "$BUILD/AppIcon.icns" ]; then
  rm -rf "$BUILD/AppIcon.iconset"; mkdir -p "$BUILD/AppIcon.iconset"
  swift tools/make_icon.swift "$BUILD/icon1024.png" 1024
  for s in 16 32 128 256 512; do
    sips -z $s $s "$BUILD/icon1024.png" --out "$BUILD/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$BUILD/icon1024.png" --out "$BUILD/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$BUILD/AppIcon.iconset" -o "$BUILD/AppIcon.icns"
fi
swiftc -O -target arm64-apple-macos13.0 -o "$BUILD/GsAvengers-arm64" mac/Sources/*.swift
swiftc -O -target x86_64-apple-macos13.0 -o "$BUILD/GsAvengers-x86_64" mac/Sources/*.swift
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$BUILD/GsAvengers-arm64" "$BUILD/GsAvengers-x86_64" -output "$APP/Contents/MacOS/GsAvengers"
cp mac/Info.plist "$APP/Contents/Info.plist"
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# sign with a stable identity so the Accessibility permission survives rebuilds
ID=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID/{print $2; exit}')
codesign --force --deep --sign "${ID:--}" "$APP"
echo "built: $APP ($(du -sh "$APP" | cut -f1)) signed with: ${ID:-ad-hoc}"
if [ "${1:-}" = "--install" ]; then
  pkill -x GsAvengers || true; sleep 0.5
  rm -rf "/Applications/G's Avengers.app"; cp -R "$APP" /Applications/
  open "/Applications/G's Avengers.app" --args --show
  echo "installed to /Applications"
fi
