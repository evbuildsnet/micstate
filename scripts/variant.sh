#!/bin/zsh
# Relaunch the installed app with a debug variant bitmask. See Sources/MicState/Variant.swift.
set -euo pipefail
defaults write net.evbuilds.micstate stemVariant -int "${1:-0}"
pkill -x MicState || true
sleep 1
echo "===== $(date) variant $1" >> ~/Library/Logs/MicState.log
open /Applications/MicState.app
echo "launched with stemVariant=$1"
