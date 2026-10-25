#!/bin/zsh
# Builds Tapdeck.app and prints its path on the last line of stdout.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=${CONFIG:-Release}
DERIVED=build/DerivedData
BUILT="$PWD/$DERIVED/Build/Products/$CONFIG/Tapdeck.app"
INSTALLED=/Applications/Tapdeck.app
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# WidgetKit caches each extension's list of controls by build number, so a
# build that reuses a number never shows newly added controls.
BUILD_NUMBER=$(date +%s)

echo "Building Tapdeck ($CONFIG, build $BUILD_NUMBER)…" >&2
xcodebuild -project Tapdeck.xcodeproj -scheme Tapdeck -configuration "$CONFIG" \
  -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" -quiet build \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" >&2

# Xcode registers the build product, which shares the installed app's bundle ID:
# left alone, Control Center lists its controls twice. Unregistering it also
# drops every App Intent for that bundle ID (the controls then fail with
# "Missing: com.ibtkrgo.Tapdeck:…"), so hand the registration back to the
# installed copy.
"$LSREGISTER" -u "$BUILT" 2>/dev/null || true
pluginkit -r "$BUILT/Contents/PlugIns/TapdeckControls.appex" 2>/dev/null || true
if [[ -d "$INSTALLED" ]]; then
  "$LSREGISTER" -f "$INSTALLED"
  pluginkit -a "$INSTALLED/Contents/PlugIns/TapdeckControls.appex"
fi

echo "$BUILT"
