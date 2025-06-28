#!/bin/bash
set -e
set -x
# Bless and Optimize Image for local testing
BASESYSTEM_MOUNT="/tmp/basesystem"
ESD_MOUNT="/tmp/esd"
SPARSE_IMG="/tmp/ASR_Installer.sparseimage"
TARGET_MOUNT="/tmp/target"
echo "🙏 Blessing and optimizing image..."
# Dynamically find the device node and mount point after ASR restore
TARGET_DEV=$(hdiutil info | awk '/\/private\/tmp\/target/ {getline; print $1}' | head -1)
if [ -z "$TARGET_DEV" ]; then
  echo "❌ Could not find device node for $TARGET_MOUNT. Attempting to re-attach..."
  hdiutil attach "$SPARSE_IMG" -mountpoint "$TARGET_MOUNT" || true
  sleep 2
  TARGET_DEV=$(hdiutil info | awk '/\/private\/tmp\/target/ {getline; print $1}' | head -1)
fi
if [ -z "$TARGET_DEV" ]; then
  echo "❌ Still could not find device node for $TARGET_MOUNT"
  hdiutil info
  exit 1
fi
MOUNT_POINT=$(mount | grep "$TARGET_DEV" | awk '{print $3}' | head -1)
if [ -z "$MOUNT_POINT" ]; then
  echo "❌ Could not find mount point for $TARGET_DEV. Attempting to re-attach..."
  hdiutil attach "$SPARSE_IMG" -mountpoint "$TARGET_MOUNT" || true
  sleep 2
  MOUNT_POINT=$(mount | grep "$TARGET_DEV" | awk '{print $3}' | head -1)
fi
if [ -z "$MOUNT_POINT" ]; then
  echo "❌ Still could not find mount point for $TARGET_DEV"
  mount
  exit 1
fi
# Enable owners if disabled
OWNERS_STATUS=$(diskutil info "$MOUNT_POINT" | awk -F': ' '/Owners/ {print $2}' | xargs)
if [[ "$OWNERS_STATUS" != "Enabled" ]]; then
  echo "⚠️ Owners are disabled on $MOUNT_POINT. Attempting to enable..."
  sudo diskutil enableOwnership "$MOUNT_POINT" || true
  OWNERS_STATUS=$(diskutil info "$MOUNT_POINT" | awk -F': ' '/Owners/ {print $2}' | xargs)
fi
FS_TYPE=$(diskutil info "$MOUNT_POINT" | awk -F': ' '/Type \(Bundle\)/ {print $2}')
echo "[DEBUG] Filesystem type: $FS_TYPE"
echo "[DEBUG] Owners: $OWNERS_STATUS"
if [ ! -d "$MOUNT_POINT/System/Library/CoreServices" ]; then
  echo "❌ $MOUNT_POINT/System/Library/CoreServices does not exist!"
  ls -l "$MOUNT_POINT/System/Library" || true
  ls -l "$MOUNT_POINT/System" || true
  exit 1
fi

# Remove version sourcing; assume variables are set by run_all.sh

# Use the correct label for bless and rename
if [[ "$FS_TYPE" == *HFS* || "$FS_TYPE" == *hfs* ]]; then
  if [[ "$OWNERS_STATUS" != "Enabled" ]]; then
    echo "⚠️ Owners are still disabled on $MOUNT_POINT. Bless may not work as expected."
  fi
  sudo bless --folder "$MOUNT_POINT/System/Library/CoreServices" --label "$VOLUME_NAME" || echo "⚠️ bless failed, continuing (HFS)"
else
  echo "⚠️ Skipping bless: not HFS/HFS+ (detected: $FS_TYPE)"
fi

# Step 12: Set proper volume name
if diskutil rename "$MOUNT_POINT" "$VOLUME_NAME"; then
  echo "✅ Volume renamed successfully to $VOLUME_NAME"
else
  echo "⚠️  Volume rename failed, continuing with current mount point"
fi

# Robust detach function
grobust_detach() {
  local target="$1"
  local max_attempts=6
  local attempt=1
  local sleep_time=5
  while [ $attempt -le $max_attempts ]; do
    if hdiutil detach "$target" -force; then
      echo "[robust_detach] Detached $target"
      return 0
    else
      echo "[robust_detach] Attempt $attempt failed for $target"
      lsof +D "$target" || true
      sleep $sleep_time
      attempt=$((attempt+1))
    fi
  done
  echo "[robust_detach] Max attempts reached for $target"
  return 1
}

# Detach all known mount points and device nodes
for mp in "$MOUNT_POINT" "$BASESYSTEM_MOUNT" "$ESD_MOUNT" "/tmp/installer" "/Volumes/OS X Base System"; do
  if [ -d "$mp" ] || mount | grep -q " $mp "; then
    grobust_detach "$mp"
  fi
  # Also try to detach by device node if available
  dev=$(mount | grep " $mp " | awk '{print $1}')
  if [ -n "$dev" ]; then
    grobust_detach "$dev"
  fi
  # Try to detach by device node for known images
  for img in "$SPARSE_IMG" "/tmp/esd/BaseSystem.dmg" "/tmp/ASR_Installer.sparseimage" "/Users/macbookpro/macos-iso/local-test-scripts/InstallESD.dmg" "/Users/macbookpro/macos-iso/local-test-scripts/Installer.dmg"; do
    devs=$(hdiutil info | awk -v img="$img" '$0 ~ img {getline; print $1}')
    for dev in $devs; do
      if [[ "$dev" == /dev/* ]]; then
        grobust_detach "$dev"
      fi
    done
  done
done

sleep 2
hdiutil compact "$SPARSE_IMG" 2>/dev/null || echo "⚠️  Compact failed but continuing..."
hdiutil resize -sectors min "$SPARSE_IMG" 2>/dev/null || true
echo "Bless and optimize complete."
DEVICE_NODE="$TARGET_DEV"
