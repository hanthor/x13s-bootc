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

echo "Extracting EFIBOOT image from $INPUT_ISO..."
# Extract the EFI system partition image. In Fedora/CentOS ISOs this is usually images/efiboot.img
xorriso -osirrox on -indev "$INPUT_ISO" -extract /images/efiboot.img "$WORK_DIR/efiboot.img"

if [ ! -f "$WORK_DIR/efiboot.img" ]; then
    echo "Error: Could not find /images/efiboot.img in the ISO. Is this a standard Fedora/Bluefin ISO?"
    exit 1
fi

echo "Injecting DTB into EFI image..."
# Use mcopy to copy the file into the FAT filesystem image
# We place it at the root of the ESP, where our earlier scripts expect it
mcopy -i "$WORK_DIR/efiboot.img" "$DTB_FILE" ::/sc8280xp-lenovo-thinkpad-x13s.dtb

# Verify it's there
mdir -i "$WORK_DIR/efiboot.img" ::/

echo "Repacking ISO..."
# Create a new ISO with the modified EFI image.
# We use xorriso to load the old ISO, replace the file, and write the new one.
# -boot_image any keep tells xorriso to preserve boot settings.
xorriso -dev "$INPUT_ISO" \
    -boot_image any keep \
    -map "$WORK_DIR/efiboot.img" /images/efiboot.img \
    -commit \
    -outdev "$OUTPUT_ISO"

echo "Done! Modified ISO saved to $OUTPUT_ISO"
