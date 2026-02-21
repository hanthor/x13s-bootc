#!/bin/bash
set -e

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input_iso> <output_iso> <dtb_file>"
    exit 1
fi

INPUT_ISO=$(realpath "$1")
OUTPUT_ISO=$(realpath "$2")
DTB_FILE=$(realpath "$3")
WORK_DIR=$(pwd)

echo "Running ISO injection inside a Fedora container..."
podman run --rm -it \
    -v "$WORK_DIR:/work:z" \
    -w /work \
    registry.fedoraproject.org/fedora:latest \
    bash -c "dnf install -y xorriso mtools genisoimage && ./scripts/inject-dtb-iso.sh \"$1\" \"$2\" \"$3\""
