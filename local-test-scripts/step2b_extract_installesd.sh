#!/bin/bash
set -e
set -x
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect Mavericks (10.9) and skip extraction if so
if [[ "$VERSION_NUM" == "10.9" ]] || [[ "$VERSION_NAME" == "Mavericks" ]]; then
  echo "[step2b] Mavericks detected (10.9) – no PKG extraction needed. Skipping."
  exit 0
fi

# Extract InstallESD.dmg from Installer.dmg for 10.10–10.12 (identical to workflow logic)

# Mount Installer.dmg
INSTALLER_DMG="Installer.dmg"
MOUNT_POINT="/tmp/installer"

if [ ! -f "$INSTALLER_DMG" ]; then
  echo "Installer.dmg not found! Run step2_download_installer.sh first."
  exit 1
fi

echo "📦 Mounting $INSTALLER_DMG..."
hdiutil attach "$INSTALLER_DMG" -noverify -readonly -mountpoint "$MOUNT_POINT"

# Find PKG
PKG_FILE=$(find "$MOUNT_POINT" -name "*.pkg" | head -1)
if [ -z "$PKG_FILE" ]; then
  echo "❌ No PKG file found in $MOUNT_POINT"
  ls -la "$MOUNT_POINT"
  hdiutil detach "$MOUNT_POINT"
  exit 1
fi
echo "✅ Found PKG: $PKG_FILE"

# Extract PKG
mkdir -p /tmp/pkg_extract
cd /tmp/pkg_extract
xar -xf "$PKG_FILE"

# Find and extract payload
PAYLOAD_FILE=$(find . -type f \( -name "Payload" -o -name "*.pax.gz" \) | head -1)
if [ -z "$PAYLOAD_FILE" ]; then
  echo "❌ No payload found in PKG"
  find . -type f | head -10
  hdiutil detach "$MOUNT_POINT"
  exit 1
fi
echo "✅ Found payload: $PAYLOAD_FILE"

mkdir -p /tmp/payload_extract
cd /tmp/payload_extract
if [[ "$PAYLOAD_FILE" == *.pax.gz ]]; then
  echo "📦 Extracting pax.gz payload..."
  gunzip -c "../pkg_extract/$PAYLOAD_FILE" | pax -r
elif [[ "$PAYLOAD_FILE" == *Payload* ]]; then
  echo "📦 Extracting cpio payload..."
  cpio -i < "../pkg_extract/$PAYLOAD_FILE"
else
  echo "❌ Unknown payload format"
  hdiutil detach "$MOUNT_POINT"
  exit 1
fi

# Find InstallESD.dmg
INSTALLESD_DMG=$(find . -type f -name "InstallESD.dmg" | head -1)
if [ -z "$INSTALLESD_DMG" ]; then
  # Fallback: look inside .app bundles
  APP_BUNDLE=$(find . -type d -name "*.app" | head -1)
  if [ -n "$APP_BUNDLE" ]; then
    SHARED_SUPPORT_DMG="$APP_BUNDLE/Contents/SharedSupport/InstallESD.dmg"
    if [ -f "$SHARED_SUPPORT_DMG" ]; then
      INSTALLESD_DMG="$SHARED_SUPPORT_DMG"
      echo "✅ Found InstallESD.dmg inside app bundle: $INSTALLESD_DMG"
    fi
  fi
fi
if [ -z "$INSTALLESD_DMG" ]; then
  PKG_DIR=$(dirname "../pkg_extract/$PAYLOAD_FILE")
  if [ -f "$PKG_DIR/InstallESD.dmg" ]; then
    INSTALLESD_DMG="$PKG_DIR/InstallESD.dmg"
    echo "✅ Found InstallESD.dmg directly in PKG: $INSTALLESD_DMG"
    # Copy to payload_extract for consistency
    cp "$INSTALLESD_DMG" "$(pwd)/InstallESD.dmg"
    INSTALLESD_DMG="$(pwd)/InstallESD.dmg"
  fi
fi
if [ -z "$INSTALLESD_DMG" ]; then
  echo "❌ InstallESD.dmg not found in extracted payload, app bundle, or PKG root"
  find . -type f | head -20
  hdiutil detach "$MOUNT_POINT"
  exit 1
fi
# If not already in payload_extract, copy it there
if [ "$INSTALLESD_DMG" != "$(pwd)/InstallESD.dmg" ]; then
  cp "$INSTALLESD_DMG" "$(pwd)/InstallESD.dmg"
  INSTALLESD_DMG="$(pwd)/InstallESD.dmg"
fi
echo "✅ Final InstallESD.dmg location: $INSTALLESD_DMG"

# Always copy to script directory for downstream steps
cp "$INSTALLESD_DMG" "$SCRIPT_DIR/InstallESD.dmg"
echo "[step2b] Copied InstallESD.dmg to script dir: $SCRIPT_DIR/InstallESD.dmg"

# Always copy to workspace root for both CI and local runs, with debug output
if [ -n "$GITHUB_WORKSPACE" ]; then
  cp "$INSTALLESD_DMG" "$GITHUB_WORKSPACE/InstallESD.dmg"
  echo "[step2b] Copied InstallESD.dmg to CI workspace root: $GITHUB_WORKSPACE/InstallESD.dmg"
else
  # Try to resolve workspace root relative to script dir
  WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  cp "$INSTALLESD_DMG" "$WORKSPACE_ROOT/InstallESD.dmg"
  echo "[step2b] Copied InstallESD.dmg to local workspace root: $WORKSPACE_ROOT/InstallESD.dmg"
fi

# Detach installer mount
hdiutil detach "$MOUNT_POINT"
