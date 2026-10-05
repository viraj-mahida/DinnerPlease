#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="${HOME}/Applications/F3Counter.app"

mkdir -p "${HOME}/Applications"
if pgrep -x F3Counter >/dev/null 2>&1; then
  killall F3Counter || true
  sleep 0.3
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

swiftc -parse-as-library -O -target arm64-apple-macosx14.0 \
  -framework Cocoa \
  -framework SwiftUI \
  -framework Charts \
  -framework Carbon \
  -framework ServiceManagement \
  -o "$APP/Contents/MacOS/F3Counter" \
  "$ROOT/Sources/F3Counter/F3Counter.swift"

codesign --force --sign - --identifier com.viraj.f3counter "$APP"
open -g "$APP"
echo "Installed and launched ${APP}"
