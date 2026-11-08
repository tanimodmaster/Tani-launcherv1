#!/usr/bin/env bash
# Rebrand the upstream source tree (run from inside it) to "Tani Launcher".
set -euo pipefail

NAME="Tani Launcher"
BUNDLE_ID="com.tani.launcher"

# Bundle identifier (Info.plist, entitlements, Makefile ipa names)
perl -pi -e "s/org\.angelauramc\.amethyst/${BUNDLE_ID}/g" \
  Natives/Info.plist entitlements.*.xml Makefile

# Display name and permission prompts
perl -pi -e "s/Angel Aura Amethyst/${NAME}/g; s/\bAmethyst\b/${NAME}/g" Natives/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${NAME}" Natives/Info.plist 2>/dev/null || true

# Every translation (keys in InfoPlist.strings must match Info.plist, so both get the same replacement)
find Natives/resources -name '*.strings' -exec \
  perl -pi -e "s/Angel Aura Amethyst/${NAME}/g; s/\bAmethyst\b/${NAME}/g" {} +

# About / version text in Settings
perl -pi -e "s/\@\"Angel Aura Amethyst %\@/\@\"${NAME} %\@/" Natives/LauncherPreferencesViewController.m

# Build log prefix
perl -pi -e 's/\[Amethyst v/[Tani Launcher v/g' Makefile

echo "Rebranded to ${NAME} (${BUNDLE_ID})"
