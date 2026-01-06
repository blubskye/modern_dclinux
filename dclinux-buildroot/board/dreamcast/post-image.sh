#!/bin/bash
set -e

BOARD_DIR="$(dirname $0)"
OUTPUT_DIR="${BINARIES_DIR}"

echo "===== Dreamcast CD Image Creation ====="

# IP.BIN is required but not included due to copyright
# User must obtain it separately
IPBIN="${BOARD_DIR}/IP.BIN"
if [ ! -f "${IPBIN}" ]; then
    echo "WARNING: IP.BIN not found at ${IPBIN}"
    echo "IP.BIN is required for bootable Dreamcast CDs but not included due to copyright."
    echo "Please obtain IP.BIN and place it in board/dreamcast/"
    echo "Skipping CD image creation..."
    exit 0
fi

# RedBoot bootloader (1ST_READ.BIN)
REDBOOT="${BOARD_DIR}/1ST_READ.BIN"
if [ ! -f "${REDBOOT}" ]; then
    echo "ERROR: 1ST_READ.BIN (RedBoot) not found at ${REDBOOT}"
    exit 1
fi

# Create ISO staging directory
ISO_DIR="${OUTPUT_DIR}/iso"
rm -rf "${ISO_DIR}"
mkdir -p "${ISO_DIR}/boot"

echo "Copying files to ISO staging directory..."

# Copy RedBoot bootloader
cp "${REDBOOT}" "${ISO_DIR}/1ST_READ.BIN"

# Copy kernel
if [ -f "${OUTPUT_DIR}/vmlinux" ]; then
    cp "${OUTPUT_DIR}/vmlinux" "${ISO_DIR}/boot/vmlinux"
else
    echo "ERROR: vmlinux not found in ${OUTPUT_DIR}"
    exit 1
fi

# Copy root filesystem
if [ -f "${OUTPUT_DIR}/rootfs.ext2" ]; then
    cp "${OUTPUT_DIR}/rootfs.ext2" "${ISO_DIR}/rootfs.ext2"
else
    echo "ERROR: rootfs.ext2 not found in ${OUTPUT_DIR}"
    exit 1
fi

# Create ISO image using mkisofs (or genisoimage)
MKISOFS="mkisofs"
if ! command -v ${MKISOFS} &> /dev/null; then
    MKISOFS="genisoimage"
    if ! command -v ${MKISOFS} &> /dev/null; then
        echo "ERROR: Neither mkisofs nor genisoimage found. Please install cdrtools or genisoimage."
        exit 1
    fi
fi

echo "Creating Dreamcast-compatible CD ISO image..."

# Create multi-session CD image for Dreamcast
# -l : Allow full 31 character filenames
# -r : Rock Ridge extensions
# -m : Exclude patterns (we exclude source directories)
# -C 0,11700 : Multi-session offset for GD-ROM compatibility
# -G : Prepend IP.BIN bootloader
${MKISOFS} -v -l -r \
    -m '*-sources*' \
    -C 0,11700 \
    -G "${IPBIN}" \
    -o "${OUTPUT_DIR}/dclinux.iso" \
    "${ISO_DIR}"

echo ""
echo "===== CD Image Created Successfully ====="
echo "ISO Image: ${OUTPUT_DIR}/dclinux.iso"
echo ""
echo "To burn to CD-R (requires wodim or cdrecord):"
echo "  # Create audio session (dummy data)"
echo "  dd if=/dev/zero bs=2352 count=300 | \\"
echo "    wodim dev=/dev/sr0 -speed=4 -v -multi -audio -dao tsize=705600 -"
echo ""
echo "  # Burn data session with Dreamcast CD"
echo "  wodim dev=/dev/sr0 -tao -overburn -xa -eject ${OUTPUT_DIR}/dclinux.iso"
echo ""
echo "Note: Adjust /dev/sr0 to match your CD burner device."
echo "Note: Burn speed should be 4x minimum for Dreamcast compatibility."
