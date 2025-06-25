#!/bin/bash
# test_download_extract_1010_1012.sh
# Local test script for macOS 10.10–10.12 installer DMG/PKG extraction
# Usage: ./test_download_extract_1010_1012.sh 10.10|10.11|10.12
set -euo pipefail

VERSION="${1:-}"
if [[ "$VERSION" != "10.10" && "$VERSION" != "10.11" && "$VERSION" != "10.12" ]]; then
  echo "Usage: $0 10.10|10.11|10.12"
  exit 1
fi

# --- Robust detach function (matches workflow logic) ---
robust_detach() {
  local mount_point="$1"
  local max_attempts=6
  local attempt=1
  local sleep_time=20
  sync
  # If the mount point does not exist or is not mounted, return success immediately
  if [ ! -d "$mount_point" ] || ! mount | grep -q " $mount_point "; then
    echo "[robust_detach] $mount_point does not exist or is not mounted, skipping."
    return 0
  fi
  while [ $attempt -le $max_attempts ]; do
    echo "[robust_detach] Attempt $attempt to detach $mount_point"
    if hdiutil detach "$mount_point" -force; then
      echo "[robust_detach] Successfully detached $mount_point"
      return 0
    else
      if [ -d "$mount_point" ]; then
        lsof +D "$mount_point" || true
      else
        echo "[robust_detach] $mount_point does not exist, skipping lsof."
      fi
      if [ $attempt -eq $max_attempts ]; then
        echo "[robust_detach] Max attempts reached. Forcing detach and continuing."
        hdiutil detach "$mount_point" -force || true
        return 1
      fi
      sleep $sleep_time
      attempt=$((attempt+1))
    fi
  done
}

case "$VERSION" in
  10.10)
    DOWNLOAD_URL="https://updates.cdn-apple.com/2019/cert/061-41343-20191023-02465f92-3ab5-4c92-bfe2-b725447a070d/InstallMacOSX.dmg"
    PKG_NAME="InstallMacOSX.pkg"
    ;;
  10.11)
    DOWNLOAD_URL="https://updates.cdn-apple.com/2019/cert/061-41424-20191024-218af9ec-cf50-4516-9011-228c78eda3d2/InstallMacOSX.dmg"
    PKG_NAME="InstallMacOSX.pkg"
    ;;
  10.12)
    DOWNLOAD_URL="https://updates.cdn-apple.com/2019/cert/061-39476-20191023-48f365f4-0015-4c41-9f44-39d3d2aca067/InstallOS.dmg"
    PKG_NAME="InstallOS.pkg"
    ;;
esac

WORKDIR="/tmp/macos_test_$VERSION"

# Download installer DMG before cleaning workdir
CACHED_DMG="$HOME/Installer_${VERSION}.dmg"
if [ -f "$CACHED_DMG" ]; then
  echo "✅ Found cached Installer.dmg, will reuse."
else
  echo "📥 Downloading $DOWNLOAD_URL ..."
  curl -fL -o "$CACHED_DMG" "$DOWNLOAD_URL"
fi

# Clean workdir but preserve Installer.dmg if present
if [ -d "$WORKDIR" ] && [ -f "$WORKDIR/Installer.dmg" ]; then
  echo "✅ Preserving existing Installer.dmg in $WORKDIR."
  mv "$WORKDIR/Installer.dmg" "$HOME/Installer_${VERSION}_tmp.dmg"
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"
  mv "$HOME/Installer_${VERSION}_tmp.dmg" "$WORKDIR/Installer.dmg"
else
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"
  cp "$CACHED_DMG" "$WORKDIR/Installer.dmg"
fi
cd "$WORKDIR"

# Mount DMG
hdiutil attach Installer.dmg -noverify -nobrowse -readonly -mountpoint "$WORKDIR/mnt"

# Find PKG
PKG_FILE=$(find "$WORKDIR/mnt" -name "*.pkg" | head -1)
if [ -z "$PKG_FILE" ]; then
  echo "❌ No PKG found in mounted DMG"
  hdiutil detach "$WORKDIR/mnt"
  exit 1
fi

echo "✅ Found PKG: $PKG_FILE"

# Extract PKG
mkdir -p pkg_extract
cd pkg_extract
xar -xf "$PKG_FILE"

# Find payload
PAYLOAD_FILE=$(find . -name "Payload" -o -name "*.pax.gz" | head -1)
if [ -z "$PAYLOAD_FILE" ]; then
  echo "❌ No payload found in PKG"
  exit 1
fi

echo "✅ Found payload: $PAYLOAD_FILE"

# Extract payload
mkdir -p ../payload_extract
cd ../payload_extract
if [[ "$PAYLOAD_FILE" == *.pax.gz ]]; then
  echo "📦 Extracting pax.gz payload..."
  gunzip -c "../pkg_extract/$PAYLOAD_FILE" | pax -r
