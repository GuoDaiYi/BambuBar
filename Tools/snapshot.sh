#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
ARCH="$(uname -m)"

FILES=()
for f in "$ROOT"/Sources/*.swift; do
  case "$(basename "$f")" in
    BambuBarApp.swift) continue ;;
  esac
  FILES+=("$f")
done

swiftc -O -parse-as-library \
  -target "${ARCH}-apple-macos13.0" \
  -sdk "$SDK" \
  -framework SwiftUI -framework AppKit -framework Network \
  -framework Security -framework UserNotifications -framework ServiceManagement \
  "${FILES[@]}" "$ROOT/Tools/SnapshotMain.swift" \
  -o "$ROOT/build/snapshot"

"$ROOT/build/snapshot"
