#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/BambuBar.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

echo "==> compiling BambuBar (universal: x86_64 + arm64, macOS 13+)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ROOT/build/obj"

build_arch() {
  local arch="$1"
  local out="$2"
  swiftc -O -parse-as-library \
    -target "${arch}-apple-macos13.0" \
    -sdk "$SDK" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Network \
    -framework Security \
    -framework UserNotifications \
    -framework ServiceManagement \
    "$ROOT"/Sources/*.swift \
    -o "$out"
}

build_arch x86_64 "$ROOT/build/obj/BambuBar-x86_64"
build_arch arm64 "$ROOT/build/obj/BambuBar-arm64"

lipo -create \
  "$ROOT/build/obj/BambuBar-x86_64" \
  "$ROOT/build/obj/BambuBar-arm64" \
  -output "$APP/Contents/MacOS/BambuBar"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

if [ -f "$ROOT/Assets/AppIcon.icns" ]; then
  cp "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "==> built $APP"
lipo -info "$APP/Contents/MacOS/BambuBar"
