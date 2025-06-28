#!/bin/bash
set -e
set -x
# Download macOS installer for 10.10-10.12 (Direct URL)
# No arguments needed, version and URLs are hardcoded for local testing

# Choose version here:
VERSION="10.10"
DOWNLOAD_URL="https://updates.cdn-apple.com/2019/cert/061-41343-20191023-02465f92-3ab5-4c92-bfe2-b725447a070d/InstallMacOSX.dmg"
EXPECTED_CHECKSUM="de869907ce4289fe948cbd2dea7479ff9c369bbf47b06d5cb5290d78fb2932c6"

# Download the installer
echo "📥 Downloading from: $DOWNLOAD_URL"
curl -v -L -# --retry 5 --retry-delay 5 -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15" -o "Installer.dmg" "$DOWNLOAD_URL"

# Verify checksum
echo "🔍 Verifying file integrity..."
ACTUAL_CHECKSUM=$(openssl dgst -sha256 Installer.dmg | cut -d' ' -f2)
if [ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
  echo "❌ Checksum verification failed!"
  echo "Expected: $EXPECTED_CHECKSUM"
  echo "Actual:   $ACTUAL_CHECKSUM"
  exit 1
fi
echo "✅ Checksum verified: $ACTUAL_CHECKSUM"
