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

2. **Method A: Patch the USB Installer (Manual):**
   After writing the Bluefin/Aurora ISO to a USB drive, run this script to inject the DTB and set kernel arguments.
   ```bash
   sudo ./scripts/patch-usb.sh /dev/sdX
   # OR if already mounted
   sudo ./scripts/patch-usb.sh /run/media/user/FEDORA-WS-LIVE
   ```

3. **Method B: Create a Modified ISO (Automated):**
   Use the injection script to create a new ISO that already has the DTB embedded in its root:
   ```bash
   # First download a Bluefin/Aurora ISO
   wget https://example.com/bluefin-lts-installer.iso
   
   # Then inject the DTB (using a container, ideal for immutable OSes)
   ./scripts/run-in-container.sh bluefin-lts-installer.iso bluefin-x13s-installer.iso ./assets/sc8280xp-lenovo-thinkpad-x13s.dtb
   
   # Write the modified ISO to USB
   sudo dd if=bluefin-x13s-installer.iso of=/dev/sdX bs=4M status=progress && sync
   ```


3. **GitHub Actions (CI/CD - Automated):**
   This repository includes a GitHub Action to automatically build a bootable ISO with the X13s DTB injected.
   - Push to `main` or `master` branch, or manually trigger workflow in GitHub
   - Download the `bluefin-x13s-installer` artifact
   - Write to USB: `sudo dd if=bluefin-x13s-installer.iso of=/dev/sdX bs=4M status=progress && sync`

## Installation & First Boot

After booting the modified ISO or installed system on the ThinkPad X13s:

1. **At UEFI/GRUB:**
   The DTB file should be accessible. If kernel arguments aren't automatically applied, add them manually:
   ```
   arm64.nopauth clk_ignore_unused pd_ignore_unused
   ```

2. **After Installation (if not set automatically):**
   ```bash
   sudo rpm-ostree kargs --append="arm64.nopauth clk_ignore_unused pd_ignore_unused"
   sudo reboot
   ```

3. **Verify DTB is loaded:**
   ```bash
   cat /proc/device-tree/model
   dmesg | grep -i "device.tree\|compatible"
   ```

## Troubleshooting
