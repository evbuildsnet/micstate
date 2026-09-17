#!/bin/zsh
# Builds, copies to /Applications, and relaunches.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build.sh
pkill -x MicState || true
rm -rf /Applications/MicState.app
cp -R build/MicState.app /Applications/MicState.app
open /Applications/MicState.app
echo "installed and launched"
