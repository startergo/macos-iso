#!/bin/bash

# Enhanced Legacy macOS Download workflow (10.7-10.8) with bootable ISO creation
# This creates properly bootable ISOs for VM usage

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to cleanup on exit or error
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_status "Cleaning up temporary files due to error..."
        
        # Clean up mounted volumes
        for mount_point in "/Volumes/LegacyInstaller" "/Volumes/macOS Mountain Lion" "/Volumes/macOS Lion" "/Volumes/Legacy Bootable" "/Volumes/InstallESD"; do
            if mount | grep -q "$mount_point"; then
                print_status "Unmounting $mount_point"
                hdiutil detach "$mount_point" -force 2>/dev/null || true
            fi
        done
        
        # Clean up temporary files
        rm -f /tmp/legacy-installer.dmg
        rm -f /tmp/installer.pkg
        rm -rf /tmp/pkg_extract*
        rm -rf /tmp/payload_extract*
        rm -rf /tmp/Applications
        rm -f /tmp/macOS-legacy.dmg
        rm -f /tmp/macOS-legacy.cdr
        rm -f /tmp/InstallESD.dmg
        rm -f /tmp/bootable-legacy.dmg
        rm -f /tmp/bootable-legacy.cdr
        
        print_error "Script failed with exit code $exit_code"
    fi
    
    exit $exit_code
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Check if version is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <version>"
    echo "Available versions:"
    echo "  10.8   - Mountain Lion"
    echo "  10.7   - Lion"
    exit 1
fi

VERSION="$1"

# Set version details
case "$VERSION" in
    "10.8")
        VERSION_NAME="Mountain Lion"
        DOWNLOAD_URL="https://updates.cdn-apple.com/2021/macos/031-0627-20210614-90D11F33-1A65-42DD-BBEA-E1D9F43A6B3F/InstallMacOSX.dmg"
        TAG="10.8-mountain-lion"
        ;;
    "10.7")
        VERSION_NAME="Lion"
        DOWNLOAD_URL="https://updates.cdn-apple.com/2021/macos/041-7683-20210614-E610947E-C7CE-46EB-8860-D26D71F0D3EA/InstallMacOSX.dmg"
        TAG="10.7-lion"
        ;;
    *)
        print_error "Unknown version: $VERSION"
        print_error "Supported versions: 10.8, 10.7"
        exit 1
        ;;
esac

print_status "Starting Enhanced Legacy macOS Bootable ISO creation for $VERSION_NAME ($VERSION)"
print_status "Download URL: $DOWNLOAD_URL"

# Step 1: Download legacy installer
print_status "🔽 Downloading macOS $VERSION_NAME ($VERSION)"

if curl -L -o /tmp/legacy-installer.dmg "$DOWNLOAD_URL"; then
    print_success "Download completed"
    print_status "File size: $(ls -lh /tmp/legacy-installer.dmg | awk '{print $5}')"
else
    print_error "Failed to download installer"
    exit 1
fi

# Step 2: Extract InstallESD.dmg from the legacy installer
print_status "📦 Extracting InstallESD.dmg from legacy installer..."

# Mount the downloaded DMG
if hdiutil attach /tmp/legacy-installer.dmg -noverify -nobrowse -mountpoint /Volumes/LegacyInstaller; then
    print_success "DMG mounted successfully"
else
    print_error "Failed to mount DMG"
    exit 1
fi

# Find the installer package
INSTALLER_PKG=$(find /Volumes/LegacyInstaller -name "*.pkg" -type f | head -n 1)

if [ -z "$INSTALLER_PKG" ]; then
    print_error "No installer package found in DMG"
    print_status "Contents of mounted DMG:"
    ls -la /Volumes/LegacyInstaller/
    exit 1
fi

print_success "Found installer package: $INSTALLER_PKG"

# Copy the package to a temporary location
cp "$INSTALLER_PKG" /tmp/installer.pkg
print_status "Package size: $(ls -lh /tmp/installer.pkg | awk '{print $5}')"

