# ESP32 Development Workspace

Professional ESP-IDF development environment with QEMU emulation and OpenOCD debugging.

---

## Directory Layout

```
~/esp/
├── esp-idf/            # ESP-IDF framework (git clone)
├── .espressif/         # Managed: toolchains, Python venv
│   ├── tools/          # Xtensa/RISC-V toolchains
│   └── python_env/     # Python venv per IDF version
├── qemu/               # Espressif QEMU fork (qemu-system-xtensa)
├── openocd/            # Espressif OpenOCD fork
└── scripts/
    ├── setup-esp-idf.sh
    ├── setup-qemu.sh
    ├── setup-openocd.sh
    ├── esp-aliases.sh  # Source this in ~/.bashrc
    └── new-project.sh

~/projects/firmware/    # Your firmware projects
├── hello_world/
└── <your-projects>/
```

---

## One-Time Setup

### 1. Install ESP-IDF

```bash
bash ~/esp/scripts/setup-esp-idf.sh           # uses v5.3.2 by default
bash ~/esp/scripts/setup-esp-idf.sh v5.4.0   # or specify version
```

### 2. Install QEMU

```bash
# Check https://github.com/espressif/qemu/releases for the latest version
# Update QEMU_VERSION in setup-qemu.sh, then:
bash ~/esp/scripts/setup-qemu.sh
```

### 3. Install OpenOCD (hardware debugging)

```bash
# Check https://github.com/espressif/openocd-esp32/releases for the latest version
bash ~/esp/scripts/setup-openocd.sh
```

### 4. Add aliases to your shell

```bash
echo 'source ~/esp/scripts/esp-aliases.sh' >> ~/.bashrc
source ~/.bashrc
```

### 5. Verify installation

```bash
idf-activate
idf.py --version
qemu-system-xtensa --version
openocd --version
```

---

## USB Permissions (for flashing and hardware debug)

The OpenOCD setup script installs udev rules and adds you to the `dialout`
and `plugdev` groups. You must **log out and log back in** for this to take effect.

To verify:
```bash
groups | grep -E "dialout|plugdev"
```

For CP210x / CH340 (USB-UART bridges):
```bash
ls -la /dev/ttyUSB*   # after plugging in device
```

For ESP32 built-in USB JTAG (ESP32-S3, C3, H2):
```bash
ls -la /dev/ttyACM*
```

---

## QEMU: What is and is NOT emulated

### Emulated (works in QEMU)

| Feature | Notes |
|---------|-------|
| Xtensa LX6 CPU (ESP32) | Full instruction set |
| Xtensa LX7 CPU (ESP32-S3) | Full instruction set |
| RAM (DRAM/IRAM) | Configured sizes |
| SPI Flash | Virtual image file |
| UART | Console I/O via stdio |
| FreeRTOS scheduler | Runs normally |
| Timers / watchdogs | Basic emulation |
| Basic GPIO state | Read/write registers |
| Software-only features | Crypto, compression, etc. |

### NOT emulated (hardware only)

| Feature | Workaround |
|---------|-----------|
| WiFi / TCP/IP stack | Use hardware or stub APIs |
| Bluetooth / BLE | Hardware only |
| ADC / DAC | Stub or mock |
| I2C / SPI hardware peripherals | Stub or hardware |
| USB OTG | Hardware only |
| Camera / LCD interfaces | Hardware only |
| Power management | Runs but no real effect |
| Hardware crypto accelerators | Falls back to software |
| Real-time clocking (RTC) | Approximate only |

### Decision guide: QEMU vs Hardware

| Use QEMU when... | Use hardware when... |
|-----------------|---------------------|
| Testing FreeRTOS task logic | Testing WiFi / BLE |
| Testing flash read/write logic | Testing peripherals (I2C, SPI) |
| Debugging boot sequence | Measuring power consumption |
| CI/CD automated testing | Production validation |
| No hardware available | Final integration testing |
| Fast iteration (no flash time) | Real-time timing critical |

---

## USB JTAG Interfaces for OpenOCD

| Interface config | Use case |
|----------------|----------|
| `esp_usb_jtag` | ESP32-S3/C3/H2 built-in USB JTAG |
| `ftdi/esp32_devkitj_v1` | ESP32 DevKit with FTDI chip |
| `jlink` | Segger J-Link adapter |
| `cmsis-dap` | Generic CMSIS-DAP adapter |

---

## Daily Workflow Summary

```bash
# New terminal
idf-activate

# Navigate to project
cd ~/projects/firmware/hello_world

# Build
idf-build

# Flash + monitor (hardware)
idf-flash-monitor

# QEMU (no hardware)
idf-qemu

# GDB on QEMU
idf-debug-qemu

# GDB on hardware (OpenOCD)
idf-debug

# New project
idf-new my_sensor_app esp32s3
```

---

## Toolchain Details

| Target | GDB binary | Toolchain prefix |
|--------|-----------|-----------------|
| ESP32 | `xtensa-esp32-elf-gdb` | `xtensa-esp32-elf-` |
| ESP32-S3 | `xtensa-esp32s3-elf-gdb` | `xtensa-esp32s3-elf-` |
| ESP32-C3 | `riscv32-esp-elf-gdb` | `riscv32-esp-elf-` |

---

## CI Integration Notes

For CI/CD, use QEMU to run firmware tests without hardware:

```bash
#!/usr/bin/env bash
set -e
source ~/esp/scripts/esp-aliases.sh
idf-activate
cd ~/projects/firmware/my_app
idf-build
# Run in QEMU with timeout, pipe output
timeout 30 idf-qemu | grep -q "expected output" && echo "PASS" || echo "FAIL"
```

For Docker CI, use Espressif's official image:
```
FROM espressif/idf:v5.3.2
```
