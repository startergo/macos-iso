#!/bin/bash
set -e
# Post-ASR Detach and Remount for Read-Write for local testing
SPARSE_IMG="/tmp/ASR_Installer.sparseimage"
TARGET_MOUNT="/tmp/target"
echo "🔄 Ensuring target is mounted read-write..."
hdiutil detach "$TARGET_MOUNT" || true
sleep 2
hdiutil attach "$SPARSE_IMG" -noverify -mountpoint "$TARGET_MOUNT" -owners on
echo "Target remounted read-write."
