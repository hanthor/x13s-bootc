FROM ghcr.io/ublue-os/bluefin-lts:latest

# Copy the X13s DTB to the image
# For OSTree/bootc systems, placing the DTB in /usr/lib/modules/$KVER/dtb/qcom/
# ensures that OSTree automatically copies it to /boot/ostree/.../dtb/ during deployment
# and adds an `fdtdir` entry to the Boot Loader Specification (BLS) config.
COPY assets/sc8280xp-lenovo-thinkpad-x13s.dtb /tmp/

RUN KVER=$(ls /usr/lib/modules | head -n 1) && \
    mkdir -p /usr/lib/modules/$KVER/dtb/qcom && \
    cp /tmp/sc8280xp-lenovo-thinkpad-x13s.dtb /usr/lib/modules/$KVER/dtb/qcom/

# Configure kernel arguments for bootc
# bootc will automatically apply these kernel arguments to the bootloader configuration
# during installation and updates.
RUN mkdir -p /usr/lib/bootc/kargs.d && \
    echo 'kargs = ["efi=noruntime", "clk_ignore_unused", "pd_ignore_unused", "arm64.nopauth"]' > /usr/lib/bootc/kargs.d/10-x13s.toml

