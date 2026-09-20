#!/bin/zsh
# Builds, copies to /Applications, and relaunches.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build.sh
# Quit gracefully first so the running copy unmutes the device on the way out.
osascript -e 'tell application "MicState" to quit' >/dev/null 2>&1 || true
sleep 1
pkill -x MicState || true
rm -rf /Applications/MicState.app
cp -R build/MicState.app /Applications/MicState.app
open /Applications/MicState.app
echo "installed and launched"
