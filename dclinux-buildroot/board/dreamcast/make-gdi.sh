#!/bin/bash
# Create a Dreamcast GDI image for emulator use
set -e

BOARD_DIR="$(dirname $0)"
OUTPUT_DIR="${1:-output}"

echo "===== Dreamcast GDI Image Creation ====="

# Check for required files
IPBIN="${BOARD_DIR}/IP.BIN"
REDBOOT="${BOARD_DIR}/1ST_READ.BIN"

if [ ! -f "${IPBIN}" ]; then
    echo "ERROR: IP.BIN not found at ${IPBIN}"
    exit 1
fi

if [ ! -f "${REDBOOT}" ]; then
    echo "ERROR: 1ST_READ.BIN not found at ${REDBOOT}"
    exit 1
fi

# Find the kernel and rootfs
if [ -f "${OUTPUT_DIR}/vmlinux" ]; then
    KERNEL="${OUTPUT_DIR}/vmlinux"
elif [ -f "${OUTPUT_DIR}/images/vmlinux" ]; then
    KERNEL="${OUTPUT_DIR}/images/vmlinux"
else
    echo "ERROR: vmlinux not found"
    exit 1
fi

if [ -f "${OUTPUT_DIR}/rootfs.ext2" ]; then
    ROOTFS="${OUTPUT_DIR}/rootfs.ext2"
elif [ -f "${OUTPUT_DIR}/images/rootfs.ext2" ]; then
    ROOTFS="${OUTPUT_DIR}/images/rootfs.ext2"
else
    echo "ERROR: rootfs.ext2 not found"
    exit 1
fi

# Create GDI working directory
GDI_DIR="${OUTPUT_DIR}/gdi"
rm -rf "${GDI_DIR}"
mkdir -p "${GDI_DIR}"

echo "Building data track..."

# Create the data track (track03.bin)
# This will contain: IP.BIN + 1ST_READ.BIN + kernel + rootfs
TRACK_DATA="${GDI_DIR}/track03.bin"

# Start with IP.BIN (32KB, padded if needed)
dd if="${IPBIN}" of="${TRACK_DATA}" bs=32768 count=1 conv=sync 2>/dev/null

# Add 1ST_READ.BIN
cat "${REDBOOT}" >> "${TRACK_DATA}"

# Calculate padding needed to align to 2048-byte sectors
CURRENT_SIZE=$(stat -c%s "${TRACK_DATA}")
SECTOR_SIZE=2048
PADDING=$((SECTOR_SIZE - (CURRENT_SIZE % SECTOR_SIZE)))
if [ $PADDING -ne $SECTOR_SIZE ]; then
    dd if=/dev/zero bs=1 count=$PADDING >> "${TRACK_DATA}" 2>/dev/null
fi

# Create a data directory for the ISO9660 filesystem
DATA_DIR="${GDI_DIR}/data"
mkdir -p "${DATA_DIR}/boot"

# Copy kernel and rootfs
cp "${KERNEL}" "${DATA_DIR}/boot/vmlinux"
cp "${ROOTFS}" "${DATA_DIR}/rootfs.ext2"

# Create ISO9660 filesystem for the data portion
MKISOFS="mkisofs"
if ! command -v ${MKISOFS} &> /dev/null; then
    MKISOFS="genisoimage"
fi

ISO_PART="${GDI_DIR}/data.iso"
${MKISOFS} -quiet -l -J -r -o "${ISO_PART}" "${DATA_DIR}"

# Append the ISO data
cat "${ISO_PART}" >> "${TRACK_DATA}"

# Create dummy audio tracks
echo "Creating dummy audio tracks..."
TRACK01="${GDI_DIR}/track01.bin"
TRACK02="${GDI_DIR}/track02.raw"

# Track 01: 300 sectors of silence (2 seconds)
dd if=/dev/zero of="${TRACK01}" bs=2352 count=300 2>/dev/null

# Track 02: 150 sectors of silence (pregap)
dd if=/dev/zero of="${TRACK02}" bs=2352 count=150 2>/dev/null

# Get sizes
TRACK01_SIZE=$(stat -c%s "${TRACK01}")
TRACK02_SIZE=$(stat -c%s "${TRACK02}")
TRACK03_SIZE=$(stat -c%s "${TRACK_DATA}")

# Calculate sector counts
TRACK01_SECTORS=$((TRACK01_SIZE / 2352))
TRACK02_SECTORS=$((TRACK02_SIZE / 2352))
TRACK03_SECTORS=$((TRACK03_SIZE / 2048))

# GDI format:
# LBA 0: Track 1 starts (audio)
# LBA 300: Track 2 starts (audio pregap)
# LBA 45000: Track 3 starts (data - high density area)

echo "Creating GDI descriptor..."
cat > "${GDI_DIR}/disc.gdi" << EOF
3
1 0 4 2352 track01.bin 0
2 300 4 2352 track02.raw 0
3 45000 4 2048 track03.bin 0
EOF

echo ""
echo "===== GDI Image Created Successfully ====="
echo "GDI Directory: ${GDI_DIR}/"
echo ""
echo "Files created:"
echo "  disc.gdi     - GDI descriptor"
echo "  track01.bin  - Audio track (dummy)"
echo "  track02.raw  - Audio pregap (dummy)"
echo "  track03.bin  - Data track (IP.BIN + bootloader + filesystem)"
echo ""
echo "To convert to CHD:"
echo "  cd ${GDI_DIR}"
echo "  wine /home/blubskye/Downloads/chdman/chdman.exe createcd -i disc.gdi -o dclinux.chd"
echo ""
echo "To use in emulator:"
echo "  Load disc.gdi directly in Redream, Flycast, etc."
echo ""
