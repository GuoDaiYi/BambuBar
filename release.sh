#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Info.plist")"
APP="$ROOT/build/BambuBar.app"
DMG="$ROOT/build/BambuBar-${VERSION}-macOS.dmg"
ZIP="$ROOT/build/BambuBar-${VERSION}-macOS.zip"
STAGE="$ROOT/build/dmg-stage"

"$ROOT/build.sh"

echo "==> staging DMG"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> creating $DMG"
rm -f "$DMG"
hdiutil create \
  -volname "BambuBar $VERSION" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" >/dev/null

echo "==> creating $ZIP"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> release artifacts"
ls -lh "$DMG" "$ZIP"
