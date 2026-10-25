#!/bin/zsh
# Builds Tapdeck, installs it to /Applications on this Mac and registers its
# Control Center controls. Run again after any code change.
set -euo pipefail
cd "$(dirname "$0")/.."

DEST=/Applications/Tapdeck.app
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

BUILT=$(scripts/build.sh | tail -1)

# The running copy restores any dimmed lights when it gets SIGTERM.
pkill -TERM -x Tapdeck 2>/dev/null && sleep 0.5 || true

echo "Installing to $DEST…"
rm -rf "$DEST"
ditto "$BUILT" "$DEST"

"$LSREGISTER" -f "$DEST"
pluginkit -a "$DEST/Contents/PlugIns/TapdeckControls.appex"

# The system keeps a running extension process across reinstalls and would keep
# drawing controls with the old code. Stop it; it relaunches from the new build.
pkill -TERM -x TapdeckControls 2>/dev/null || true

# The app redraws every control when it starts.
open -g "$DEST"
echo "Done. Add the controls from Control Center → Edit Controls → Tapdeck."
