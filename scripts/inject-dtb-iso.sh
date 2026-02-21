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

echo "Repacking ISO with mkisofs (preserving boot configuration)..."
# Use mkisofs to recreate the ISO with the same boot parameters

# Try to extract isohdpfx.bin from the original ISO (used for hybrid ISO), fallback to system version
MBR_FILE=""
if xorriso -osirrox on -indev "$INPUT_ISO" -extract /isolinux/isohdpfx.bin "$WORK_DIR/isohdpfx.bin" 2>/dev/null; then
    MBR_FILE="$WORK_DIR/isohdpfx.bin"
elif [ -f /usr/lib/ISOLINUX/isohdpfx.bin ]; then
    MBR_FILE="/usr/lib/ISOLINUX/isohdpfx.bin"
elif [ -f /usr/lib/syslinux/isohdpfx.bin ]; then
    MBR_FILE="/usr/lib/syslinux/isohdpfx.bin"
fi

# Repack with mkisofs, trying with full boot options first
if [ -n "$MBR_FILE" ]; then
    mkisofs \
        -R -J \
        -V "Fedora-Workstation-Live" \
        -o "$OUTPUT_ISO" \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e images/efiboot.img \
        -no-emul-boot \
        -isohybrid-mbr "$MBR_FILE" \
        "$WORK_DIR/iso_root" 2>/dev/null || \
        mkisofs -R -J -o "$OUTPUT_ISO" "$WORK_DIR/iso_root"
else
    mkisofs -R -J -o "$OUTPUT_ISO" "$WORK_DIR/iso_root"
fi

echo "Done! Modified ISO saved to $OUTPUT_ISO"
