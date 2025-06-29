#!/bin/bash
set -e
set -x
# Script: mavericks_full_installer_linux.sh
# Purpose: Download and prepare a full-size macOS Mavericks installer image from Apple Recovery API on Linux/WSL/Cygwin
# Combines: Download, verify, extract, expand, patch, and optional ISO creation
# Requires: curl, openssl, xxd, 7z, dmg2img, mount, sudo, cp, qemu-img, mkfs.hfsplus, kpartx, blkid, fdisk
# Optional: udisksctl (for fallback mounting), genisoimage (for ISO creation)
#
# WARNING: The Linux HFS+ driver is known to be unstable and will crash (kernel Oops) on ARM platforms (including Parallels VMs on Apple Silicon) during the copy step.
# This script is only reliable on x86_64 Linux or macOS. If you are on ARM Linux, ABORT NOW and use a different platform for the copy step.

# Abort on ARM Linux (HFS+ kernel Oops risk)
ARCH=$(uname -m)
KERNEL=$(uname -s)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ] || [ "$ARCH" = "armv7l" ]; then
  echo "❌ ERROR: This script cannot safely run on ARM Linux ($ARCH). The Linux HFS+ driver will crash during the copy step."
  echo "   Please use x86_64 Linux or macOS for this step. Aborting."
  exit 1
fi

# Check for required tools
for tool in curl openssl xxd 7z dmg2img mount sudo cp qemu-img mkfs.hfsplus kpartx blkid fdisk; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "❌ Required tool '$tool' not found. Please install it."
    exit 1
  fi
done
# Optionally check for udisksctl and genisoimage (not fatal)
if ! command -v iconv >/dev/null 2>&1; then
  echo "⚠️ Optional tool 'iconv' not found. If missing, install 'libc-bin' or 'gawk'."
fi
if ! command -v od >/dev/null 2>&1; then
  echo "⚠️ Optional tool 'od' not found. If missing, install 'coreutils'."
fi
if ! command -v udisksctl >/dev/null 2>&1; then
  echo "⚠️ Optional tool 'udisksctl' not found. Some fallback mounting strategies may not be available."
fi
if ! command -v genisoimage >/dev/null 2>&1; then
  echo "⚠️ Optional tool 'genisoimage' not found. ISO creation will be skipped."
fi

# --- SECTION: Download and verify InstallESD.dmg ---
EXPECTED_CHECKSUM="c861fd59e82bf777496809a0d2a9b58f66691ee56738031f55874a3fe1d7c3ff"
TMPDIR="${TMPDIR:-/tmp}"

BOARD_ID="Mac-3CBD00234E554E41"


if [ -f macOS-Mavericks-InstallESD.dmg ]; then
  echo "✅ macOS-Mavericks-InstallESD.dmg already exists, skipping download and secrets."
