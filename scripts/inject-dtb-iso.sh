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
# We use the exact same options as the original ISO was built with, extracting
# the EFI partition image directly from the original ISO by sector range so the
# GPT structure is preserved exactly.

# Get the original ISO volume label
ORIG_LABEL=$(xorriso -indev "$INPUT_ISO" -report_el_torito as_mkisofs 2>/dev/null | grep "^-V " | sed "s/-V '//;s/'//")
ORIG_LABEL="${ORIG_LABEL:-Fedora-Workstation-Live}"
echo "Using volume label: $ORIG_LABEL"

# Get the original modification date to keep metadata consistent
ORIG_DATE=$(xorriso -indev "$INPUT_ISO" -report_el_torito as_mkisofs 2>/dev/null | grep "^--modification-date" | sed "s/--modification-date='//;s/'//")

# Extract the EFI partition sector info from the original ISO
# The appended EFI partition is referenced as:  -append_partition 2 <guid> --interval:...NNNNd-MMMMd::
APPEND_LINE=$(xorriso -indev "$INPUT_ISO" -report_el_torito as_mkisofs 2>/dev/null | grep "^-append_partition 2")
EFI_START=$(echo "$APPEND_LINE" | grep -oP '\d+(?=d-)')
EFI_END=$(echo "$APPEND_LINE" | grep -oP '(?<=d-)\d+(?=d::)')
EFI_GUID=$(echo "$APPEND_LINE" | awk '{print $3}')

echo "EFI partition: sectors $EFI_START to $EFI_END (GUID: $EFI_GUID)"

# Extract the EFI partition image directly from the original ISO by sector range
EFI_IMG="$WORK_DIR/efi_partition.img"
EFI_COUNT=$(( EFI_END - EFI_START + 1 ))
dd if="$INPUT_ISO" of="$EFI_IMG" bs=512 skip="$EFI_START" count="$EFI_COUNT" status=none
echo "Extracted EFI partition image: $(stat -c%s "$EFI_IMG") bytes"

# Extract the original MBR/GPT sectors (first 16 sectors) to replicate the exact
# protective MBR and any GPT entries
MBR_IMG="$WORK_DIR/mbr_sectors.img"
dd if="$INPUT_ISO" of="$MBR_IMG" bs=512 count=16 status=none

# Build the new ISO replicating the exact boot setup from the original
xorriso -as mkisofs \
    -iso-level 3 \
    -r -V "$ORIG_LABEL" \
    -J -joliet-long \
    --protective-msdos-label \
    -partition_cyl_align off \
    -partition_offset 16 \
    -append_partition 2 "$EFI_GUID" "$EFI_IMG" \
    -appended_part_as_gpt \
    -G "$MBR_IMG" \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    --boot-catalog-hide \
    -b boot/eltorito.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --grub2-boot-info \
    -eltorito-alt-boot \
    -e "--interval:appended_partition_2:all::" \
    -no-emul-boot \
    -boot-load-size "$EFI_COUNT" \
    -o "$OUTPUT_ISO" \
    "$WORK_DIR/iso_root"

echo "Done! Modified ISO saved to $OUTPUT_ISO"
