#!/bin/sh
set -eu

# Minimal example: start gamescope and run the UI inside it.
#
# You will almost certainly want to tune flags for your device.
#
# If you use gamescope-session (recommended for SteamOS-like behavior),
# use its gamescope-fg helper to set STEAM_GAME properties.

DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# Force Qt to X11/Xwayland for compatibility with gamescope embedded mode.
export QT_QPA_PLATFORM=xcb

# Tag the UI window as STEAM_GAME=769 (SteamOS convention) so gamescope embedded
# sessions will treat it as the "main" UI.
exec gamescope -e -- "$DIR/tools/gamescope-fg-lite" --appid 769 --wait -- "$DIR/scripts/run-qs.sh"
