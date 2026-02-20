#!/bin/bash
set -e

# Configuration
DTB_NAME="sc8280xp-lenovo-thinkpad-x13s.dtb"
ASSETS_DIR="$(dirname "$0")/../assets"
DTB_PATH="$ASSETS_DIR/$DTB_NAME"

# Kernel arguments to add
KERNEL_ARGS="arm64.nopauth clk_ignore_unused pd_ignore_unused"

usage() {
    echo "Usage: $0 <device_or_mountpoint>"
    echo "Example: $0 /dev/sda"
    echo "Example: $0 /run/media/user/FEDORA-WS-LIVE"
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

TARGET="$1"
MOUNT_POINT=""

# Check if target is a block device or a directory
if [ -b "$TARGET" ]; then
    echo "Target is a block device. Detecting partitions..."
    # Usually partition 2 is EFI on Fedora ISOs written to USB (hybrid ISO)
    # But on a pure stick created with media writer it might be different.
    # Let's try to assume partition 2 for ESP if plain device.
    # Safe check: valid block device?
    
    # Try to find the EFI partition.
    # `lsblk -o NAME,FSTYPE,LABEL` might help but complex in script without dependencies
    # We will assume user passes the device.
    
    # Most Linux ISO hybrids have EFI on partition 2.
    EFI_PART="${TARGET}2"
    if [ ! -b "$EFI_PART" ]; then
        # Maybe it's p2 (nvme)
        EFI_PART="${TARGET}p2"
    fi
     
    if [ ! -b "$EFI_PART" ]; then
         echo "Error: Could not find partition 2 on $TARGET. Is this a standard Fedora USB?"
         exit 1
    fi

    echo "Mounting $EFI_PART..."
    MOUNT_POINT=$(mktemp -d)
    mount "$EFI_PART" "$MOUNT_POINT"
    echo "Mounted at $MOUNT_POINT"
    trap "umount '$MOUNT_POINT' && rmdir '$MOUNT_POINT'" EXIT

elif [ -d "$TARGET" ]; then
    echo "Target is a directory. Assuming mounted EFI partition."
    MOUNT_POINT="$TARGET"
else
    echo "Error: Target $TARGET is not a block device or directory."
    exit 1
fi

# Ensure DTB exists
if [ ! -f "$DTB_PATH" ]; then
    echo "Error: DTB file not found at $DTB_PATH."
    echo "Please run ./scripts/fetch-dtb.sh first."
    exit 1
fi

# 1. Copy DTB to Root of ESP and/or correct location
echo "Copying DTB to $MOUNT_POINT/$DTB_NAME..."
cp "$DTB_PATH" "$MOUNT_POINT/"

# 2. Update Bootloader Config
# Fedora ISO uses GRUB2 in /EFI/BOOT/grub.cfg or /boot/grub2/grub.cfg depending on layout
# Because it's an ISO 9660 hybrid, the writeable ESP might be an overlay or the actual ESP partition.
# We need to look for grub.cfg

GRUB_CFG_LOCATIONS=(
    "$MOUNT_POINT/EFI/BOOT/grub.cfg"
    "$MOUNT_POINT/EFI/fedora/grub.cfg"
    "$MOUNT_POINT/boot/grub/grub.cfg"
    "$MOUNT_POINT/boot/grub2/grub.cfg"
)

FOUND_GRUB=false

for cfg in "${GRUB_CFG_LOCATIONS[@]}"; do
    if [ -f "$cfg" ]; then
        echo "Found grub config at $cfg"
        
        # Check if already patched
        if grep -q "arm64.nopauth" "$cfg"; then
            echo "Config already appears patched. Skipping append."
        else
            echo "Appending kernel arguments..."
            # Simple sed replacement to append to local linux lines
            # CAUTION: This expects 'linux /images/...' or 'linuxefi ...'
            sed -i "s|linux .*|& $KERNEL_ARGS|g" "$cfg"
            sed -i "s|linuxefi .*|& $KERNEL_ARGS|g" "$cfg"
            echo "Patched $cfg"
        fi
        FOUND_GRUB=true
    fi
done

if [ "$FOUND_GRUB" = false ]; then
    echo "Warning: Could not find a grub.cfg to patch. You may need to add arguments manually at boot:"
    echo "$KERNEL_ARGS"
else
    echo "Bootloader config updated."
fi

echo "Done. The DTB is copied and kernel arguments added (if config found)."
echo "You can now boot from this USB on the ThinkPad X13s."
