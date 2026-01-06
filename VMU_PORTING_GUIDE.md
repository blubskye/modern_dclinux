# VMU Support in Dreamcast Linux

## Current Status in Linux 4.19.316

### ✅ Already Available (Not Yet Enabled)

#### 1. **VMU Memory Card Driver** (`drivers/mtd/maps/vmu-flash.c`)
- **Status:** Exists in kernel, NOT enabled in our config
- **Functionality:**
  - Block-level read/write to VMU memory (512-byte blocks)
  - Automatic partition detection
  - Read/write caching
  - Exposed as MTD (Memory Technology Device)
- **Author:** Adrian McMenamin, Paul Mundt
- **Lines of Code:** 824 lines
- **Maple Function:** `MAPLE_FUNC_MEMCARD` (0x002)

### ❌ Missing (Can Be Ported from KallistiOS)

#### 2. **VMU LCD Driver** (KallistiOS: `kernel/arch/dreamcast/hardware/maple/vmu.c`)
- **Display:** 48x32 pixels, 1bpp monochrome
- **Use Cases:**
  - Game status displays
  - Player-specific information
  - Debug output
- **Required Driver Type:** Character device (`/dev/vmu0-lcd`, etc.)
- **Maple Function:** `MAPLE_FUNC_LCD` (0x004)
- **KallistiOS APIs:**
  - `vmu_draw_lcd()` - Draw raw 1bpp bitmap
  - `vmu_draw_lcd_rotated()` - Draw rotated bitmap
  - `vmu_draw_lcd_xbm()` - Draw X11 XBM format
  - `vmu_set_icon()` - Broadcast to all VMUs

#### 3. **VMU Clock/RTC Driver** (KallistiOS: same file)
- **Maple Function:** `MAPLE_FUNC_CLOCK` (0x008)
- **Features:**
  - **Date/Time:**
    - Get/set date and time
    - Unix timestamp support
    - Could integrate with Linux RTC subsystem
  - **Buzzer/Beeper:**
    - Square wave tone generation
    - Dual-channel waveform (mono on standard VMUs)
    - Frequency range: ~3.9KHz-500KHz
  - **Button Input:**
    - D-pad (up, down, left, right)
    - A and B buttons
    - Mode and Sleep buttons (not pollable on standard VMU)
    - Could integrate with Linux input subsystem

#### 4. **VMU Settings** (KallistiOS: same file)
- Enable/disable 241-block mode (extra 41 blocks)
- Set custom VMU color (displayed in Dreamcast BIOS)
- Set icon shape (124 BIOS icons available)
- Requires VMUFS access

---

## Porting Recommendations

### Priority 1: Enable Existing VMU Flash Driver

**Difficulty:** Easy ⭐
**Benefit:** High - VMU save file support

Add to `linux.config`:
```makefile
# MTD Support
CONFIG_MTD=y
CONFIG_MTD_BLOCK=y
CONFIG_MTD_CHAR=y

# VMU Flash Driver
CONFIG_MTD_VMU=y
```

This will give you `/dev/mtdblock0`, `/dev/mtdblock1`, etc. for each VMU partition.

**User-space access:**
```bash
# Read VMU block
dd if=/dev/mtdblock0 of=vmu_backup.img bs=512

# Mount VMU filesystem (requires VMUFS driver - see below)
mount -t vfat /dev/mtdblock0 /mnt/vmu
```

---

### Priority 2: Port VMU LCD Driver

**Difficulty:** Medium ⭐⭐
**Benefit:** Medium - Cool visual feedback

**Implementation Plan:**

1. **Create new driver:** `drivers/char/vmu_lcd.c`
2. **Register as character device:** `/dev/vmu0-lcd`, `/dev/vmu1-lcd`, etc.
3. **IOCTLs:**
   ```c
   #define VMU_LCD_DRAW_RAW     _IOW('v', 1, struct vmu_bitmap)
   #define VMU_LCD_DRAW_XBM     _IOW('v', 2, struct vmu_bitmap)
   #define VMU_LCD_CLEAR        _IO('v', 3)
   ```

4. **User-space API:**
   ```c
   int fd = open("/dev/vmu0-lcd", O_WRONLY);
   struct vmu_bitmap bmp = { .width = 48, .height = 32, .data = bitmap_data };
   ioctl(fd, VMU_LCD_DRAW_RAW, &bmp);
   ```

5. **Maple bus integration:**
   - Use `maple_add_packet()` with `MAPLE_COMMAND_SETCOND`
   - Send 1bpp bitmap (192 bytes = 48*32/8)

**KallistiOS Code to Reference:**
- `/home/blubskye/Downloads/KallistiOS/kernel/arch/dreamcast/hardware/maple/vmu.c:vmu_draw_lcd()`
- Lines involving `MAPLE_COMMAND_BLOCK_WRITE` or LCD commands

---

### Priority 3: Port VMU RTC/Clock Driver

**Difficulty:** Medium ⭐⭐
**Benefit:** Medium - Real-time clock support

**Implementation Plan:**

