# Dreamcast Linux Buildroot External Tree

Modern build system for Dreamcast Linux using Buildroot 2025.02 LTS.

## Project Structure

```
dclinux-buildroot/
├── README.md                    # This file
├── external.desc                # BR2_EXTERNAL description
├── external.mk                  # External makefile
├── Config.in                    # External Kconfig
├── configs/
│   └── dreamcast_defconfig      # Dreamcast Buildroot configuration
├── board/dreamcast/
│   ├── 1ST_READ.BIN             # RedBoot bootloader (preserved from original)
│   ├── linux.config             # Kernel configuration for SH4/Dreamcast
│   ├── post-build.sh            # Post-build customization script
│   ├── post-image.sh            # CD image creation script
│   └── overlay/                 # Root filesystem overlay
│       └── etc/
│           ├── fstab            # Filesystem mount table (with NFS)
│           └── init.d/          # SysV init scripts (from original)
├── package/                     # Custom packages (future: prboom, mame, etc.)
└── patches/
    ├── dreamcast/               # Original 2001 build patches (reference)
    ├── chrony.patch             # Chrony NTP patches
    ├── socat.patch              # Socat patches
    ├── netcat.patch             # Netcat patches
    ├── micro_inetd.patch        # Micro inetd patches
    ├── fbcat.c                  # Framebuffer screenshot utility
    ├── tuxclear.c               # SuperH Tux logo utility
    └── ntpclient.c              # Minimal NTP client
```

## Quick Start

### Prerequisites

- Linux build host (tested on Fedora 43)
- Build dependencies:
  ```bash
  sudo dnf install git gcc g++ make patch perl python3 \
                   ncurses-devel which wget cpio unzip \
                   rsync bc bzip2 file
  ```
- CD burning tools (optional, for creating bootable CDs):
  ```bash
  sudo dnf install wodim genisoimage
  ```

### Building

1. **Navigate to Buildroot directory**:
   ```bash
   cd /home/blubskye/Downloads/buildroot-2025.02
   ```

2. **Load the Dreamcast configuration**:
   ```bash
   make BR2_EXTERNAL=/home/blubskye/Downloads/dclinux-buildroot dreamcast_defconfig
   ```

3. **Optional: Customize configuration**:
   ```bash
   make menuconfig
   ```

4. **Build the system** (this will take 1-3 hours on first build):
   ```bash
   make
   ```

5. **Find output** in `output/images/`:
   - `vmlinux` - Kernel for Dreamcast
   - `rootfs.ext2` - Root filesystem
   - `dclinux.iso` - Bootable CD image (if IP.BIN is provided)

### Creating Bootable CD

The system requires **IP.BIN** (Sega bootloader) to create a bootable CD. This file is not included due to copyright restrictions.

Once you have IP.BIN:

1. **Place IP.BIN** in `board/dreamcast/`:
   ```bash
   cp /path/to/IP.BIN /home/blubskye/Downloads/dclinux-buildroot/board/dreamcast/
   ```

2. **Rebuild to generate CD image**:
   ```bash
   make
   ```

3. **Burn to CD-R**:
   ```bash
   # Create audio session (dummy data)
   dd if=/dev/zero bs=2352 count=300 | \
     wodim dev=/dev/sr0 -speed=4 -v -multi -audio -dao tsize=705600 -

   # Burn data session with Dreamcast CD
   wodim dev=/dev/sr0 -tao -overburn -xa -eject output/images/dclinux.iso
   ```

   **Note**: Adjust `/dev/sr0` to match your CD burner device. Burn at 4x speed minimum.

## Current Status

### ✅ Phase 1: Complete (Buildroot Infrastructure)
- Buildroot 2025.02 LTS cloned
- BR2_EXTERNAL tree structure created
- Initial defconfig for SH4/Dreamcast created
- Kernel configuration (4.19 LTS) with Dreamcast-specific drivers
- CD image creation scripts
- Init scripts and fstab migrated from original system

### 🔄 Phase 2: Next Steps (Basic Boot & Drivers)
- Test build and verify kernel compiles
- Test boot on real Dreamcast hardware
- Debug driver issues (GD-ROM, Maple bus, network)
- Fine-tune kernel configuration

## Configuration Details

### Target Architecture
- **CPU**: SuperH SH4 (SH7091)
- **Platform**: Sega Dreamcast
- **RAM**: 16MB
- **Kernel**: Linux 4.19 LTS (conservative starting point)
- **C Library**: glibc
- **Init System**: SysVinit (compatibility with original)

### Key Features
- **No initramfs**: Boot directly from CD-ROM ext2 filesystem (RAM constraint)
- **Full GNU tools**: bash, coreutils, util-linux (NO BusyBox)
- **Networking**: DHCP, Dropbear SSH, NFS client, Chrony NTP
- **Drivers**: RTL8139 (Broadband Adapter), Maple bus, PowerVR2 FB, GD-ROM
- **Size optimization**: -Os, LTO, stripped binaries

### Important Drivers

| Component | Driver | Config Option |
|-----------|--------|---------------|
| CPU | SuperH SH-4 | CONFIG_CPU_SUBTYPE_SH7091 |
| Platform | Dreamcast | CONFIG_SH_DREAMCAST |
| Keyboard/Mouse | Maple bus | CONFIG_MAPLE, CONFIG_KEYBOARD_MAPLE, CONFIG_MOUSE_MAPLE |
| Network | RTL8139 | CONFIG_8139TOO |
| Graphics | PowerVR2 | CONFIG_FB_PVR2 |
| CD-ROM | GD-ROM | CONFIG_GDROM |
| Serial | SH SCI | CONFIG_SERIAL_SH_SCI |
| Sound | AICA | CONFIG_SND_AICA |

## Known Limitations

1. **IP.BIN not included**: Copyrighted Sega bootloader must be obtained separately
2. **16MB RAM constraint**: Cannot use large initramfs, requires NFS swap for X11/development
3. **RedBoot bootloader**: Binary-only, cannot be updated (sources lost)
4. **SH4 architecture**: Declining support in newer kernels, may require driver porting

## Troubleshooting

### Build fails with "kernel headers mismatch"
- Ensure `BR2_KERNEL_HEADERS_4_19=y` matches kernel version in defconfig

### Build fails with missing dependencies
- Install Buildroot build dependencies (see Prerequisites above)

### CD image not created
- Verify IP.BIN is present in `board/dreamcast/`
- Check `output/images/` for vmlinux and rootfs.ext2

### Dreamcast won't boot
- Verify CD is bootable (multi-session with audio track)
- Check serial console output (115200 bps on ttySC1)
- Ensure IP.BIN is correct for your region (USA/Europe/Japan)

## Resources

- **Buildroot Manual**: https://buildroot.org/downloads/manual/manual.html
- **Original Dreamcast Linux**: https://linuxdc.sourceforge.net/
- **Kernel SH4 Support**: https://www.kernel.org/
- **Implementation Plan**: `/home/blubskye/.claude/plans/optimized-cooking-turtle.md`

## License

This external tree configuration is provided as-is for educational and preservation purposes. Individual components retain their original licenses:
- Buildroot: GPLv2+
- Linux Kernel: GPLv2
- Original patches: Various (see individual files)

## Contact

For questions about this modernization project, refer to the implementation plan in `/home/blubskye/.claude/plans/optimized-cooking-turtle.md`.
