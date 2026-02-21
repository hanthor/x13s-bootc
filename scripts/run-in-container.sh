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

IMAGE_NAME="x13s-iso-builder"

# Check if our custom builder image exists, if not, build it
if ! podman image exists "$IMAGE_NAME"; then
    echo "Building ISO builder container image..."
    podman build -t "$IMAGE_NAME" - <<EOF
FROM registry.fedoraproject.org/fedora:latest
RUN dnf install -y xorriso mtools genisoimage && dnf clean all
EOF
fi

echo "Running ISO injection inside the container..."
podman run --rm -it \
    -v "$WORK_DIR:/work:z" \
    -w /work \
    "$IMAGE_NAME" \
    bash -c "./scripts/inject-dtb-iso.sh \"$1\" \"$2\" \"$3\""
