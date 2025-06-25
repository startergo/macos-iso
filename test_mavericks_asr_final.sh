#!/bin/bash

# Enhanced macOS Mavericks (10.9) ISO Creator with ASR Method
# Unified script matching GitHub Actions workflow logic
# Includes comprehensive error handling, validation, and cleanup

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ISO_CREATED_SUCCESSFULLY=false

# Color functions
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }

# Enhanced trap function for comprehensive cleanup
cleanup() {
    local exit_code=$?
    echo ""
    yellow "🧹 Performing cleanup..."
    
    # List of known mount points to clean up
    local mount_points=(
        "/tmp/mavericks_installesd"
        "/tmp/mavericks_basesystem"
        "/tmp/mavericks_target"
        "/tmp/mavericks_target_rw"
    )
    
    # Detach known mount points quietly
    for mount_point in "${mount_points[@]}"; do
        if mount | grep -q "$mount_point"; then
            hdiutil detach "$mount_point" -force 2>/dev/null || true
        fi
    done
    
    # Clean up any remaining BaseSystem volumes (created by ASR)
    while IFS= read -r line; do
        if [[ "$line" =~ .*\ on\ (.*)\ \(.* ]]; then
            vol="${BASH_REMATCH[1]}"
            if [ -n "$vol" ] && [ -d "$vol" ]; then
                hdiutil detach "$vol" -force 2>/dev/null || true
            fi
        fi
    done < <(mount | grep -E "OS X Base System|Mac OS X Base System" 2>/dev/null || true)
    
    # Clean up temporary files (but preserve the final images if successfully created)
    rm -f /tmp/asr_output.log 2>/dev/null || true
    rm -f "/tmp/InstallMacOS_Mavericks_ASR.sparseimage" 2>/dev/null || true
    rm -f "/tmp/mavericks_iso.cdr" 2>/dev/null || true
    
    # Only show cleanup completion if this isn't a successful exit
    if [ $exit_code -ne 0 ]; then
        yellow "✅ Cleanup completed (error occurred)"
    else
        yellow "✅ Cleanup completed"
    fi
}

trap cleanup EXIT INT TERM

# Input validation
if [ "$#" -ne 1 ]; then
    red "❌ Usage: $0 <path-to-InstallESD.dmg>"
    red "   Example: $0 /path/to/InstallESD.dmg"
    exit 1
fi

INSTALLESD_PATH="$1"

if [ ! -f "$INSTALLESD_PATH" ]; then
    red "❌ Error: InstallESD.dmg not found at: $INSTALLESD_PATH"
    exit 1
fi

echo "🍎 macOS Mavericks (10.9) Bootable Image Creator - ASR Method"
echo "📁 Input: $INSTALLESD_PATH"
echo "📦 Output: Both DMG and ISO formats"
echo ""

# Step 1: Create sparse image
blue "🔧 STEP 1: Creating sparse image"
if ! hdiutil create -size 7g -layout SPUD -fs "HFS+J" -volname "Install OS X Mavericks" -type SPARSE -o "/tmp/InstallMacOS_Mavericks_ASR"; then
    red "❌ Failed to create sparse image"
    exit 1
fi
green "✅ Sparse image created successfully"

# Step 2: Mount sparse image
blue "🔧 STEP 2: Mounting sparse image"
if ! hdiutil attach "/tmp/InstallMacOS_Mavericks_ASR.sparseimage" -noverify -nobrowse -mountpoint "/tmp/mavericks_target"; then
    red "❌ Failed to mount sparse image"
    exit 1
fi
green "✅ Sparse image mounted at /tmp/mavericks_target"

# Step 3: Mount InstallESD
blue "🔧 STEP 3: Mounting InstallESD.dmg"
if ! hdiutil attach "$INSTALLESD_PATH" -noverify -readonly -nobrowse -mountpoint "/tmp/mavericks_installesd"; then
    red "❌ Failed to mount InstallESD.dmg"
    exit 1
fi
green "✅ InstallESD.dmg mounted successfully"

# Step 4: Mount BaseSystem
blue "🔧 STEP 4: Mounting BaseSystem.dmg"
if [ ! -f "/tmp/mavericks_installesd/BaseSystem.dmg" ]; then
    red "❌ BaseSystem.dmg not found in InstallESD"
    exit 1
fi

if ! hdiutil attach "/tmp/mavericks_installesd/BaseSystem.dmg" -noverify -readonly -nobrowse -mountpoint "/tmp/mavericks_basesystem"; then
    red "❌ Failed to mount BaseSystem.dmg"
    exit 1
fi
green "✅ BaseSystem.dmg mounted successfully"

# Step 5: ASR restore
blue "🔧 STEP 5: ASR restore BaseSystem to target"
yellow "🚀 Starting ASR restore (this may take a few minutes)..."

TARGET_DISK=$(mount | grep "/tmp/mavericks_target" | awk '{print $1}')
blue "   Target disk: $TARGET_DISK"

if ! asr restore --source "/tmp/mavericks_basesystem" --target "$TARGET_DISK" --noprompt --noverify --erase 2>&1 | tee /tmp/asr_output.log; then
    red "❌ ASR restore failed"
    echo "🔍 ASR output:"
    cat /tmp/asr_output.log
    exit 1
fi

green "✅ ASR restore completed"

# Check for Error 22 (harmless for Mavericks)
if grep -q "error = 22" /tmp/asr_output.log; then
    yellow "ℹ️  Note: ASR reported 'error = 22' - this is harmless for Mavericks"
fi

# Step 6: Clean remount for read-write access
blue "🔧 STEP 6: Preparing read-write access"

# Detach all current mounts to avoid conflicts
hdiutil detach "/tmp/mavericks_basesystem" -force 2>/dev/null || true
hdiutil detach "/tmp/mavericks_target" -force 2>/dev/null || true

# Clean up ASR-created BaseSystem volumes quietly
mount | grep -E "OS X Base System|Mac OS X Base System" 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" =~ .*\ on\ (.*)\ \(.* ]]; then
        vol="${BASH_REMATCH[1]}"
        if [ -n "$vol" ] && [ -d "$vol" ]; then
            hdiutil detach "$vol" -force 2>/dev/null || true
        fi
    fi
done

sleep 2

# Remount sparse image for read-write access
yellow "🔄 Remounting sparse image for read-write access..."
if ! hdiutil attach "/tmp/InstallMacOS_Mavericks_ASR.sparseimage" -noverify -nobrowse -mountpoint "/tmp/mavericks_target_rw"; then
    red "❌ Failed to remount sparse image"
    exit 1
fi

RESTORED_VOLUME="/tmp/mavericks_target_rw"
green "✅ Sparse image remounted successfully"

# Step 7: Validate restored content
blue "🔧 STEP 7: Validating restored content"
if [ ! -d "$RESTORED_VOLUME/System/Library/CoreServices" ] || [ ! -d "$RESTORED_VOLUME/Install OS X Mavericks.app" ]; then
    red "❌ Required content missing after restore"
    echo "🔍 Available content:"
    ls -la "$RESTORED_VOLUME" | head -10
    exit 1
fi

# Verify read-write access
if ! touch "$RESTORED_VOLUME/test_write" 2>/dev/null; then
    red "❌ Volume is still read-only"
    exit 1
fi
rm -f "$RESTORED_VOLUME/test_write"
green "✅ Content validated and read-write access confirmed"

# Step 8: Copy installer packages (using proven method from working script)
blue "🔧 STEP 8: Copying installer packages"

# Check if Packages is a symlink (typical in BaseSystem) and remove it
if [ -L "$RESTORED_VOLUME/System/Installation/Packages" ]; then
    yellow "⚠️  Removing existing Packages symlink"
    unlink "$RESTORED_VOLUME/System/Installation/Packages"
elif [ -e "$RESTORED_VOLUME/System/Installation/Packages" ]; then
    yellow "⚠️  Removing existing Packages directory"
    rm -rf "$RESTORED_VOLUME/System/Installation/Packages"
fi

# Copy the full packages directory from InstallESD to replace the symlink
if [ -d "/tmp/mavericks_installesd/Packages" ]; then
    yellow "📦 Copying packages from InstallESD..."
    echo "   Source: /tmp/mavericks_installesd/Packages"
    echo "   Target: $RESTORED_VOLUME/System/Installation/"
    
    # Show source package count
    SOURCE_PKG_COUNT=$(find "/tmp/mavericks_installesd/Packages" -name "*.pkg" -o -name "*.mpkg" | wc -l)
    echo "   Source packages: $SOURCE_PKG_COUNT"
    
    if cp -R "/tmp/mavericks_installesd/Packages" "$RESTORED_VOLUME/System/Installation/"; then
        green "✅ Packages copied successfully"
        
        # Verify copy was successful
        if [ -d "$RESTORED_VOLUME/System/Installation/Packages" ]; then
            TARGET_PKG_COUNT=$(find "$RESTORED_VOLUME/System/Installation/Packages" -name "*.pkg" -o -name "*.mpkg" | wc -l)
            echo "   Target packages: $TARGET_PKG_COUNT"
            
            if [ "$SOURCE_PKG_COUNT" -eq "$TARGET_PKG_COUNT" ]; then
                green "✅ Package count verified - all packages copied"
            else
                yellow "⚠️  Package count mismatch - some packages may be missing"
            fi
            
            # Check if it's a real directory, not a symlink
            if [ -L "$RESTORED_VOLUME/System/Installation/Packages" ]; then
                red "❌ Packages is still a symlink after copy!"
                exit 1
            else
                green "✅ Packages is now a real directory (not symlink)"
            fi
        else
            red "❌ Packages directory not found after copy"
            exit 1
        fi
    else
        red "❌ Failed to copy packages"
        exit 1
    fi
else
    red "❌ Packages directory not found in InstallESD"
    exit 1
fi

# Step 9: Copy BaseSystem.dmg to target (CRITICAL FOR VM COMPATIBILITY)
blue "🔧 STEP 9: Copying BaseSystem.dmg to target"
if ! cp "/tmp/mavericks_installesd/BaseSystem.dmg" "$RESTORED_VOLUME/"; then
    red "❌ Failed to copy BaseSystem.dmg"
    exit 1
fi
green "✅ BaseSystem.dmg copied successfully"

# Step 10: Copy BaseSystem.chunklist if present
blue "🔧 STEP 10: Copying BaseSystem.chunklist (if present)"
if [ -f "/tmp/mavericks_installesd/BaseSystem.chunklist" ]; then
    if cp "/tmp/mavericks_installesd/BaseSystem.chunklist" "$RESTORED_VOLUME/"; then
        green "✅ BaseSystem.chunklist copied"
    else
        yellow "⚠️  Failed to copy BaseSystem.chunklist, but continuing..."
    fi
else
    yellow "ℹ️  BaseSystem.chunklist not found (normal for Mavericks)"
fi

# Step 11: Add volume icon and additional files (matching working script)
blue "🔧 STEP 11: Adding volume icon and additional files"

# Remove problematic symlinks and aliases (matching working script)
find "$RESTORED_VOLUME" -type l -name "Applications" -delete 2>/dev/null || true
find "$RESTORED_VOLUME" -name "Applications" -exec file {} \; | grep "alias" | cut -d: -f1 | xargs rm -f 2>/dev/null || true

# Copy additional Mavericks files if present (excluding installer app - already in BaseSystem)
for file in mach_kernel .IABootFiles .DS_Store; do
    if [ -e "/tmp/mavericks_installesd/$file" ]; then
        cp -R "/tmp/mavericks_installesd/$file" "$RESTORED_VOLUME/" 2>/dev/null || true
        green "✅ $file copied"
    fi
done

# Add volume icon for better VM recognition
if [ -f "$RESTORED_VOLUME/Install OS X Mavericks.app/Contents/Resources/InstallAssistant.icns" ]; then
    cp "$RESTORED_VOLUME/Install OS X Mavericks.app/Contents/Resources/InstallAssistant.icns" "$RESTORED_VOLUME/.VolumeIcon.icns" 2>/dev/null || true
    green "✅ Volume icon added"
else
    yellow "⚠️  InstallAssistant.icns not found, skipping volume icon"
fi

# Step 12: Set volume name to 'Install OS X Mavericks' (matching working script)
blue "🔧 STEP 12: Setting proper volume name"
# Use diskutil with the mount point - but don't update the variable until we verify it's still mounted
if diskutil rename "$RESTORED_VOLUME" "Install OS X Mavericks"; then
    green "✅ Volume renamed successfully"
    # Don't update RESTORED_VOLUME yet - wait to see if it's still mounted
else
    yellow "⚠️  Volume rename failed, continuing with current mount point"
fi

# Step 13: Bless the system folder for boot compatibility (matching working script)
blue "🔧 STEP 13: Blessing the system"

# After rename, check if the volume is still mounted at the original location or new location
yellow "🔍 Finding volume location after rename..."
FINAL_VOLUME=""

# Check if it's still at the original location
if [ -d "$RESTORED_VOLUME" ]; then
    FINAL_VOLUME="$RESTORED_VOLUME"
    green "✅ Volume still available at original location: $FINAL_VOLUME"
# Check if it moved to /Volumes/Install OS X Mavericks
elif [ -d "/Volumes/Install OS X Mavericks" ]; then
    FINAL_VOLUME="/Volumes/Install OS X Mavericks"
    green "✅ Volume moved to renamed location: $FINAL_VOLUME"
else
    # It may have been unmounted during rename - try to remount the sparse image
    yellow "⚠️  Volume not found after rename, attempting to remount..."
    
    # Try to mount the sparse image again
    if hdiutil attach "/tmp/InstallMacOS_Mavericks_ASR.sparseimage" -noverify -nobrowse 2>/dev/null; then
        # Look for the mounted volume
        sleep 2
        if [ -d "/Volumes/Install OS X Mavericks" ]; then
            FINAL_VOLUME="/Volumes/Install OS X Mavericks"
            green "✅ Successfully remounted volume: $FINAL_VOLUME"
        else
            # Find any volume that contains our system
            for vol in /Volumes/*; do
                if [ -d "$vol/System/Library/CoreServices" ] && [ -d "$vol/Install OS X Mavericks.app" ]; then
                    FINAL_VOLUME="$vol"
                    green "✅ Found system volume: $FINAL_VOLUME"
                    break
                fi
            done
        fi
    fi
fi

if [ -z "$FINAL_VOLUME" ] || [ ! -d "$FINAL_VOLUME" ]; then
    red "❌ Cannot find volume for blessing"
    echo "🔍 Available volumes:"
    ls -la /Volumes/ 2>/dev/null || true
    exit 1
fi

if [ -d "$FINAL_VOLUME/System/Library/CoreServices" ]; then
    bless --folder "$FINAL_VOLUME/System/Library/CoreServices" --bootinfo --label "Install OS X Mavericks"
    green "✅ Volume blessed successfully with label"
    # Update the variable for subsequent operations
    RESTORED_VOLUME="$FINAL_VOLUME"
else
    red "❌ Could not bless - CoreServices not found at: $FINAL_VOLUME/System/Library/CoreServices"
    echo "🔍 Available content:"
    ls -la "$FINAL_VOLUME" | head -10
    exit 1
fi

# Step 14: Detach all mounted volumes before optimization (critical sequence)
blue "🔧 STEP 14: Detaching all volumes for optimization"
# Enhanced detach logic to handle re-mounted volumes during the process and properly handle spaces in mount points
echo "🔍 Scanning for all volumes that need to be detached..."

# Detach BaseSystem volumes - process each line separately to handle spaces
echo "🔄 Detaching BaseSystem volume(s)..."
mount | grep -E "/tmp/mavericks_basesystem|OS X Base System|Mac OS X Base System" 2>/dev/null | while IFS= read -r line; do
    mount_point=$(echo "$line" | sed 's/^[^ ]* on \(.*\) (.*$/\1/')
    if [ -n "$mount_point" ] && [ -d "$mount_point" ]; then
        echo "   Detaching BaseSystem: '$mount_point'"
        if hdiutil detach "$mount_point" 2>/dev/null; then
            echo "   ✅ BaseSystem detached: '$mount_point'"
        else
            echo "   ⚠️ BaseSystem detach failed: '$mount_point'"
        fi
    fi
done

# Detach InstallESD volumes - process each line separately to handle spaces
echo "🔄 Detaching InstallESD volume(s)..."
mount | grep -E "/tmp/mavericks_installesd|InstallESD" 2>/dev/null | while IFS= read -r line; do
    mount_point=$(echo "$line" | sed 's/^[^ ]* on \(.*\) (.*$/\1/')
    if [ -n "$mount_point" ] && [ -d "$mount_point" ]; then
        echo "   Detaching InstallESD: '$mount_point'"
        # Try graceful detach first
        if hdiutil detach "$mount_point" 2>/dev/null; then
            echo "   ✅ InstallESD detached: '$mount_point'"
        else
            echo "   ⚠️ Graceful detach failed, trying force detach..."
            if hdiutil detach "$mount_point" -force 2>/dev/null; then
                echo "   ✅ InstallESD force detached: '$mount_point'"
            else
                echo "   ❌ InstallESD detach failed: '$mount_point'"
            fi
        fi
    fi
done

# Detach target volumes
echo "� Detaching target volume(s)..."
# Check for our target mount point specifically
if [ -n "$RESTORED_VOLUME" ] && mount | grep -F "$RESTORED_VOLUME" >/dev/null; then
    echo "   Detaching target: '$RESTORED_VOLUME'"
    if hdiutil detach "$RESTORED_VOLUME" 2>/dev/null; then
        echo "   ✅ Target detached: '$RESTORED_VOLUME'"
    else
        echo "   ⚠️ Target detach failed: '$RESTORED_VOLUME'"
    fi
elif mount | grep -q "/tmp/mavericks_target"; then
    echo "   Detaching target: '/tmp/mavericks_target'"
    if hdiutil detach "/tmp/mavericks_target" 2>/dev/null; then
        echo "   ✅ Target detached: '/tmp/mavericks_target'"
    else
        echo "   ⚠️ Target detach failed: '/tmp/mavericks_target'"
    fi
else
    echo "ℹ️  No target volumes to detach"
fi

green "✅ Primary detach operations completed"

# Step 15: Resize sparse image to minimum size (following proven sequence)
blue "🔧 STEP 15: Resize sparse image to minimum size"
echo "📏 Compacting sparse image to reduce final ISO size..."
hdiutil compact "/tmp/InstallMacOS_Mavericks_ASR.sparseimage" &
COMPACT_PID=$!

echo "⏳ Waiting for compact operation to complete..."
wait $COMPACT_PID && echo "✅ Compact completed" || echo "⚠️ Compact failed"

echo "� Resizing to minimum size..."
hdiutil resize -size min "/tmp/InstallMacOS_Mavericks_ASR.sparseimage" &
RESIZE_PID=$!

echo "📐 Resizing to minimum size..."
hdiutil resize -size min "/tmp/InstallMacOS_Mavericks_ASR.sparseimage" &
RESIZE_PID=$!

echo "⏳ Waiting for resize operation to complete..."
wait $RESIZE_PID && echo "✅ Resize completed" || echo "⚠️ Resize failed"

green "✅ Image size optimization completed"

# Step 16: Convert to ISO format (like other ASR versions) - using proven working method
blue "🔧 STEP 16: Convert to ISO format"
echo "🔄 Converting sparse image to ISO format..."
hdiutil convert "/tmp/InstallMacOS_Mavericks_ASR.sparseimage" -format UDTO -o "/tmp/InstallMacOS_Mavericks_ASR" &
CONVERT_PID=$!

echo "⏳ Waiting for conversion to complete..."
if wait $CONVERT_PID; then
    echo "✅ Conversion to ISO successful"
else
    echo "❌ Conversion failed, trying to force detach and retry..."
    # Force detach any remaining volumes
    hdiutil detach "/tmp/mavericks_installesd" -force 2>/dev/null &
    hdiutil detach "/tmp/mavericks_target" -force 2>/dev/null &
    
    # Wait for all force detaches
    wait
    
    echo "🔄 Retrying conversion..."
    hdiutil convert "/tmp/InstallMacOS_Mavericks_ASR.sparseimage" -format UDTO -o "/tmp/InstallMacOS_Mavericks_ASR" &
    RETRY_CONVERT_PID=$!
    
    if wait $RETRY_CONVERT_PID; then
        echo "✅ Conversion successful after force detach"
    else
        echo "❌ Conversion still failed"
        exit 1
    fi
fi

# Step 17: Rename CDR to ISO and create both formats
blue "🔧 STEP 17: Finalizing outputs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DMG_FILE="$SCRIPT_DIR/InstallMacOS_Mavericks_${TIMESTAMP}.dmg"
ISO_FILE="$SCRIPT_DIR/InstallMacOS_Mavericks_${TIMESTAMP}.iso"

# Move and rename the ISO
mv "/tmp/InstallMacOS_Mavericks_ASR.cdr" "$ISO_FILE"

if [ ! -f "$ISO_FILE" ]; then
    red "❌ Failed to create final ISO"
    exit 1
fi

# Create DMG version from the ISO
yellow "💿 Creating DMG format from ISO..."
if hdiutil convert "$ISO_FILE" -format UDZO -o "$DMG_FILE"; then
    green "✅ DMG created successfully"
else
    red "❌ Failed to create bootable DMG"
    exit 1
fi

# Mark images as successfully created
ISO_CREATED_SUCCESSFULLY=true

# Step 18: Final verification
blue "� STEP 18: Final verification"
echo "🔍 Final verification..."
hdiutil attach "$ISO_FILE" -noverify -readonly -mountpoint "/tmp/mavericks_final" 2>/dev/null

VOLUME_NAME=$(diskutil info /tmp/mavericks_final | grep "Volume Name" | cut -d: -f2 | xargs)
echo "✅ Final volume name: '$VOLUME_NAME'"

# Verify essential components
ESSENTIAL_COMPONENTS=(
    "/tmp/mavericks_final/System/Library/CoreServices"
    "/tmp/mavericks_final/System/Library/CoreServices/boot.efi"
    "/tmp/mavericks_final/System/Library/CoreServices/SystemVersion.plist"
    "/tmp/mavericks_final/System/Installation/Packages"
    "/tmp/mavericks_final/BaseSystem.dmg"
)

ALL_GOOD=true
for component in "${ESSENTIAL_COMPONENTS[@]}"; do
    if [ -e "$component" ]; then
        if [ -f "$component" ]; then
            SIZE=$(ls -lh "$component" | awk '{print $5}')
            echo "✅ $component ($SIZE)"
        else
            echo "✅ $component (directory)"
        fi
    else
        echo "❌ Missing: $component"
        ALL_GOOD=false
    fi
done

# Check for Mavericks-specific components
MAVERICKS_COMPONENTS=(
    "/tmp/mavericks_final/Install OS X Mavericks.app"
    "/tmp/mavericks_final/mach_kernel"
)

for component in "${MAVERICKS_COMPONENTS[@]}"; do
    if [ -e "$component" ]; then
        if [ -f "$component" ]; then
            SIZE=$(ls -lh "$component" | awk '{print $5}')
            echo "✅ $component ($SIZE)"
        else
            echo "✅ $component (directory)"
        fi
    else
        echo "ℹ️  Optional: $component (not found)"
    fi
done

# Check BaseSystem.chunklist separately as it may not exist in Mavericks
if [ -f "/tmp/mavericks_final/BaseSystem.chunklist" ]; then
    SIZE=$(ls -lh "/tmp/mavericks_final/BaseSystem.chunklist" | awk '{print $5}')
    echo "✅ /tmp/mavericks_final/BaseSystem.chunklist ($SIZE)"
else
    echo "ℹ️  BaseSystem.chunklist not found (may be normal for Mavericks)"
fi

# Package count
if [ -d "/tmp/mavericks_final/System/Installation/Packages" ]; then
    PKG_COUNT=$(find "/tmp/mavericks_final/System/Installation/Packages" -name "*.pkg" -o -name "*.mpkg" | wc -l)
    echo "📦 Package count: $PKG_COUNT"
    
    # Verify this is a real directory, not a symlink
    if [ -L "/tmp/mavericks_final/System/Installation/Packages" ]; then
        echo "⚠️  Packages is still a symlink (should be full directory for Mavericks)"
        ALL_GOOD=false
    else
        echo "✅ Packages is a full directory (correct for Mavericks)"
    fi
else
    echo "❌ Packages directory not found"
    ALL_GOOD=false
fi

# Check SystemVersion.plist for version info
if [ -f "/tmp/mavericks_final/System/Library/CoreServices/SystemVersion.plist" ]; then
    VERSION=$(defaults read "/tmp/mavericks_final/System/Library/CoreServices/SystemVersion.plist" ProductVersion 2>/dev/null || echo "Unknown")
    BUILD=$(defaults read "/tmp/mavericks_final/System/Library/CoreServices/SystemVersion.plist" ProductBuildVersion 2>/dev/null || echo "Unknown")
    echo "🏷️  System Version: $VERSION (Build: $BUILD)"
fi

# Cleanup verification mount
hdiutil detach "/tmp/mavericks_final" 2>/dev/null || true

if [ "$ALL_GOOD" = true ]; then
    DMG_SIZE=$(du -h "$DMG_FILE" | cut -f1)
    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
    
    green "✅ Validation completed successfully"

    green "✅ Validation completed successfully"
    
    echo ""
    echo "🎉 SUCCESS! Mavericks ASR ISO created successfully!"
    echo "📁 Location: $ISO_FILE"
    echo "� ISO Size: $ISO_SIZE"
    echo "📁 DMG Location: $DMG_FILE"
    echo "📊 DMG Size: $DMG_SIZE"
    echo ""
    echo "🔬 This ISO follows the same ASR workflow as 10.10-10.12:"
    echo "   • ASR restore instead of hdiutil convert"
    echo "   • Complete package copying"
    echo "   • Proper volume blessing"
    echo "   • ISO format for maximum VM compatibility"
    echo ""
    echo "💡 Next steps:"
    echo "   • For Parallels/VMware: Use the DMG file (recommended)"
    echo "   • For VirtualBox/other: Try the ISO file first, then DMG if needed"
    echo "   • Test both formats in your preferred virtual machine"
    echo "   • Verify they boot correctly"
    echo "   • Use for clean Mavericks installations"
    echo ""
    echo "ℹ️  Format notes:"
    echo "   • DMG: Apple's native format, excellent VM compatibility"
    echo "   • ISO: Standard format created using proven ASR method"
    echo ""
    echo "✅ If this works in VMs, we can unify all 10.9-10.12 under ASR method!"
else
    echo ""
    echo "❌ FAILED - Missing essential components"
    exit 1
fi