1. **Create RTC driver:** `drivers/rtc/rtc-vmu.c`
2. **Register with RTC subsystem:**
   ```c
   static struct rtc_class_ops vmu_rtc_ops = {
       .read_time = vmu_rtc_read_time,
       .set_time = vmu_rtc_set_time,
   };
   ```

3. **Maple commands:**
   - `MAPLE_COMMAND_GETCOND` - Read date/time
   - `MAPLE_COMMAND_SETCOND` - Write date/time

4. **User-space:**
   ```bash
   hwclock -r -f /dev/rtc1  # Read VMU time
   hwclock -w -f /dev/rtc1  # Write VMU time
   ```

**KallistiOS Code to Reference:**
- `vmu_get_datetime()` - Read time
- `vmu_set_datetime()` - Write time
- Format: `vmu_datetime_t` struct (lines 62-70)

---

### Priority 4: Port VMU Buzzer Driver

**Difficulty:** Easy-Medium ⭐⭐
**Benefit:** Low - Fun but not essential

**Implementation Plan:**

1. **Create PWM/Beeper driver:** `drivers/input/misc/vmu_beep.c`
2. **Register with input subsystem as beeper**
3. **Maple command:** `MAPLE_COMMAND_SETCOND` with waveform data
4. **User-space:**
   ```bash
   echo 1000 > /sys/class/input/input1/beep  # 1KHz tone
   ```

**KallistiOS Code:**
- `vmu_beep_waveform()` - Generate square wave
- Period and duty cycle parameters (lines 422-480)

---

### Priority 5: Port VMU Button Input Driver

**Difficulty:** Medium ⭐⭐⭐
**Benefit:** Low - Niche use case

**Implementation Plan:**

1. **Create input driver:** `drivers/input/misc/vmu_buttons.c`
2. **Register as input device**
3. **Poll using `MAPLE_COMMAND_GETCOND`**
4. **Report as EV_KEY events:**
   - BTN_DPAD_UP, BTN_DPAD_DOWN, BTN_DPAD_LEFT, BTN_DPAD_RIGHT
   - BTN_A, BTN_B

**KallistiOS Code:**
- `vmu_poll_reply()` - Button polling
- `vmu_buttons_t` struct (lines 562-574)

---

## VMUFS Filesystem Driver (Advanced)

KallistiOS includes a VMU filesystem implementation (`kernel/arch/dreamcast/fs/vmufs.c`). This could be ported to Linux as a proper filesystem driver:

**Features:**
- FAT-like filesystem (but VMU-specific format)
- File/directory support
- Icon metadata
- 512-byte blocks

**Porting Difficulty:** Hard ⭐⭐⭐⭐⭐
**Alternative:** Use existing MTD block device + user-space tools

---

## Integration with Existing Kernel Config

To enable VMU memory card support in our current build:

```bash
cd /home/blubskye/Downloads/buildroot-2025.02
make linux-menuconfig BR2_EXTERNAL=/home/blubskye/Downloads/modern_dclinux/dclinux-buildroot

# Navigate to:
# Device Drivers → Memory Technology Device (MTD) support
#   → [*] MTD support
#   → [*] Enable UBI - Unsorted Block Images
#   → Mapping drivers for chip access
#       → [*] Dreamcast Maple bus VMU

# Save and rebuild
make
```

---

## Testing VMU Support

Once enabled:

```bash
# Check for VMU devices
ls -l /dev/mtd*

# Read VMU info
cat /proc/mtd

# Backup VMU
dd if=/dev/mtdblock0 of=/root/vmu_backup.img bs=512

# Check dmesg for VMU detection
dmesg | grep -i vmu
```

---

## Summary

| Feature | Status | Difficulty | Priority |
|---------|--------|------------|----------|
| Memory Card (MTD) | ✅ Exists, needs enabling | ⭐ Easy | 🔥 High |
| LCD Display | ❌ Needs porting | ⭐⭐ Medium | 🔥 Medium |
| RTC/Clock | ❌ Needs porting | ⭐⭐ Medium | 🔥 Medium |
| Buzzer/Beeper | ❌ Needs porting | ⭐⭐ Easy-Medium | 🔥 Low |
| Button Input | ❌ Needs porting | ⭐⭐⭐ Medium | 🔥 Low |
| VMUFS Filesystem | ❌ Needs porting | ⭐⭐⭐⭐⭐ Hard | 🔥 Low |

---

## Next Steps

1. **Enable existing VMU flash driver** (add CONFIG_MTD_VMU=y)
2. **Test memory card functionality** on real hardware or emulator
3. **Port LCD driver** for visual feedback
4. **Port RTC driver** for clock functionality
5. **Consider buzzer/button support** if needed

The KallistiOS code at `/home/blubskye/Downloads/KallistiOS/kernel/arch/dreamcast/hardware/maple/vmu.c` provides excellent reference material for all VMU functions!

---

*Created: 2026-01-05*
*Linux Kernel Version: 4.19.316*
*KallistiOS Reference: Latest*
