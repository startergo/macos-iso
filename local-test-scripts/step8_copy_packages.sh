#!/bin/bash
set -e
# Copy Installer Packages and Additional Files for local testing
ESD_MOUNT="/tmp/esd"
BASESYSTEM_MOUNT="/tmp/basesystem"
TARGET_MOUNT="/tmp/target"
echo "📦 Copying installer packages and additional files..."
# Ensure the destination directory exists before copying Packages
mkdir -p "$TARGET_MOUNT/System/Installation"
# Only copy Packages if not already a real directory
if [ -L "$TARGET_MOUNT/System/Installation/Packages" ] || [ ! -d "$TARGET_MOUNT/System/Installation/Packages" ]; then
  if [ -L "$TARGET_MOUNT/System/Installation/Packages" ]; then
    echo "Removing symlinked Packages (requires sudo)..."
    sudo rm -rf "$TARGET_MOUNT/System/Installation/Packages"
  fi
  if [ -d "$ESD_MOUNT/Packages" ]; then
    echo "Copying: $ESD_MOUNT/Packages -> $TARGET_MOUNT/System/Installation/"
    sudo cp -a "$ESD_MOUNT/Packages" "$TARGET_MOUNT/System/Installation/"
    echo "✅ Packages copied from $ESD_MOUNT/Packages"
  elif [ -d "$ESD_MOUNT/SharedSupport/Packages" ]; then
    echo "Copying: $ESD_MOUNT/SharedSupport/Packages -> $TARGET_MOUNT/System/Installation/"
    sudo cp -a "$ESD_MOUNT/SharedSupport/Packages" "$TARGET_MOUNT/System/Installation/"
    echo "✅ Packages copied from $ESD_MOUNT/SharedSupport/Packages"
  elif [ -d "$BASESYSTEM_MOUNT/System/Installation/Packages" ]; then
    echo "Copying: $BASESYSTEM_MOUNT/System/Installation/Packages -> $TARGET_MOUNT/System/Installation/"
    sudo cp -a "$BASESYSTEM_MOUNT/System/Installation/Packages" "$TARGET_MOUNT/System/Installation/"
    echo "✅ Packages copied from $BASESYSTEM_MOUNT/System/Installation/Packages"
  fi
else
  echo "Packages directory already exists at $TARGET_MOUNT/System/Installation/Packages, skipping copy."
fi
echo "[DEBUG] After copy, listing $TARGET_MOUNT/System/Installation:"
ls -l "$TARGET_MOUNT/System/Installation" || true
for f in BaseSystem.dmg BaseSystem.chunklist; do
  if [ -f "$ESD_MOUNT/$f" ]; then
    echo "Copying: $ESD_MOUNT/$f -> $TARGET_MOUNT/"
    cp "$ESD_MOUNT/$f" "$TARGET_MOUNT/"
    echo "✅ $f copied from $ESD_MOUNT"
  elif [ -f "$ESD_MOUNT/SharedSupport/$f" ]; then
    echo "Copying: $ESD_MOUNT/SharedSupport/$f -> $TARGET_MOUNT/"
    cp "$ESD_MOUNT/SharedSupport/$f" "$TARGET_MOUNT/"
    echo "✅ $f copied from $ESD_MOUNT/SharedSupport"
  fi

done
if [ -f "$ESD_MOUNT/.VolumeIcon.icns" ]; then
  echo "Copying: $ESD_MOUNT/.VolumeIcon.icns -> $TARGET_MOUNT/"
  cp "$ESD_MOUNT/.VolumeIcon.icns" "$TARGET_MOUNT/"
  SetFile -a C "$TARGET_MOUNT/.VolumeIcon.icns" || true
  echo "✅ .VolumeIcon.icns copied"
fi
# Copy additional files if present (matches workflow logic)
for file in mach_kernel .IABootFiles .DS_Store; do
  if [ -e "/tmp/installesd/$file" ]; then
    echo "Copying: /tmp/installesd/$file -> $RESTORED_VOLUME/"
    cp -R "/tmp/installesd/$file" "$RESTORED_VOLUME/" 2>/dev/null || true
    echo "✅ $file copied"
  fi
  # Optionally, also check /tmp/esd for legacy compatibility
  if [ -e "/tmp/esd/$file" ]; then
    echo "Copying: /tmp/esd/$file -> $RESTORED_VOLUME/"
    cp -R "/tmp/esd/$file" "$RESTORED_VOLUME/" 2>/dev/null || true
    echo "✅ $file copied from /tmp/esd"
  fi

done
# Set the intended volume name based on installer version
# You can set INSTALLER_VERSION externally or edit this logic
case "${INSTALLER_VERSION:-}" in
  "10.9"|"Mavericks")
    VOLUME_NAME="Install OS X Mavericks"
    ;;
  "10.10"|"Yosemite")
    VOLUME_NAME="Install OS X Yosemite"
    ;;
  "10.11"|"El Capitan")
    VOLUME_NAME="Install OS X El Capitan"
    ;;
  "10.12"|"Sierra")
    VOLUME_NAME="Install macOS Sierra"
    ;;
  *)
    VOLUME_NAME="Install macOS"
    ;;
esac

# Rename the target volume to the correct name
# Only attempt rename if a /Volumes/ mount is found for the target
VOLUME_PATH=$(mount | grep "$TARGET_MOUNT" | awk '{print $3}' | grep '^/Volumes/' | head -1)
if [ -z "$VOLUME_PATH" ]; then
  echo "⚠️  Could not find a /Volumes/ mount for $TARGET_MOUNT, skipping rename."
else
  if diskutil rename "$VOLUME_PATH" "$VOLUME_NAME"; then
    echo "✅ Volume renamed successfully to $VOLUME_NAME"
  else
    echo "⚠️  Volume rename failed, continuing with current mount point"
  fi
fi
echo "Copy complete."
