#!/bin/bash
set -e

# Configuration
DTB_URL="https://d-i.debian.org/daily-images/arm64/daily/device-tree/qcom/sc8280xp-lenovo-thinkpad-x13s.dtb"
OUTPUT_DIR="$(dirname "$0")/../assets"
OUTPUT_FILE="$OUTPUT_DIR/sc8280xp-lenovo-thinkpad-x13s.dtb"

mkdir -p "$OUTPUT_DIR"

echo "Fetching X13s DTB from Debian..."
echo "URL: $DTB_URL"

if command -v wget >/dev/null 2>&1; then
    wget -O "$OUTPUT_FILE" "$DTB_URL"
elif command -v curl >/dev/null 2>&1; then
    curl -L -o "$OUTPUT_FILE" "$DTB_URL"
else
    echo "Error: Neither wget nor curl found."
    exit 1
fi

if [ -f "$OUTPUT_FILE" ]; then
    echo "Successfully downloaded DTB to $OUTPUT_FILE"
    ls -lh "$OUTPUT_FILE"
else
    echo "Failed to download DTB."
    exit 1
fi
