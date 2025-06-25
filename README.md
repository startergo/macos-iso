# Create MacOS ISO

This repository provides automated workflows to create bootable macOS installers for virtualization. Choose the appropriate workflow based on your target macOS version:

| macOS Version | Workflow | Method | Output |
|---------------|----------|--------|--------|
| **10.9-10.12** | **Unified ASR VM Installer** | ASR Restore | DMG + ISO (VM-optimized) |
| **10.13+** | **Download** | Apple Software Update | ISO (minimal size) |
| **10.7-10.8** | **Enhanced Legacy macOS Download** | Direct InstallESD conversion | ISO (enhanced bootable) |

Steps from: https://osxdaily.com/2020/12/14/how-create-macos-big-sur-iso/

## Setup

1. **Fork this repository** to your own GitHub account
2. The workflow will automatically push ISO files to your forked repository's container registry

## Creating an ISO

This repository provides **three optimized workflows** to cover all macOS versions:

1. **Unified ASR VM Installer (10.9-10.12)** - Recommended for all versions 10.9-10.12
2. **Download (10.13+)** - For modern macOS versions  
3. **Enhanced Legacy macOS Download (10.7-10.8)** - Enhanced bootable method for oldest versions

### Unified ASR Workflow (10.9-10.12) - **Recommended**

The **Unified ASR VM Installer** workflow provides a single, consistent method for creating macOS 10.9-10.12 installers using the proven ASR (Apple Software Restore) method:

1. Go to the **Actions** tab in your forked repository
2. Click on the **Unified ASR VM Installer (10.9-10.12)** workflow
3. Click **Run workflow**
4. Select your desired macOS version:
   - `10.9 (Mavericks)`
   - `10.10 (Yosemite)`
   - `10.11 (El Capitan)`
   - `10.12 (Sierra)`
5. Choose output format:
   - **Both DMG and ISO** (recommended for testing)
   - **DMG only** (best for Parallels Desktop)
   - **ISO only** (best for VMware/VirtualBox)

**Key Benefits of the Unified ASR Workflow:**
- **Same proven method** for all versions 10.9-10.12
- **Automatic download handling**: Uses Recovery API for Mavericks, direct URLs for others
- **Full package copying**: Replaces symlinks with actual installer packages
- **Proper volume blessing**: Ensures reliable VM boot compatibility
- **Both formats**: Creates both DMG and ISO outputs when requested
- **VM-optimized**: Tested and verified across Parallels ✅, VMware, and VirtualBox

### Modern macOS (10.13+)

1. Go to the **Actions** tab in your forked repository
2. Click on the **Download** workflow
3. Click **Run workflow**
4. The workflow will first list all available macOS versions with their build numbers (e.g., `10.13.6-17G66`, `11.7.6-20G1231`)
5. Enter the macOS version you want to download in one of these formats:
   - **Version-Build format**: `10.15.7-19H2` (for precise selection)
   - **Version-only format**: `10.13.6` (works when only one build exists for that version)
6. The workflow will validate your input and automatically resolve it to the correct version-build combination
7. The ISO will be automatically created, optimized for minimal size, and pushed to your GitHub Container Registry

### Legacy macOS (10.7-10.8) - **Enhanced Bootable Method**
1. Go to the **Actions** tab in your forked repository
2. Click on the **Enhanced Legacy macOS Download (10.7-10.8)** workflow
3. Click **Run workflow**
4. Select from the dropdown menu:
   - `10.8 Mountain Lion`
   - `10.7 Lion`
5. The enhanced workflow will:
   - Download the official Apple DMG
   - Extract the InstallESD.dmg directly (preserving boot structure) 
   - Create a properly bootable ISO using UDTO format
   - Verify the ISO contains essential boot files (boot.efi, BaseSystem.dmg)
6. Enhanced ISOs are tagged with descriptive names (e.g., `10.8-mountain-lion`, `10.7-lion`)

**Enhanced Benefits:**
- **Direct InstallESD conversion**: Preserves original Apple boot structure
- **VM-optimized**: Tested and verified in Parallels ✅
- **Proper boot files**: Includes boot.efi and BaseSystem.dmg for reliable booting
- **UDTO format**: Optimized for VM platform compatibility

**Note**: Legacy installers often have expired certificates. The workflow automatically strips code signatures and bypasses certificate validation to ensure compatibility.

**Note**: If an ISO with the same version already exists in your registry, it will be **overwritten** with the new one.

## Technical Details

## Supported Input Formats

### Modern macOS (Download workflow):
- **Exact version-build**: `10.15.7-19H2`, `11.7.6-20G1231` (always works)
- **Version-only**: `10.13.6`, `12.4` (works when only one build exists for that version)
- **Invalid examples**: `10.15.7` (when multiple builds like 19H2, 19H15 exist - you must specify the build)

### Legacy macOS (Legacy Download workflow):
- **Dropdown selection only**: Choose from predefined options in the workflow interface

## Downloading an existing ISO

To download an ISO that has already been created and pushed to your registry:

```bash
# Install oras if not already installed
brew install oras

# Download Unified ASR installers (10.9-10.12) - Recommended method
oras pull ghcr.io/YOUR_USERNAME/macos-iso:Mavericks      # 10.9 outputs
oras pull ghcr.io/YOUR_USERNAME/macos-iso:Yosemite       # 10.10 outputs
oras pull ghcr.io/YOUR_USERNAME/macos-iso:El_Capitan     # 10.11 outputs  
oras pull ghcr.io/YOUR_USERNAME/macos-iso:Sierra         # 10.12 outputs

# Download modern macOS ISO (version-build format)
oras pull ghcr.io/YOUR_USERNAME/macos-iso:11.7.10-20G1427

# Download enhanced legacy macOS ISO (bootable format)
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.8-mountain-lion
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.7-lion
```

