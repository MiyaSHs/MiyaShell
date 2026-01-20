#!/bin/sh
set -eu

# Run the Quickshell config in this repo.
#
# Tips:
# - If you're inside a gamescope session that expects X11 (Xwayland), force Qt to XCB:
#     QT_QPA_PLATFORM=xcb ./scripts/run-qs.sh

DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
exec qs -p "$DIR"
