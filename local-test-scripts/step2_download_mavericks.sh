#!/bin/bash
set -e
set -x
# Download macOS Mavericks (10.9) installer using Apple Recovery API
# Secrets must be provided via environment variables

# BOARD_ID is public, so hardcode it here
BOARD_ID="Mac-3CBD00234E554E41"
EXPECTED_CHECKSUM="c861fd59e82bf777496809a0d2a9b58f66691ee56738031f55874a3fe1d7c3ff"

# If the installer is already downloaded, skip secrets and download logic
if [ -f macOS-Mavericks-InstallESD.dmg ]; then
  echo "✅ macOS-Mavericks-InstallESD.dmg already exists, skipping download and secrets."
else
  # Check for required secrets
  # : "${BOARD_SERIAL_NUMBER:?Must set BOARD_SERIAL_NUMBER env var}"
  # : "${ROM:?Must set ROM env var}"

  # Check for required secrets interactively
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
  # Get server session
  SERVER_ID=$(curl -v -fs -c - http://osrecovery.apple.com/ 2>/dev/null | tail -1 | awk '{print $NF}')
  if [ -z "$SERVER_ID" ]; then
    echo "❌ Failed to get server ID from Apple"
    exit 1
  fi
  echo "✅ Server ID obtained: $SERVER_ID"

  CLIENT_ID=$(dd if=/dev/urandom bs=8 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
  echo "✅ Client ID generated: $CLIENT_ID"

  # Generate authentication key
  {
      hex_to_bin "$CLIENT_ID"
      hex_to_bin "$(echo $SERVER_ID | awk -F'~' '{print $2}')"
      hex_to_bin "$ROM"
      printf "%s" "${BOARD_SERIAL_NUMBER}${BOARD_ID}" | iconv -t utf-8 | openssl dgst -sha256 -binary
      printf '\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC\xCC'
  } > auth_info
  K=$(openssl dgst -sha256 -binary < auth_info | od -An -tx1 | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
  rm auth_info
  echo "✅ Authentication key generated"

  echo "📦 Requesting Mavericks installer information..."
  # Create the data payload
  echo "cid=$CLIENT_ID" > /tmp/post_data
  echo "sn=$BOARD_SERIAL_NUMBER" >> /tmp/post_data
  echo "bid=$BOARD_ID" >> /tmp/post_data
  echo "k=$K" >> /tmp/post_data
  echo "" >> /tmp/post_data

  INSTALL_ESD_INFO=$(curl -s 'http://osrecovery.apple.com/InstallationPayload/OSInstaller' -X POST -H 'Content-Type: text/plain' -H 'User-Agent: InternetRecovery/1.0' --cookie "session=$SERVER_ID" --data-binary @/tmp/post_data)
  rm -f /tmp/post_data

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

  # Defensive: print the URL and token before using curl
  echo "[DEBUG] INSTALL_ESD_URL: $INSTALL_ESD_URL"
  echo "[DEBUG] INSTALL_ESD_ASSET_TOKEN: $INSTALL_ESD_ASSET_TOKEN"

  echo "✅ Got authenticated download URL"
  echo "🔽 Downloading InstallESD.dmg..."
  curl -L "$INSTALL_ESD_URL" -H "Cookie: AssetToken=$INSTALL_ESD_ASSET_TOKEN" -o macOS-Mavericks-InstallESD.dmg
fi

# Verify checksum
echo "🔍 Verifying file integrity..."
ACTUAL_CHECKSUM=$(openssl dgst -sha256 macOS-Mavericks-InstallESD.dmg | cut -d' ' -f2)
if [ "$ACTUAL_CHECKSUM" != "$EXPECTED_CHECKSUM" ]; then
  echo "❌ Checksum verification failed!"
  exit 1
fi
echo "✅ InstallESD.dmg downloaded and verified ($(ls -lh macOS-Mavericks-InstallESD.dmg | awk '{print $5}'))"
cp macOS-Mavericks-InstallESD.dmg InstallESD.dmg
