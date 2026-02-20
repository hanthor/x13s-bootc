FROM ghcr.io/ublue-os/bluefin-lts:latest

# Copy the X13s DTB to the image
# It needs to be in a place where it can be copied to the ESP during install or boot.
# For OSTree systems, /usr/lib/modules/$KVER/dtb/ is standard, but the bootloader needs it in ESP.
# We can use a systemd service or a modprobe config to help, but physically moving it to ESP is key.
# A simple approach: Place it in /usr/share/x13s/ and have a script handling it,
# or try to put it in /boot/dtb (which might not persist/deploy correctly in all setups).

COPY assets/sc8280xp-lenovo-thinkpad-x13s.dtb /usr/lib/firmware/
COPY assets/sc8280xp-lenovo-thinkpad-x13s.dtb /boot/efi/

# Add a script explicitly to copy DTB to ESP on boot if missing
COPY scripts/ensure-x13s-dtb.service /etc/systemd/system/
COPY scripts/ensure-x13s-dtb.sh /usr/bin/

RUN systemctl enable ensure-x13s-dtb.service

# Append kernel args to the internal preset if possible, or leave for `bootc install --karg`
# Modifying /usr/lib/bootupd/updates is complex.
# We rely on user using `bootc install --karg` for the initial install args.
