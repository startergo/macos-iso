#!/bin/bash
set -e

# Step 1: Interactive version selection and export variables
source ./step1_set_version.sh

# Step 2: Download installer based on version
if [[ "$VERSION_NUM" == "10.9" ]]; then
  ./step2_download_mavericks.sh
else
  ./step2_download_installer.sh
fi

# Step 2b+: Continue with unified steps
./step2b_extract_installesd.sh
./step3_create_sparse_image.sh
./step4_mount_images.sh
./step5_asr_restore.sh
./step6_remount_rw.sh
./step7_validate_volume.sh
./step8_copy_packages.sh
./step9_bless_optimize.sh
./step10_create_dmg.sh
./step11_create_iso.sh

echo "✅ All steps completed successfully."