elif [[ "$PAYLOAD_FILE" == *Payload* ]]; then
  echo "📦 Extracting cpio payload..."
  cpio -i < "../pkg_extract/$PAYLOAD_FILE"
else
  echo "❌ Unknown payload format"
  exit 1
fi

# Find InstallESD.dmg
INSTALLESD=$(find . -name "InstallESD.dmg" | head -1)
if [ -z "$INSTALLESD" ]; then
  # Try to find it in the extracted PKG directory (for 10.10/10.11)
  INSTALLESD=$(find "$WORKDIR/pkg_extract" -name "InstallESD.dmg" | head -1)
fi
if [ -z "$INSTALLESD" ]; then
  echo "❌ InstallESD.dmg not found"
  exit 1
fi
cp "$INSTALLESD" "$WORKDIR/InstallESD.dmg"
echo "✅ InstallESD.dmg extracted: $WORKDIR/InstallESD.dmg"

cd "$WORKDIR"

# --- Begin Unified ASR Installer Creation ---
VOLUME_NAME=""
case "$VERSION" in
  10.10) VOLUME_NAME="Install OS X Yosemite" ;;
  10.11) VOLUME_NAME="Install OS X El Capitan" ;;
  10.12) VOLUME_NAME="Install macOS Sierra" ;;
esac

# Mount InstallESD.dmg
hdiutil attach InstallESD.dmg -noverify -readonly -nobrowse -mountpoint "$WORKDIR/installesd"

# Check for BaseSystem.dmg
if [ ! -f "$WORKDIR/installesd/BaseSystem.dmg" ]; then
  echo "❌ BaseSystem.dmg not found in InstallESD"
  hdiutil detach "$WORKDIR/installesd"
  exit 1
fi

# Mount BaseSystem.dmg
hdiutil attach "$WORKDIR/installesd/BaseSystem.dmg" -noverify -nobrowse -readonly -mountpoint "$WORKDIR/basesystem"

# Create sparse image
hdiutil create -size 7g -layout SPUD -fs "HFS+J" -volname "$VOLUME_NAME" -type SPARSE -o "$WORKDIR/ASR_Installer"

# Mount sparse image
hdiutil attach "$WORKDIR/ASR_Installer.sparseimage" -noverify -nobrowse -mountpoint "$WORKDIR/asr_target"

# ASR restore
TARGET_DISK=$(mount | grep "$WORKDIR/asr_target" | awk '{print $1}')
echo "🚀 Starting ASR restore..."
if ! asr restore --source "$WORKDIR/basesystem" --target "$TARGET_DISK" --noprompt --noverify --erase; then
  echo "❌ ASR restore failed"
  exit 1
fi

# Detach and remount for read-write
MOUNTS_BEFORE=$(mount | grep "$WORKDIR" | awk '{print $3}')
echo "🔍 Mount points before detach:"
echo "$MOUNTS_BEFORE"
echo "[DEBUG] WORKDIR/basesystem: $WORKDIR/basesystem"
echo "[DEBUG] WORKDIR/asr_target: $WORKDIR/asr_target"
hdiutil detach -force "$WORKDIR/basesystem" || true
hdiutil detach -force "$WORKDIR/asr_target" || true

