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
codesign --force --sign - "$APP"
echo "built $APP"
