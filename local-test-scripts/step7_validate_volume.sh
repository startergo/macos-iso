#!/bin/bash
set -e
# Validate and Prepare Restored Volume for local testing
TARGET_MOUNT="/tmp/target"
echo "🔍 Validating restored volume..."
if [ -L "$TARGET_MOUNT/System/Installation/Packages" ]; then
  echo "Packages is a symlink, will replace with full directory."
  sudo rm "$TARGET_MOUNT/System/Installation/Packages"
fi
echo "Validation complete."
