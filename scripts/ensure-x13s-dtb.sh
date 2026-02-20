#!/bin/bash
set -e

DTB_SOURCE="/usr/lib/firmware/sc8280xp-lenovo-thinkpad-x13s.dtb"
ESP_MOUNT="/boot/efi"
DTB_DEST="$ESP_MOUNT/sc8280xp-lenovo-thinkpad-x13s.dtb"

if [ -f "$DTB_SOURCE" ]; then
    if [ ! -f "$DTB_DEST" ]; then
        echo "Copying X13s DTB to ESP..."
        cp "$DTB_SOURCE" "$DTB_DEST"
    else
        # Check if different?
        if ! cmp -s "$DTB_SOURCE" "$DTB_DEST"; then
             echo "Updating X13s DTB on ESP..."
             cp "$DTB_SOURCE" "$DTB_DEST"
        fi
    fi
fi
