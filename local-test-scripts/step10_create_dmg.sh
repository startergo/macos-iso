#!/bin/bash
set -e
set -x
# Create compressed DMG from the sparse image
SPARSE_IMG="/tmp/ASR_Installer.sparseimage"
# Remove version sourcing; assume variables are set by run_all.sh
VOLUME_NAME="${VOLNAME:-Install macOS}"
DMG_NAME="macOS-${VOLUME_NAME// /_}.dmg"
echo "💿 Creating DMG: /tmp/$DMG_NAME from $SPARSE_IMG"
if hdiutil convert "$SPARSE_IMG" -format UDZO -o "/tmp/$DMG_NAME"; then
  echo "✅ DMG created: /tmp/$DMG_NAME"
  du -sh "/tmp/$DMG_NAME"
else
  echo "❌ Failed to create DMG"
  exit 1
fi