Replace `YOUR_USERNAME` with your GitHub username. You can only download versions that have been previously created through the workflows in your forked repository.

## Browsing Available ISOs

To see what macOS ISOs are available in your registry:

### Via GitHub Web Interface:
1. Go to your GitHub profile: `https://github.com/YOUR_USERNAME`
2. Click on the **Packages** tab
3. Look for the `macos-iso` package
4. Click on it to see all available versions/tags

### Via Command Line:
```bash
# List all available versions/tags
oras repo tags ghcr.io/YOUR_USERNAME/macos-iso

# Get detailed information about a specific version
oras manifest fetch ghcr.io/YOUR_USERNAME/macos-iso:11.7.6
```

### Direct URL:
You can also browse directly at: `https://github.com/YOUR_USERNAME?tab=packages&repo_name=macos-iso`

## Available macOS installers:
Finding available software
Software Update found the following full installers:
* Title: macOS Sequoia, Version: 15.5, Size: 15283299KiB, Build: 24F74, Deferred: NO
* Title: macOS Sequoia, Version: 15.4.1, Size: 15244333KiB, Build: 24E263, Deferred: NO
* Title: macOS Sequoia, Version: 15.4, Size: 15243957KiB, Build: 24E248, Deferred: NO
* Title: macOS Sequoia, Version: 15.3.2, Size: 14890483KiB, Build: 24D81, Deferred: NO
* Title: macOS Sequoia, Version: 15.3.1, Size: 14891477KiB, Build: 24D70, Deferred: NO
* Title: macOS Sonoma, Version: 14.7.6, Size: 13338327KiB, Build: 23H626, Deferred: NO
* Title: macOS Sonoma, Version: 14.7.5, Size: 13337289KiB, Build: 23H527, Deferred: NO
* Title: macOS Sonoma, Version: 14.7.4, Size: 13332546KiB, Build: 23H420, Deferred: NO
* Title: macOS Ventura, Version: 13.7.6, Size: 11910780KiB, Build: 22H625, Deferred: NO
* Title: macOS Ventura, Version: 13.7.5, Size: 11916960KiB, Build: 22H527, Deferred: NO
* Title: macOS Ventura, Version: 13.7.4, Size: 11915317KiB, Build: 22H420, Deferred: NO
* Title: macOS Monterey, Version: 12.7.4, Size: 12117810KiB, Build: 21H1123, Deferred: NO
* Title: macOS Big Sur, Version: 11.7.10, Size: 12125478KiB, Build: 20G1427, Deferred: NO
* Title: macOS Catalina, Version: 10.15.7, Size: 8055522KiB, Build: 19H2, Deferred: NO
* Title: macOS Catalina, Version: 10.15.7, Size: 8054879KiB, Build: 19H4, Deferred: NO
* Title: macOS Catalina, Version: 10.15.7, Size: 8055650KiB, Build: 19H15, Deferred: NO
* Title: macOS Catalina, Version: 10.15.6, Size: 8056662KiB, Build: 19G2006, Deferred: NO
* Title: macOS Catalina, Version: 10.15.6, Size: 8055450KiB, Build: 19G2021, Deferred: NO
* Title: macOS Catalina, Version: 10.15.5, Size: 8043778KiB, Build: 19F2200, Deferred: NO
* Title: macOS Catalina, Version: 10.15.4, Size: 8057341KiB, Build: 19E2269, Deferred: NO
* Title: macOS Catalina, Version: 10.15.3, Size: 7992550KiB, Build: 19D2064, Deferred: NO
* Title: macOS Mojave, Version: 10.14.6, Size: 5896894KiB, Build: 18G103, Deferred: NO
* Title: macOS Mojave, Version: 10.14.5, Size: 5892394KiB, Build: 18F2059, Deferred: NO
* Title: macOS Mojave, Version: 10.14.4, Size: 5894794KiB, Build: 18E2034, Deferred: NO
* Title: macOS High Sierra, Version: 10.13.6, Size: 5099306KiB, Build: 17G66, Deferred: NO

## Troubleshooting

### Unified ASR Workflow (10.9-10.12)
The unified ASR workflow resolves common issues:
- **Duplicate Mounts**: Prevents `/Volumes/OS X Base System 1` style duplicates
- **Resource Busy Errors**: Enhanced unmount logic with process cleanup
- **Workflow Failures**: Robust verification prevents "disk busy" termination

### Enhanced Legacy macOS (10.7-10.8)
- **Enhanced Bootability**: New method preserves original InstallESD.dmg boot structure
- **VM Compatibility**: Tested and verified in Parallels ✅
- **Boot File Verification**: Automatically checks for boot.efi and BaseSystem.dmg
- **UDTO Format**: Optimized conversion format for better VM compatibility

### Modern macOS (10.13+)
- **Version Not Found**: Use exact version-build format (`10.15.7-19H2` not `10.15.7`)
- **Download Failures**: Workflow includes automatic retry logic

### General Tips
- **Patience**: Legacy ISOs take 20-30 minutes due to complex extraction
- **Logs**: Check detailed workflow logs for troubleshooting
- **Storage**: Ensure sufficient space (4-15GB per ISO)