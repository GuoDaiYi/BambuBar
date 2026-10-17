#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/Assets"
ICONSET="$ASSETS/AppIcon.iconset"
mkdir -p "$ASSETS" "$ICONSET"

swift "$ROOT/Tools/makeicon.swift" "$ASSETS/icon_1024.png"

sips -z 16 16     "$ASSETS/icon_1024.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32     "$ASSETS/icon_1024.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$ASSETS/icon_1024.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64     "$ASSETS/icon_1024.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$ASSETS/icon_1024.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256   "$ASSETS/icon_1024.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$ASSETS/icon_1024.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512   "$ASSETS/icon_1024.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$ASSETS/icon_1024.png" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$ASSETS/icon_1024.png" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ASSETS/AppIcon.icns"
echo "==> wrote $ASSETS/AppIcon.icns"
