#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/BambuBar.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"

echo "==> compiling BambuBar for ${ARCH} (macOS 13+)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -parse-as-library \
  -target "${ARCH}-apple-macos13.0" \
  -sdk "$SDK" \
  -framework SwiftUI \
  -framework AppKit \
  -framework Network \
  -framework Security \
  -framework UserNotifications \
  -framework ServiceManagement \
  "$ROOT"/Sources/*.swift \
  -o "$APP/Contents/MacOS/BambuBar"

cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

if [ -f "$ROOT/Assets/AppIcon.icns" ]; then
  cp "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "==> built $APP"
