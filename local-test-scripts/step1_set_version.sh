#!/bin/bash
set -e
# Interactive version/parameter selection for local testing

echo "Select macOS version to create:" 
select VERSION in \
  "10.9 (Mavericks)" \
  "10.10 (Yosemite)" \
  "10.11 (El Capitan)" \
  "10.12 (Sierra)"; do
  case $REPLY in
    1) VERSION_NUM=10.9; VERSION_NAME=Mavericks; VOLNAME="Install OS X Mavericks"; ;;
    2) VERSION_NUM=10.10; VERSION_NAME=Yosemite; VOLNAME="Install OS X Yosemite"; ;;
    3) VERSION_NUM=10.11; VERSION_NAME=El_Capitan; VOLNAME="Install OS X El Capitan"; ;;
    4) VERSION_NUM=10.12; VERSION_NAME=Sierra; VOLNAME="Install macOS Sierra"; ;;
    *) echo "Invalid selection."; continue;;
  esac
  break
done

# Output and export for downstream scripts
export VERSION_NUM
export VERSION_NAME
export VOLNAME
export INSTALLER_VERSION="$VERSION_NUM"
export VOLUME_NAME="$VOLNAME"
echo "VERSION_NUM=$VERSION_NUM"
echo "VERSION_NAME=$VERSION_NAME"
echo "VOLNAME=$VOLNAME"
echo "INSTALLER_VERSION=$INSTALLER_VERSION"
echo "VOLUME_NAME=$VOLUME_NAME"
