#!/bin/bash
set -e
# ASR Restore BaseSystem to Target for local testing
SPARSE_IMG="/tmp/ASR_Installer.sparseimage"
BASESYSTEM_DMG="/tmp/esd/BaseSystem.dmg"
BASESYSTEM_MOUNT="/tmp/basesystem"
TARGET_MOUNT="/tmp/target"

# Pre-check: file must exist and be a valid image
if [ ! -f "$SPARSE_IMG" ]; then
  echo "❌ Sparse image not found: $SPARSE_IMG"
  ls -l /tmp
  exit 1
fi
echo "[DEBUG] Sparse image file info:"
ls -lh "$SPARSE_IMG"
file "$SPARSE_IMG"

# Pre-check: BaseSystem.dmg must exist
if [ ! -f "$BASESYSTEM_DMG" ]; then
  echo "❌ BaseSystem.dmg not found at $BASESYSTEM_DMG"
  ls -l /tmp/esd || true
  exit 1
fi

# Mount BaseSystem.dmg if not already mounted
if ! mount | grep -q "on $BASESYSTEM_MOUNT "; then
  echo "🛠️ Mounting BaseSystem.dmg to $BASESYSTEM_MOUNT..."
  hdiutil attach "$BASESYSTEM_DMG" -mountpoint "$BASESYSTEM_MOUNT"
fi

echo "🛠️ Attaching sparse image..."
SPARSE_ATTACH_OUTPUT=$(hdiutil attach "$SPARSE_IMG" -mountpoint "$TARGET_MOUNT" -plist)
SPARSE_DEV=$(echo "$SPARSE_ATTACH_OUTPUT" | grep -Eo '/dev/disk[0-9]+' | head -1)

if [ -z "$SPARSE_DEV" ]; then
  echo "❌ Could not find device node for attached sparse image."
  exit 1
fi

echo "[DEBUG] Filesystem info for $SPARSE_DEV:"
diskutil info "$SPARSE_DEV" || true

diskutil unmount "$TARGET_MOUNT"
asr restore --source "$BASESYSTEM_MOUNT" --target "$SPARSE_DEV" --erase --noprompt --noverify
hdiutil attach "$SPARSE_IMG" -mountpoint "$TARGET_MOUNT"

# After ASR restore: print filesystem info
echo "[DEBUG] Filesystem info AFTER ASR restore:"
diskutil info "$SPARSE_IMG" || true
diskutil info "$TARGET_MOUNT" || true
if [ -n "$SPARSE_DEV" ]; then
  diskutil info "$SPARSE_DEV" || true
fi
