#!/bin/bash
set -e

# Usage: ./inject-dtb-iso.sh <input_iso> <output_iso> <dtb_file>
# Dependencies: xorriso, mtools

INPUT_ISO="$1"
OUTPUT_ISO="$2"
DTB_FILE="$3"

if [ -z "$INPUT_ISO" ] || [ -z "$OUTPUT_ISO" ] || [ -z "$DTB_FILE" ]; then
    echo "Usage: $0 <input_iso> <output_iso> <dtb_file>"
    exit 1
fi

# Temp work dir
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

echo "Extracting ISO contents..."
# Extract the entire ISO to a temporary directory
xorriso -osirrox on -indev "$INPUT_ISO" -extract / "$WORK_DIR/iso_root"

if [ ! -d "$WORK_DIR/iso_root" ]; then
    echo "Error: Could not extract ISO contents."
    exit 1
fi

echo "Copying DTB to ISO root..."
# Copy the DTB to the root of the ISO filesystem
cp "$DTB_FILE" "$WORK_DIR/iso_root/sc8280xp-lenovo-thinkpad-x13s.dtb"

# Verify it's there
ls -lh "$WORK_DIR/iso_root/sc8280xp-lenovo-thinkpad-x13s.dtb"

echo "Patching GRUB configuration..."
# Find and patch grub.cfg to include the devicetree command and kernel args
KERNEL_ARGS="efi=noruntime pd_ignore_unused clk_ignore_unused arm64.nopauth"

find "$WORK_DIR/iso_root" -name "grub.cfg" -type f | while read -r cfg; do
    echo "Patching $cfg"
    # Add kernel arguments to linux/linuxefi lines
    sed -i "s|linux .*|& $KERNEL_ARGS|g" "$cfg"
    sed -i "s|linuxefi .*|& $KERNEL_ARGS|g" "$cfg"
    
    # Add devicetree command after initrd/initrdefi lines
    # We use awk to insert the line right after initrd
    awk '/initrd/ {print; print "  devicetree /sc8280xp-lenovo-thinkpad-x13s.dtb"; next}1' "$cfg" > "${cfg}.tmp" && mv "${cfg}.tmp" "$cfg"
done

echo "Repacking ISO with xorriso (ARM64 UEFI configuration)..."
# ARM64 systems are strictly UEFI and do not use ISOLINUX or MBR boot code.
# We use xorriso to create a GPT partition table with the EFI boot image exposed as an ESP.

xorriso -as mkisofs \
    -r -V "Fedora-Workstation-Live" \
    -J -joliet-long \
    -e images/efiboot.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "$OUTPUT_ISO" \
    "$WORK_DIR/iso_root"

echo "Done! Modified ISO saved to $OUTPUT_ISO"