else
  if [ -z "$BOARD_SERIAL_NUMBER" ]; then
    read -rp "Enter BOARD_SERIAL_NUMBER: " BOARD_SERIAL_NUMBER
  fi
  if [ -z "$ROM" ]; then
    read -rp "Enter ROM: " ROM
  fi
  hex_to_bin() {
    echo -n "$1" | xxd -r -p
  }
  echo "🔐 Authenticating with Apple recovery servers..."
  SERVER_ID=$(curl -fs -c - http://osrecovery.apple.com/ 2>/dev/null | tail -1 | awk '{print $NF}')
  if [ -z "$SERVER_ID" ]; then
    echo "❌ Failed to get server ID from Apple"
    exit 1
  fi
  echo "✅ Server ID obtained: $SERVER_ID"
  CLIENT_ID=$(dd if=/dev/urandom bs=8 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
  echo "✅ Client ID generated: $CLIENT_ID"
  {
    hex_to_bin "$CLIENT_ID"
    hex_to_bin "$(echo $SERVER_ID | awk -F'~' '{print $2}')"
    hex_to_bin "$ROM"
    printf "%s" "${BOARD_SERIAL_NUMBER}${BOARD_ID}" | iconv -t utf-8 | openssl dgst -sha256 -binary
    printf '\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC'
  } > "$TMPDIR/auth_info"
  K=$(openssl dgst -sha256 -binary < "$TMPDIR/auth_info" | od -An -tx1 | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
  rm "$TMPDIR/auth_info"
  echo "✅ Authentication key generated"
  echo "📦 Requesting Mavericks installer information..."
  echo "cid=$CLIENT_ID" > "$TMPDIR/post_data"
  echo "sn=$BOARD_SERIAL_NUMBER" >> "$TMPDIR/post_data"
  echo "bid=$BOARD_ID" >> "$TMPDIR/post_data"
  echo "k=$K" >> "$TMPDIR/post_data"
  echo "" >> "$TMPDIR/post_data"
  INSTALL_ESD_INFO=$(curl -s 'http://osrecovery.apple.com/InstallationPayload/OSInstaller' -X POST -H 'Content-Type: text/plain' -H 'User-Agent: InternetRecovery/1.0' --cookie "session=$SERVER_ID" --data-binary @"$TMPDIR/post_data")
  rm -f "$TMPDIR/post_data"
  INSTALL_ESD_URL=$(echo "$INSTALL_ESD_INFO" | grep "^AU:" | cut -d' ' -f2)
  INSTALL_ESD_ASSET_TOKEN=$(echo "$INSTALL_ESD_INFO" | grep "^AT:" | cut -d' ' -f2)
  if [ -z "$INSTALL_ESD_URL" ]; then
    echo "❌ Failed to get Mavericks download URL from Apple"
    echo "[DEBUG] INSTALL_ESD_INFO:"
    echo "$INSTALL_ESD_INFO"
    exit 1
  fi
  if [ -z "$INSTALL_ESD_ASSET_TOKEN" ]; then
    echo "❌ Asset token missing from Apple response."
    echo "[DEBUG] INSTALL_ESD_INFO:"
    echo "$INSTALL_ESD_INFO"
    exit 1
  fi
  echo "[DEBUG] INSTALL_ESD_URL: $INSTALL_ESD_URL"
  echo "[DEBUG] INSTALL_ESD_ASSET_TOKEN: $INSTALL_ESD_ASSET_TOKEN"
  echo "✅ Got authenticated download URL"
  echo "🔽 Downloading InstallESD.dmg..."
  curl -L "$INSTALL_ESD_URL" -H "Cookie: AssetToken=$INSTALL_ESD_ASSET_TOKEN" -o macOS-Mavericks-InstallESD.dmg
fi

# Verify checksum
if command -v openssl >/dev/null 2>&1; then
  ACTUAL_CHECKSUM=$(openssl dgst -sha256 macOS-Mavericks-InstallESD.dmg | awk '{print $NF}')
elif command -v certutil >/dev/null 2>&1; then
  ACTUAL_CHECKSUM=$(certutil -hashfile macOS-Mavericks-InstallESD.dmg SHA256 | awk 'NR==2{print $1}')
else
  echo "❌ No tool found for SHA256 checksum."
  exit 1
fi
if [ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
  echo "❌ Checksum verification failed!"
  exit 1
fi
echo "✅ InstallESD.dmg downloaded and verified ($(ls -lh macOS-Mavericks-InstallESD.dmg | awk '{print $5}'))"
cp macOS-Mavericks-InstallESD.dmg InstallESD.dmg

# Extract BaseSystem.dmg and Packages if not present
if [ ! -f BaseSystem.dmg ]; then
  echo "Extracting BaseSystem.dmg and Packages from $INSTALL_ESD_DMG ..."
  7z x "$INSTALL_ESD_DMG" -oInstallESD_extracted
  if [ -f InstallESD_extracted/OS\ X\ Install\ ESD/BaseSystem.dmg ]; then
    cp InstallESD_extracted/OS\ X\ Install\ ESD/BaseSystem.dmg BaseSystem.dmg
    echo "✅ Extracted BaseSystem.dmg."
  elif [ -f InstallESD_extracted/BaseSystem.dmg ]; then
    cp InstallESD_extracted/BaseSystem.dmg BaseSystem.dmg
    echo "✅ Extracted BaseSystem.dmg."
  else
    echo "❌ BaseSystem.dmg not found after extraction. Aborting."
    exit 1
  fi
  # Extract Packages if present
  if [ -d InstallESD_extracted/OS\ X\ Install\ ESD/Packages ]; then
    rm -rf Packages
    cp -a InstallESD_extracted/OS\ X\ Install\ ESD/Packages Packages
    echo "✅ Extracted Packages folder."
  elif [ -d InstallESD_extracted/Packages ]; then
    rm -rf Packages
    cp -a InstallESD_extracted/Packages Packages
    echo "✅ Extracted Packages folder."
  else
    echo "⚠️ Packages folder not found after extraction. Continuing without it."
  fi
fi

BASE_SYSTEM_DMG="BaseSystem.dmg"

# Convert BaseSystem.dmg to raw image
if [ ! -f BaseSystem.img ]; then
  dmg2img "$BASE_SYSTEM_DMG" BaseSystem.img
fi

# Create a new full-size HFS+ image for the installer (6.4GB)
if [ ! -f BaseSystem.full.img ]; then
  echo "Creating 6.4GB HFS+ image for full installer..."
  qemu-img create -f raw BaseSystem.full.img 6.4G
  mkfs.hfsplus -v "MacOSXInstaller" BaseSystem.full.img
  echo "Mounting original and new images to copy contents..."
  sudo mkdir -p /mnt/basesystem-orig /mnt/basesystem-new

  # Cleanup function for kpartx/losetup
  cleanup_loopdev() {
    if [ -n "$LOOPDEV" ]; then
      sudo kpartx -d "$LOOPDEV" 2>/dev/null || true
      sudo losetup -d "$LOOPDEV" 2>/dev/null || true
    fi
  }
  trap cleanup_loopdev EXIT

  set +e
  sudo mount -o loop BaseSystem.img /mnt/basesystem-orig
  MOUNT_RESULT=$?
  set -e
  if [ $MOUNT_RESULT -eq 0 ]; then
    echo "Mounted BaseSystem.img directly."
    PARTITION_SUMMARY="Direct mount of BaseSystem.img succeeded."
  else
    echo "[DEBUG] 'mount -o loop BaseSystem.img' failed. File type info:"
    file BaseSystem.img
    echo "[DEBUG] Last 30 lines of dmesg after failed mount:"
    dmesg | tail -30
    # Try kpartx/losetup Apple partition map fallback
    if command -v kpartx >/dev/null 2>&1; then
      echo "[DEBUG] Attempting to map partitions with kpartx..."
      LOOPDEV=$(sudo losetup --show -f BaseSystem.img)
      sudo kpartx -a "$LOOPDEV"
      sleep 1
      PARTDEVS=(/dev/mapper/$(basename "$LOOPDEV")p*)
      if [ -e "${PARTDEVS[0]}" ]; then
        echo "[INFO] Found partition devices: ${PARTDEVS[*]}"
        for PARTDEV in "${PARTDEVS[@]}"; do
          echo "[INFO] Partition $PARTDEV type: $(sudo blkid "$PARTDEV" || file -s "$PARTDEV")"
          sudo mkdir -p /mnt/basesystem-orig-tmp
          if sudo mount "$PARTDEV" /mnt/basesystem-orig-tmp 2>/dev/null; then
            echo "[SUCCESS] Mounted $PARTDEV at /mnt/basesystem-orig-tmp."
            # Check for expected files
            if [ -e /mnt/basesystem-orig-tmp/System/Installation ]; then
              echo "[INFO] Found expected installer structure in $PARTDEV. Using this partition."
              PARTITION_SUMMARY="Mounted $PARTDEV (HFS+) containing installer."
              sudo umount /mnt/basesystem-orig-tmp
              sudo mount "$PARTDEV" /mnt/basesystem-orig
              KPARTX_MOUNTED=1
              break
            else
              echo "[INFO] $PARTDEV does not contain expected files."
              sudo umount /mnt/basesystem-orig-tmp
            fi
          else
            echo "[INFO] Could not mount $PARTDEV."
          fi
        done
        sudo rmdir /mnt/basesystem-orig-tmp
        if [ "${KPARTX_MOUNTED:-0}" != "1" ]; then
          echo "❌ Could not find a mountable HFS+ partition with expected files."
          cleanup_loopdev
          # Try udisksctl fallback
          if command -v udisksctl >/dev/null 2>&1; then
            echo "[DEBUG] Trying udisksctl loop-setup fallback..."
            UDISKS_LOOPDEV=$(udisksctl loop-setup -f BaseSystem.img | awk '/Mapped file/ {print $NF}' | sed 's/\.//')
            if [ -n "$UDISKS_LOOPDEV" ] && [ -b "$UDISKS_LOOPDEV" ]; then
              echo "[INFO] udisksctl mapped: $UDISKS_LOOPDEV"
              for PART in $(ls ${UDISKS_LOOPDEV}p* 2>/dev/null); do
                echo "[INFO] Partition $PART type: $(sudo blkid "$PART" || file -s "$PART")"
                if udisksctl mount -b "$PART"; then
                  MNT_POINT=$(lsblk -no MOUNTPOINT "$PART" | head -n1)
                  if [ -n "$MNT_POINT" ] && [ -e "$MNT_POINT/System/Installation" ]; then
                    echo "[SUCCESS] Mounted $PART at $MNT_POINT with expected files."
                    PARTITION_SUMMARY="Mounted $PART (udisksctl) containing installer."
                    sudo mkdir -p /mnt/basesystem-orig
                    sudo mount --bind "$MNT_POINT" /mnt/basesystem-orig
                    UDISKS_MOUNTED=1
                    break
                  else
                    echo "[INFO] $PART does not contain expected files."
                    udisksctl unmount -b "$PART"
                  fi
                else
                  echo "[INFO] Could not mount $PART with udisksctl."
                fi
              done
              if [ "${UDISKS_MOUNTED:-0}" != "1" ]; then
                echo "❌ Could not find a mountable HFS+ partition with expected files using udisksctl."
                echo "You may try mounting the image manually using your desktop GUI or udisksctl."
                exit 1
              fi
            else
              echo "❌ udisksctl could not map the image."
              exit 1
            fi
          else
            echo "❌ No partition device found via kpartx, and udisksctl not available."
            cleanup_loopdev
            exit 1
          fi
        fi
      else
        echo "❌ No partition device found via kpartx."
        cleanup_loopdev
        exit 1
      fi
    else
      SECTOR_SIZE=512
      PART_START=$(fdisk -l BaseSystem.img | awk '/HFS/ {print $2; exit}')
      if [ -n "$PART_START" ]; then
        OFFSET=$((PART_START * SECTOR_SIZE))
        echo "Mounting BaseSystem.img at offset $OFFSET..."
        if ! sudo mount -o loop,offset=$OFFSET BaseSystem.img /mnt/basesystem-orig; then
          echo "❌ Could not mount BaseSystem.img at offset $OFFSET."
          exit 1
        fi
        echo "Mounted BaseSystem.img at offset $OFFSET."
        PARTITION_SUMMARY="Mounted BaseSystem.img at offset $OFFSET."
      else
        echo "❌ Could not mount BaseSystem.img directly and no HFS+ partition found."
        exit 1
      fi
    fi
  fi
  sudo mount -o loop BaseSystem.full.img /mnt/basesystem-new
  echo "Copying all files from original to new image..."
  sudo cp -a /mnt/basesystem-orig/. /mnt/basesystem-new/
  sudo umount /mnt/basesystem-orig
  sudo umount /mnt/basesystem-new
  cleanup_loopdev
  trap - EXIT
  echo "✅ Created and populated BaseSystem.full.img."
  echo "[SUMMARY] $PARTITION_SUMMARY"
fi

# Use BaseSystem.full.img for all further steps
SPARSE_IMG=BaseSystem.full.img

# Mount the new full-size image
sudo mkdir -p /mnt/basesystem
MOUNTED=0
if sudo mount -o loop "$SPARSE_IMG" /mnt/basesystem; then
  MOUNTED=1
else
  echo "⚠️ Default mount failed, trying -t hfsplus..."
  if sudo mount -o loop -t hfsplus "$SPARSE_IMG" /mnt/basesystem; then
    MOUNTED=1
  else
    echo "❌ Failed to mount $SPARSE_IMG. Aborting."
    exit 1
  fi
fi
if [ $MOUNTED -ne 1 ]; then
  echo "❌ Failed to mount $SPARSE_IMG. Aborting."
  exit 1
fi

# Ensure Packages folder is present before copy step
if [ ! -d Packages ]; then
  echo "[INFO] Packages folder not found in current directory. Attempting to extract from $INSTALL_ESD_DMG ..."
  7z x "$INSTALL_ESD_DMG" -oInstallESD_extracted
  if [ -d InstallESD_extracted/OS\ X\ Install\ ESD/Packages ]; then
    cp -a InstallESD_extracted/OS\ X\ Install\ ESD/Packages Packages
    echo "✅ Extracted Packages folder."
  elif [ -d InstallESD_extracted/Packages ]; then
    cp -a InstallESD_extracted/Packages Packages
    echo "✅ Extracted Packages folder."
  else
    echo "⚠️ Packages folder could not be found or extracted. Continuing without it."
  fi
fi

# Replace Packages symlink with real directory
if [ -d Packages ]; then
  echo "Detected Packages folder in current directory. Copying to BaseSystem."
  sudo rm -rf /mnt/basesystem/System/Installation/Packages
  sudo cp -a Packages /mnt/basesystem/System/Installation/
else
  echo "No Packages folder found in current directory. Skipping Packages copy."
fi

# Unmount image
sudo umount /mnt/basesystem

# Clean up extracted files if they exist
if [ -d BaseSystem_extracted ]; then
  rm -rf BaseSystem_extracted
  echo "[INFO] Cleaned up BaseSystem_extracted temporary files."
fi

# Optionally, create an ISO from the modified image
if command -v genisoimage >/dev/null 2>&1; then
  sudo mkdir -p /mnt/basesystem
  sudo mount -o loop "$SPARSE_IMG" /mnt/basesystem
  genisoimage -V "Install OS X Mavericks" -o InstallMacOSXMavericks.iso -r -J /mnt/basesystem
  sudo umount /mnt/basesystem
  echo "✅ Created InstallMacOSXMavericks.iso from modified $SPARSE_IMG"
else
  echo "genisoimage not found, skipping ISO creation. You can use $SPARSE_IMG as a raw image."
fi

# Clean up
# rm -f BaseSystem.sparse.img

echo "Successfully prepared full-size macOS installer image."
