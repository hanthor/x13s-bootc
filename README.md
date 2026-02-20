# ThinkPad X13s BootC Utilities

This repository contains tools to make Bluefin, Bluefin LTS, and Aurora (Fedora Silverblue based images) bootable on the Lenovo ThinkPad X13s.

## Prerequisites

- A Linux environment
- `wget` or `curl`
- `sudo` access (for mounting/modifying USB drives)

## Usage

1. **Download the DTB:**
   Run the fetch script to get the compatible Device Tree Blob from Debian.
   ```bash
   ./scripts/fetch-dtb.sh
   ```

2. **Patch the USB Installer:**
   After writing the Bluefin/Aurora ISO to a USB drive, run this script to inject the DTB and set kernel arguments.
   ```bash
   sudo ./scripts/patch-usb.sh /dev/sdX
   # OR if already mounted
   sudo ./scripts/patch-usb.sh /run/media/user/FEDORA-WS-LIVE
   ```

3. **Build Custom Bootc Image (Optional):**
   If you want to create a custom Bluefin image that includes the DTB (for future `bootc` updates), you can build the provided Containerfile.
   ```bash
   podman build -t localhost/bluefin-x13s:latest .
   ```
   Then you can rebase your system to this image:
   ```bash
   bootc switch localhost/bluefin-x13s:latest
   ```
4. **GitHub Actions (CI/CD):**
   This repository includes a GitHub Action to automatically build a bootable ISO with the X13s DTB injected.
   - Fork this repo.
   - Trigger the "Build X13s Bootc ISO" workflow.
   - Download the `bluefin-x13s-installer` artifact.
   - Flash to USB and boot (you may still need to add kernel args manually on the very first boot if not using `mkksiso`).

## Troubleshooting