# Detach the DMG
hdiutil detach /Volumes/LegacyInstaller
print_success "Package extracted successfully"

# Step 3: Extract InstallESD.dmg from the package
print_status "📦 Extracting InstallESD.dmg from package..."

# Use a unique directory name to avoid conflicts
EXTRACT_DIR="/tmp/pkg_extract_$$_$(date +%s)"

print_status "Using unique extraction directory: $EXTRACT_DIR"

# Extract the package contents using pkgutil
if pkgutil --expand /tmp/installer.pkg "$EXTRACT_DIR" 2>/dev/null; then
    print_success "Package expanded successfully with pkgutil"
else
    print_error "Failed to extract package"
    exit 1
fi

# Look for InstallESD.dmg in the package structure
print_status "🔍 Looking for InstallESD.dmg in extracted package structure..."

INSTALL_ESD=""

# Check common locations for InstallESD.dmg
if [ -f "$EXTRACT_DIR/InstallMacOSX.pkg/InstallESD.dmg" ]; then
    INSTALL_ESD="$EXTRACT_DIR/InstallMacOSX.pkg/InstallESD.dmg"
    print_success "Found InstallESD.dmg: $INSTALL_ESD"
elif [ -f "$EXTRACT_DIR/InstallOS.pkg/InstallESD.dmg" ]; then
    INSTALL_ESD="$EXTRACT_DIR/InstallOS.pkg/InstallESD.dmg"
    print_success "Found InstallESD.dmg: $INSTALL_ESD"
else
    # Search recursively
    INSTALL_ESD=$(find "$EXTRACT_DIR" -name "InstallESD.dmg" -type f | head -n 1)
    if [ -n "$INSTALL_ESD" ]; then
        print_success "Found InstallESD.dmg via search: $INSTALL_ESD"
    fi
fi

if [ -z "$INSTALL_ESD" ]; then
    print_error "InstallESD.dmg not found in package"
    print_status "Package structure:"
    find "$EXTRACT_DIR" -type f | head -20
    exit 1
fi

# Copy InstallESD.dmg to temp location
cp "$INSTALL_ESD" /tmp/InstallESD.dmg
print_status "InstallESD.dmg size: $(ls -lh /tmp/InstallESD.dmg | awk '{print $5}')"

# Clean up extraction directory
rm -rf "$EXTRACT_DIR"

# Step 4: Create bootable ISO from InstallESD.dmg
print_status "💿 Creating bootable ISO from InstallESD.dmg..."

# Mount the InstallESD.dmg to examine its structure
if hdiutil attach /tmp/InstallESD.dmg -noverify -nobrowse -mountpoint /Volumes/InstallESD; then
    print_success "InstallESD.dmg mounted successfully"
    
    print_status "InstallESD contents:"
    ls -la /Volumes/InstallESD/
    
    # Check if it has the proper boot files
    if [ -f "/Volumes/InstallESD/System/Library/CoreServices/boot.efi" ]; then
        print_success "Found boot.efi - this should be bootable"
    else
        print_warning "boot.efi not found - may not boot properly in VMs"
    fi
    
    # Check for BaseSystem.dmg which is needed for booting
    if [ -f "/Volumes/InstallESD/BaseSystem.dmg" ]; then
        print_success "Found BaseSystem.dmg - good for booting"
    else
        print_warning "BaseSystem.dmg not found"
    fi
    
    # Unmount InstallESD
    hdiutil detach /Volumes/InstallESD
    
    # Convert InstallESD.dmg directly to ISO with proper settings for booting
    print_status "Converting InstallESD.dmg to bootable ISO..."
    
    OUTPUT_ISO="macOS-$TAG-bootable.iso"
    
    # Use UDTO format with proper settings for VM compatibility
    if hdiutil convert /tmp/InstallESD.dmg -format UDTO -o "/tmp/bootable-legacy"; then
        if [ -f "/tmp/bootable-legacy.cdr" ]; then
            mv "/tmp/bootable-legacy.cdr" "$OUTPUT_ISO"
            print_success "Bootable ISO created successfully"
            print_status "Final ISO size: $(ls -lh "$OUTPUT_ISO" | awk '{print $5}')"
        else
            print_error "CDR file not found after conversion"
            exit 1
        fi
    else
        print_error "Failed to convert InstallESD.dmg to ISO"
        exit 1
    fi
    
