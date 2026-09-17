#!/bin/zsh
# Builds MicState.app into build/ and ad-hoc signs it so TCC permissions stick.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP=build/MicState.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/MicState "$APP/Contents/MacOS/MicState"
cp Info.plist "$APP/Contents/Info.plist"
# A stable signing identity keeps the microphone permission across rebuilds. Ad-hoc re-prompts every build.
IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null)
IDENTITY=$(echo "$IDENTITIES" | awk -F'"' '/Developer ID Application/ {print $2; exit}')
[[ -z "$IDENTITY" ]] && IDENTITY=$(echo "$IDENTITIES" | awk -F'"' '/Apple Development/ {print $2; exit}')
codesign --force --options runtime --sign "${IDENTITY:--}" "$APP"
echo "signed as ${IDENTITY:-ad-hoc}"
echo "built $APP"