# Ensure sparseimage is fully detached before re-attaching
for dev in $(hdiutil info | awk -v img="$WORKDIR/ASR_Installer.sparseimage" '
  BEGIN {dev=""}
  /^\/dev\// {dev=$1}
  $0 ~ img && dev != "" {print dev}
'); do
  if [ ! -e "$dev" ]; then
    echo "[DEBUG] Device $dev already gone, skipping."
    continue
  fi
  echo "[DEBUG] Forcibly detaching lingering device $dev"
  if hdiutil detach -force "$dev"; then
  continue
  fi
  if diskutil unmountDisk force "$dev"; then
  continue
  fi
  diskutil eject "$dev" || true
done

sleep 2
# Wait for sparseimage to be fully released before re-attaching
for i in {1..10}; do
  # Directly kill any process holding the image open
  PIDS=$(lsof | grep "$WORKDIR/ASR_Installer.sparseimage" | awk '{print $2}' | sort -u)
  if [ -n "$PIDS" ]; then
    for pid in $PIDS; do
      echo "[DEBUG] Killing process $pid holding sparseimage open"
      kill -9 $pid || true
    done
    sleep 2
    # Re-check and forcibly detach device nodes if still present
    for dev in $(hdiutil info | awk -v img="$WORKDIR/ASR_Installer.sparseimage" '
      BEGIN {dev=""}
      /^\/dev\// {dev=$1}
      $0 ~ img && dev != "" {print dev}
    '); do
      echo "[DEBUG] Forcibly detaching lingering device $dev"
      hdiutil detach -force "$dev" || true
      diskutil unmountDisk force "$dev" || true
      diskutil eject "$dev" || true
    done
    sleep 1
  fi

  if hdiutil attach "$WORKDIR/ASR_Installer.sparseimage" -noverify -nobrowse -mountpoint "$WORKDIR/asr_target_rw"; then
    break
  else
    echo "Waiting for sparseimage to be released (attempt $i)..."
    sleep 2
  fi

  if [ $i -eq 10 ]; then
    echo "❌ Failed to re-attach sparseimage after multiple attempts"
    exit 1
  fi

done
RESTORED_VOLUME="$WORKDIR/asr_target_rw"

# Remove Packages symlink/dir and copy full Packages
if [ -L "$RESTORED_VOLUME/System/Installation/Packages" ]; then
  unlink "$RESTORED_VOLUME/System/Installation/Packages"
elif [ -e "$RESTORED_VOLUME/System/Installation/Packages" ]; then
  rm -rf "$RESTORED_VOLUME/System/Installation/Packages"
fi
if [ -d "$WORKDIR/installesd/Packages" ]; then
  cp -R "$WORKDIR/installesd/Packages" "$RESTORED_VOLUME/System/Installation/"
else
  echo "❌ Packages directory not found in InstallESD"
  exit 1
fi

# Copy BaseSystem.dmg and chunklist
cp "$WORKDIR/installesd/BaseSystem.dmg" "$RESTORED_VOLUME/"
if [ -f "$WORKDIR/installesd/BaseSystem.chunklist" ]; then
  cp "$WORKDIR/installesd/BaseSystem.chunklist" "$RESTORED_VOLUME/"
fi

# Bless the system
if [ -d "$RESTORED_VOLUME/System/Library/CoreServices" ]; then
  bless --folder "$RESTORED_VOLUME/System/Library/CoreServices" --bootinfo --label "$VOLUME_NAME"
else
  echo "❌ CoreServices not found for blessing"
  exit 1
fi

# Detach restored volume
robust_detach "$RESTORED_VOLUME"

# Compact and convert to DMG/ISO
VNAME=""
case "$VERSION" in
  10.10) VNAME="Yosemite" ;;
  10.11) VNAME="El_Capitan" ;;
  10.12) VNAME="Sierra" ;;
esac
DMG_OUT="$WORKDIR/macOS-${VNAME}.dmg"
ISO_OUT="$WORKDIR/macOS-${VNAME}.iso"

# Compact and resize
echo "📏 Compacting sparse image..."
hdiutil compact "$WORKDIR/ASR_Installer.sparseimage" || echo "⚠️  Compact failed but continuing..."
echo "📐 Resizing to minimum size..."
hdiutil resize -size min "$WORKDIR/ASR_Installer.sparseimage" || echo "⚠️  Resize failed but continuing..."
echo "✅ Image optimization completed"

# Remove any previous outputs
rm -f "$DMG_OUT" "$ISO_OUT" "$WORKDIR/macOS-${VNAME}.cdr"

echo "💿 Creating DMG for $VNAME..."
hdiutil convert "$WORKDIR/ASR_Installer.sparseimage" -format UDZO -o "$WORKDIR/macOS-${VNAME}" -verbose
if [ -f "$WORKDIR/macOS-${VNAME}.dmg" ]; then
  echo "✅ DMG created successfully"
  echo "📊 Size: $(ls -lh \"$WORKDIR/macOS-${VNAME}.dmg\" | awk '{print $5}')"
else
  echo "❌ DMG not created as expected"
fi

echo "💿 Creating ISO for $VNAME..."
hdiutil convert "$WORKDIR/ASR_Installer.sparseimage" -format UDTO -o "$WORKDIR/macOS-${VNAME}" -verbose
if [ -f "$WORKDIR/macOS-${VNAME}.cdr" ]; then
  mv "$WORKDIR/macOS-${VNAME}.cdr" "$ISO_OUT"
  echo "✅ ISO created successfully"
  echo "📊 Size: $(ls -lh \"$ISO_OUT\" | awk '{print $5}')"
else
  echo "❌ ISO not created as expected"
fi

# Cleanup mounts
robust_detach "$WORKDIR/installesd" 2>/dev/null || true
robust_detach "$WORKDIR/mnt"
echo "🧹 Cleanup complete."

echo ""
echo "🎉 SUCCESS! $VNAME installer created successfully!"
echo ""
echo "📁 Created files:"
if [ -f "$DMG_OUT" ]; then
  echo "   • DMG: $(ls -lh \"$DMG_OUT\" | awk '{print $5}')"
fi
if [ -f "$ISO_OUT" ]; then
  echo "   • ISO: $(ls -lh \"$ISO_OUT\" | awk '{print $5}')"
fi
echo ""
echo "✅ Ready for VM deployment!"