else
    print_error "Failed to mount InstallESD.dmg"
    exit 1
fi

# Step 5: Verify the ISO structure
print_status "🔍 Verifying ISO structure..."

# Check ISO format and structure
print_status "ISO format information:"
hdiutil imageinfo "$OUTPUT_ISO" | grep -E "(Format|Partition|Bootable|Checksum)"

# Mount the ISO to verify contents
print_status "Mounting ISO to verify contents..."
if hdiutil attach "$OUTPUT_ISO" -noverify -nobrowse -mountpoint "/Volumes/Legacy Bootable"; then
    print_success "ISO mounted successfully for verification"
    
    print_status "ISO contents:"
    ls -la "/Volumes/Legacy Bootable/"
    
    # Check for essential boot files
    if [ -f "/Volumes/Legacy Bootable/System/Library/CoreServices/boot.efi" ]; then
        print_success "✓ boot.efi found in ISO"
    else
        print_warning "✗ boot.efi not found in ISO"
    fi
    
    if [ -f "/Volumes/Legacy Bootable/BaseSystem.dmg" ]; then
        print_success "✓ BaseSystem.dmg found in ISO"
    else
        print_warning "✗ BaseSystem.dmg not found in ISO"
    fi
    
    # Unmount verification
    hdiutil detach "/Volumes/Legacy Bootable"
    print_success "ISO verification completed"
else
    print_warning "Could not mount ISO for verification, but file was created"
fi

# Show VM setup instructions
echo ""
print_success "🖥️ Enhanced Virtual Machine Setup Instructions:"
echo "=============================================="
print_status "Your bootable ISO is ready! Size: $(ls -lh "$OUTPUT_ISO" | awk '{print $5}')"
echo ""
print_status "This ISO was created from the original InstallESD.dmg and should be properly bootable."
echo ""
print_status "For Parallels Desktop:"
echo "1. Create new VM → 'Install Windows or another OS from DVD or image file'"
echo "2. Select this ISO file: $OUTPUT_ISO"
echo "3. Choose 'macOS' as operating system"
echo "4. Configure VM with at least 4GB RAM and 64GB disk space"
echo "5. Boot from the ISO - it should boot directly to the macOS installer"
echo ""
print_status "For VMware Fusion:"
echo "1. Create new VM → 'Install from disc or image'"
echo "2. Select this ISO file: $OUTPUT_ISO"
echo "3. Choose 'Apple Mac OS X' and select the appropriate version"
echo "4. Boot from the ISO"
echo ""
print_status "For VirtualBox:"
echo "1. Create new VM → Type: Mac OS X, Version: Mac OS X (64-bit)"
echo "2. Attach the ISO to the virtual optical drive"
echo "3. Boot from the ISO"
echo ""
print_warning "If the ISO still doesn't boot:"
print_warning "1. Check VM settings - ensure UEFI/EFI boot is enabled"
print_warning "2. Try different VM software (Parallels often has better Mac support)"
print_warning "3. The InstallESD.dmg might need additional modifications for VM compatibility"

print_success "Enhanced Legacy macOS bootable ISO creation completed!"
print_status "Output file: $OUTPUT_ISO"

# Clean up temporary files on success
print_status "Cleaning up temporary files..."
rm -f /tmp/legacy-installer.dmg
rm -f /tmp/installer.pkg
rm -f /tmp/InstallESD.dmg
rm -f /tmp/bootable-legacy.cdr
print_success "Cleanup completed"
