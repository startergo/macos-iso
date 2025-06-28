# Create MacOS ISO

This repository provides automated workflows to create bootable macOS installers for virtualization. Choose the appropriate workflow based on your target macOS version:

| macOS Version    | Workflow                        | Method                    | Output                        |
|-----------------|----------------------------------|---------------------------|-------------------------------|
| **10.7-10.8**   | **Installer for macOS (10.7-10.8)** | Direct InstallESD conversion | DMG + ISO (enhanced bootable) |
| **10.9-10.12**  | **Installer for macOS (10.9-10.12)** | ASR Restore                 | DMG + ISO (VM-optimized)      |
| **10.13+**      | **Installer for macOS (10.13+)**     | Apple Software Update       | DMG + ISO

## Setup

1. **Fork this repository** to your own GitHub account
2. The workflow will automatically push ISO files to your forked repository's container registry

<details>
<summary><strong>Requirements for Mavericks (10.9) Recovery Workflow</strong></summary>

*Credit: Community research and extraction method by [Wowfunhappy](https://github.com/Wowfunhappy)*

To use the Mavericks (10.9) Recovery API workflow, you must extract secrets from a Mac that originally shipped from Apple with OS X Mavericks preinstalled. Only Macs with factory Mavericks installations will have valid secrets for this process.

**Supported Macs and Board IDs:**

| Model                                      | Board ID                  |
|---------------------------------------------|---------------------------|
| MacBook Air (11-inch, Mid 2013/Early 2014)  | Mac-35C1E88140C3E6CF      |
| MacBook Air (13-inch, Mid 2013/Early 2014)  | Mac-2E6FAB96566FE58C      |
| MacBook Pro (Retina, 13-inch, Late 2013/14) | Mac-189A3D4F975D5FFC      |
| MacBook Pro (Retina, 15-inch, Late 2013)    | Mac-F65AE981FFA204ED      |
| iMac (21.5-inch, Late 2013)                 | Mac-189A3D4F975D5FFC      |
| iMac (27-inch, Late 2013)                   | Mac-77EB7D7DAF985301      |
| Mac mini (Late 2014)                        | Mac-7DF21CB3ED6977E5      |
| Mac Pro (Late 2013)                         | Mac-F60DEB81FF30ACF6      |

**Instructions:**
- Use one of the above Macs to extract the required secrets (`BOARD_SERIAL` and `ROM`).
- The `BOARD_ID` is not a secret and must be set directly in the workflow file. If you use a different Mac model, update the `BOARD_ID` value in `.github/workflows/unified-asr.yml` to match your hardware's Board ID.
- Add `BOARD_SERIAL` and `ROM` as GitHub Actions secrets before running the Mavericks workflow.

</details>

## Creating an ISO

This repository provides **three optimized workflows** to cover all macOS versions:

1. **Installer for macOS (10.7-10.8)** - Enhanced bootable method for oldest versions
2. **Installer for macOS (10.9-10.12)** - Recommended for all versions 10.9-10.12
3. **Installer for macOS (10.13+)** - For modern macOS versions

### Legacy macOS (10.7-10.8) - **Enhanced Bootable Method**
1. Go to the **Actions** tab in your forked repository
2. Click on the **Installer for macOS (10.7-10.8)** workflow
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

### Unified ASR Workflow (10.9-10.12)

The **Installer for macOS (10.9-10.12)** workflow provides a single, consistent method for creating macOS 10.9-10.12 installers using the proven ASR (Apple Software Restore) method:

1. Go to the **Actions** tab in your forked repository
2. Click on the **Installer for macOS (10.9-10.12)** workflow
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

> **Reference:** Steps adapted from [OSXDaily: How to Create a MacOS Big Sur ISO File](https://osxdaily.com/2020/12/14/how-create-macos-big-sur-iso/)

1. Go to the **Actions** tab in your forked repository
2. Click on the **Installer for macOS 10.13+** workflow
3. Click **Run workflow**
4. The workflow will first list all available macOS versions with their build numbers (e.g., `10.13.6-17G66`, `11.7.6-20G1231`)
5. Enter the macOS version you want to download in one of these formats:
   - **Version-Build format**: `10.15.7-19H2` (for precise selection)
   - **Version-only format**: `10.13.6` (works when only one build exists for that version)
6. **Select the output format from the dropdown menu:**
   - `Both DMG and ISO` (default, recommended for most users)
   - `DMG only` (best for Parallels Desktop)
   - `ISO only` (best for VMware/VirtualBox)
7. The workflow will validate your input and automatically resolve it to the correct version-build combination
8. The selected artifact(s) will be created, optimized for minimal size, and pushed to your GitHub Container Registry:
   - **ISO**: `ghcr.io/YOUR_USERNAME/macos-iso:VERSION-BUILD`
   - **DMG**: `ghcr.io/YOUR_USERNAME/macos-iso:VERSION-BUILD-dmg`

> **Tip:** You can always download either artifact later using `oras pull` (see below for details).

## Supported Input Formats

### Installer for macOS (10.7-10.8):
- **Dropdown selection only**: Choose from predefined options in the workflow interface

### Installer for macOS (10.9-10.12):
- **Dropdown selection only**: Choose from predefined options in the workflow interface

### Modern macOS (10.13+):
- **Dropdown selection for output format**: Choose from `Both DMG and ISO` (default), `DMG only`, or `ISO only` in the workflow interface
- **Exact version-build**: `10.15.7-19H2`, `11.7.6-20G1231` (for precise selection)
- **Version-only**: `10.13.6`, `12.4` (works when only one build exists for that version)
- **Invalid examples**: `10.15.7` (when multiple builds like 19H2, 19H15 exist - you must specify the build)

## Downloading an existing ISO or DMG

To download an ISO or DMG that has already been created and pushed to your registry:

```bash
# Install oras if not already installed
brew install oras

# Download Unified ASR installers (10.9-10.12) - ISO
oras pull ghcr.io/YOUR_USERNAME/macos-iso:Mavericks-iso      # 10.9 ISO
oras pull ghcr.io/YOUR_USERNAME/macos-iso:Yosemite-iso       # 10.10 ISO
oras pull ghcr.io/YOUR_USERNAME/macos-iso:El_Capitan-iso     # 10.11 ISO
oras pull ghcr.io/YOUR_USERNAME/macos-iso:Sierra-iso         # 10.12 ISO

# Download Unified ASR installers (10.9-10.12) - DMG
oras pull ghcr.io/YOUR_USERNAME/macos-iso:Mavericks-dmg      # 10.9 DMG
oras pull ghcr.io/YOUR_USERNAME/macos-iso:Yosemite-dmg       # 10.10 DMG
oras pull ghcr.io/YOUR_USERNAME/macos-iso:El_Capitan-dmg     # 10.11 DMG
oras pull ghcr.io/YOUR_USERNAME/macos-iso:Sierra-dmg         # 10.12 DMG

# Download modern macOS ISO (version-build format)
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.13.6-17G66           # 10.13 ISO
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.14.6-18G103          # 10.14 ISO
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.15.7-19H15           # 10.15 ISO
oras pull ghcr.io/YOUR_USERNAME/macos-iso:12.7.4-21H1123          # Monterey ISO
oras pull ghcr.io/YOUR_USERNAME/macos-iso:13.7.6-22H625           # Ventura ISO
oras pull ghcr.io/YOUR_USERNAME/macos-iso:14.7.6-23H626           # Sonoma ISO

# Download modern macOS DMG (version-build-dmg format)
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.13.6-17G66-dmg       # 10.13 DMG
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.14.6-18G103-dmg      # 10.14 DMG
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.15.7-19H15-dmg       # 10.15 DMG
oras pull ghcr.io/YOUR_USERNAME/macos-iso:12.7.4-21H1123-dmg      # Monterey DMG
oras pull ghcr.io/YOUR_USERNAME/macos-iso:13.7.6-22H625-dmg       # Ventura DMG
oras pull ghcr.io/YOUR_USERNAME/macos-iso:14.7.6-23H626-dmg       # Sonoma DMG

# Download enhanced legacy macOS ISO (bootable format)
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.8-mountain-lion-iso  # 10.8 ISO
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.7-lion-iso           # 10.7 ISO

# Download enhanced legacy macOS DMG (bootable format)
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.8-mountain-lion-dmg  # 10.8 DMG
oras pull ghcr.io/YOUR_USERNAME/macos-iso:10.7-lion-dmg           # 10.7 DMG
```

Replace `YOUR_USERNAME` with your GitHub username. You can only download versions that have been previously created through the workflows in your forked repository.

## Browsing Available ISOs

To see what macOS ISOs are available in your registry:

### Via GitHub Web Interface:
1. Go to your GitHub profile: `https://github.com/YOUR_USERNAME`
2. Click on the **Packages** tab
3. Look for the `macos-iso` package
4. Click on it to see all available versions/tags

### Via Command Line (Terminal):
```bash
# List all available versions/tags in your registry
oras repo tags ghcr.io/YOUR_USERNAME/macos-iso

# Get detailed information about a specific version/tag
oras manifest fetch ghcr.io/YOUR_USERNAME/macos-iso:TAG
```
Replace `YOUR_USERNAME` with your GitHub username and `TAG` with the version/tag you want details for.

### Direct URL:
You can also browse directly at: `https://github.com/YOUR_USERNAME?tab=packages&repo_name=macos-iso`

<details>
<summary><strong>Available macOS installers</strong></summary>

Finding available software

**Apple Silicon (macos-latest) available versions:**

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

**Intel (macos-13) available versions:**

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

</details>

> **Note:** Some new macOS versions (Big Sur 11 and later: Big Sur, Monterey, Ventura, Sonoma, Sequoia, and all future releases) include a `corecrypto` component and other Apple Silicon–specific files in the installer. This is required for proper boot and security on Apple Silicon hardware. **However, when running these workflows on GitHub Actions (which uses Intel x86_64 runners), the downloaded installer will typically be the Intel version and may not include Apple Silicon–specific files like `corecrypto`.

## Supported Runners and Installer Availability

> **Important:**
> - **Apple Silicon runners** (`macos-latest`): Only support downloading macOS Big Sur (11) and later. These runners will fetch universal/Apple Silicon installers, including ARM-specific files like `corecrypto`. Installers for 10.13–10.15 (High Sierra, Mojave, Catalina) are **not available** on Apple Silicon runners.
> - **Intel runners** (`macos-13`): Required to download 10.13–10.15 installers. Use these runners if you need Intel-only or legacy installers.
> - **Recommendation:** If you want a universal/Apple Silicon installer, use `macos-latest`. If you need 10.13–10.15, use `macos-13`.

## Troubleshooting

<details>
<summary><strong>Unified ASR Workflow (10.9-10.12)</strong></summary>

The unified ASR workflow resolves common issues:
- **Duplicate Mounts**: Prevents `/Volumes/OS X Base System 1` style duplicates
- **Resource Busy Errors**: Enhanced unmount logic with process cleanup
- **Workflow Failures**: Robust verification prevents "disk busy" termination

</details>

<details>
<summary><strong>Installer for macOS (10.7-10.8)</strong></summary>

- **Enhanced Bootability**: New method preserves original InstallESD.dmg boot structure
- **VM Compatibility**: Tested and verified in Parallels ✅
- **Boot File Verification**: Automatically checks for boot.efi and BaseSystem.dmg
- **UDTO Format**: Optimized conversion format for better VM compatibility

</details>

<details>
<summary><strong>Modern macOS (10.13+)</strong></summary>

- **Version Not Found**: Use exact version-build format (`10.15.7-19H2` not `10.15.7`)
- **Download Failures**: Workflow includes automatic retry logic

</details>

<details>
<summary><strong>General Tips</strong></summary>

- **Patience**: Legacy ISOs take 20-30 minutes due to complex extraction
- **Logs**: Check detailed workflow logs for troubleshooting
- **Storage**: Ensure sufficient space (4-15GB per ISO)

</details>

## Selecting the Runner Type (Intel or Apple Silicon)

You can now choose which GitHub Actions runner to use for the Download workflow:

- **Intel (macos-13):** Required for downloading macOS 10.13–10.15 (High Sierra, Mojave, Catalina) installers. Select this if you need legacy or Intel-only installers.
- **Apple Silicon (macos-latest):** Use this to download universal/Apple Silicon installers (Big Sur/11 and later). 10.13–10.15 are not available on Apple Silicon runners.

When running the workflow, use the **Runner type** dropdown to select either `macos-13` (Intel) or `macos-latest` (Apple Silicon) as needed. Only the job matching your selection will run.
