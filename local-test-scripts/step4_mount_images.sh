#!/bin/bash
set -e
# Mount Sparse Image and Source DMGs for local testing
SPARSE_IMG="/tmp/ASR_Installer.sparseimage"
ESD_DMG="./InstallESD.dmg"
ESD_MOUNT="/tmp/esd"
BASESYSTEM_MOUNT="/tmp/basesystem"
TARGET_MOUNT="/tmp/target"

if [[ ! -f "$ESD_DMG" ]]; then
  echo "InstallESD.dmg not found: $ESD_DMG"
  exit 1
fi

echo "🔗 Mounting sparse image and source DMGs..."
hdiutil attach "$ESD_DMG" -noverify -readonly -mountpoint "$ESD_MOUNT"
# Copy BaseSystem.dmg to /tmp/BaseSystem.dmg for downstream scripts
if [ -f "$ESD_MOUNT/BaseSystem.dmg" ]; then
  cp "$ESD_MOUNT/BaseSystem.dmg" /tmp/BaseSystem.dmg
  if [ -f /tmp/BaseSystem.dmg ]; then
    echo "✅ Copied BaseSystem.dmg to /tmp/BaseSystem.dmg"
    ls -lh /tmp/BaseSystem.dmg
  else
    echo "❌ Failed to copy BaseSystem.dmg!"
    exit 1
  fi
elif [ -f "$ESD_MOUNT/SharedSupport/BaseSystem.dmg" ]; then
  cp "$ESD_MOUNT/SharedSupport/BaseSystem.dmg" /tmp/BaseSystem.dmg
  if [ -f /tmp/BaseSystem.dmg ]; then
    echo "✅ Copied BaseSystem.dmg to /tmp/BaseSystem.dmg"
    ls -lh /tmp/BaseSystem.dmg
  else
    echo "❌ Failed to copy BaseSystem.dmg!"
    exit 1
  fi
else
  echo "❌ Could not find BaseSystem.dmg in $ESD_MOUNT or $ESD_MOUNT/SharedSupport"
  exit 1
fi
if [ -f "$ESD_MOUNT/BaseSystem.dmg" ]; then
  hdiutil attach "$ESD_MOUNT/BaseSystem.dmg" -noverify -readonly -mountpoint "$BASESYSTEM_MOUNT"
else
  hdiutil attach "$ESD_MOUNT/SharedSupport/BaseSystem.dmg" -noverify -readonly -mountpoint "$BASESYSTEM_MOUNT"
fi
hdiutil attach "$SPARSE_IMG" -noverify -mountpoint "$TARGET_MOUNT"
echo "Mounts complete."
