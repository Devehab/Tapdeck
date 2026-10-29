#!/bin/zsh
# Packages a release:
#   dist/Tapdeck-<version>.dmg          (archive copy)
#   dist/Tapdeck.dmg                    (the release asset the landing page links to)
#   dist/tapdeck-chrome-extension.zip   (the sample Chrome extension, ready to load unpacked)
set -euo pipefail
cd "$(dirname "$0")/.."

BUILT=$(scripts/build.sh | tail -1)

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$BUILT/Contents/Info.plist")
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
ditto "$BUILT" "$STAGING/Tapdeck.app"
ln -s /Applications "$STAGING/Applications"

mkdir -p dist
DMG="dist/Tapdeck-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Tapdeck" -srcfolder "$STAGING" -fs HFS+ \
  -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
cp "$DMG" dist/Tapdeck.dmg

EXTENSION="$STAGING/tapdeck-chrome-extension"
ditto extensions/chrome "$EXTENSION"
rm -f dist/tapdeck-chrome-extension.zip
ditto -c -k --keepParent --norsrc "$EXTENSION" dist/tapdeck-chrome-extension.zip

echo "Created $DMG, dist/Tapdeck.dmg ($(du -h "$DMG" | cut -f1)) and dist/tapdeck-chrome-extension.zip"
echo "Publish: gh release create v$VERSION dist/Tapdeck.dmg dist/tapdeck-chrome-extension.zip --title \"Tapdeck $VERSION\""
