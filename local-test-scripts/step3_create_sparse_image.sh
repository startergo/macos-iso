#!/bin/bash
set -e
set -x
# Create ASR Sparse Image for local testing (uses environment variables from step1_set_version.sh)

# Use VOLNAME from environment (exported by step1_set_version.sh)
SPARSE_IMG="/tmp/ASR_Installer.sparseimage"

# Remove existing sparse image if present
if [ -f "$SPARSE_IMG" ]; then
  echo "⚠️  Removing existing sparse image: $SPARSE_IMG"
  rm -f "$SPARSE_IMG"
fi

# Create a 10GB sparse image (adjust size as needed)
echo "🛠️ Creating sparse image: $SPARSE_IMG with volume name: $VOLNAME"
hdiutil create -size 10g -type SPARSE -fs HFS+J -volname "$VOLNAME" "$SPARSE_IMG"
echo "✅ Created sparse image: $SPARSE_IMG"
