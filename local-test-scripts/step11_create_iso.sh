#!/bin/bash
set -e
set -x
# Create ISO from the sparse image
SPARSE_IMG="/tmp/ASR_Installer.sparseimage"
# Remove version sourcing; assume variables are set by run_all.sh
VOLUME_NAME="${VOLNAME:-Install macOS}"
ISO_NAME="macOS-${VOLUME_NAME// /_}.iso"
echo "💿 Creating ISO: /tmp/$ISO_NAME from $SPARSE_IMG"
if hdiutil convert "$SPARSE_IMG" -format UDTO -o "/tmp/${ISO_NAME%.iso}.cdr"; then
  mv "/tmp/${ISO_NAME%.iso}.cdr" "/tmp/$ISO_NAME"
  echo "✅ ISO created: /tmp/$ISO_NAME"
  du -sh "/tmp/$ISO_NAME"
else
  echo "❌ Failed to create ISO"
  exit 1
fi
