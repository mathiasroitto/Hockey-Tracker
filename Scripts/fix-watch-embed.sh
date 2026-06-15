#!/bin/bash
#
# Xcode 16+ requires a watchOS app to be embedded in the host app's `PlugIns/`
# directory (dstSubfolderSpec = 13, empty dstPath), the same as app extensions.
# As of writing, XcodeGen still generates the older `Watch/` embed location
# (dstSubfolderSpec = 16, dstPath = "$(CONTENTS_FOLDER_PATH)/Watch"), which makes
# the app fail to install with:
#
#   "... is a Foundation extension and must be embedded in the parent app
#    bundle's PlugIns directory, but is embedded in the parent app bundle's
#    Watch directory."
#
# See https://github.com/yonaskolb/XcodeGen/issues/1613
#
# This script rewrites the generated project to use the PlugIns location. It is
# idempotent (running it again does nothing) and a no-op if XcodeGen has already
# been fixed to emit the correct path.

set -euo pipefail

PBXPROJ="HockeyTracker.xcodeproj/project.pbxproj"

if [ ! -f "$PBXPROJ" ]; then
  echo "fix-watch-embed: $PBXPROJ not found, skipping."
  exit 0
fi

if ! grep -q 'dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";' "$PBXPROJ"; then
  echo "fix-watch-embed: nothing to patch (already using PlugIns)."
  exit 0
fi

TMP="$(mktemp)"
sed \
  -e 's|dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";|dstPath = "";|g' \
  -e 's|dstSubfolderSpec = 16;|dstSubfolderSpec = 13;|g' \
  "$PBXPROJ" > "$TMP"
mv "$TMP" "$PBXPROJ"

echo "fix-watch-embed: patched watch embed location to PlugIns/."
