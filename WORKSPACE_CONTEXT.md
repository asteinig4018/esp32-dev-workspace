# ESP32 Workspace Context

Pick up this file at the start of a new session to understand the full environment.
All tooling is set up and ready to use after running the one-time setup scripts below.

---

## Paths

| Role | Path |
|------|------|
| ESP-IDF framework | `~/esp/esp-idf/` |
| Toolchains + Python venv | `~/esp/.espressif/` |
| QEMU binary | `~/esp/qemu/bin/qemu-system-xtensa` |
| OpenOCD binary | `~/esp/openocd/bin/openocd` |
| OpenOCD scripts | `~/esp/openocd/share/openocd/scripts/` |
| Setup + alias scripts | `~/esp/scripts/` |
| Firmware projects root | `~/projects/firmware/` |
| Example project | `~/projects/firmware/hello_world/` |
| Workspace git repo | https://github.com/asteinig4018/esp32-dev-workspace |

---

## Setup State

Run these scripts once if not already done:

```bash
bash ~/esp/scripts/setup-esp-idf.sh        # installs ESP-IDF v5.3.2
bash ~/esp/scripts/setup-qemu.sh           # installs Espressif QEMU
bash ~/esp/scripts/setup-openocd.sh        # installs OpenOCD + udev rules
```

Add aliases to shell (once):

```bash
echo 'source ~/esp/scripts/esp-aliases.sh' >> ~/.bashrc
source ~/.bashrc
```

Verify:

```bash
idf-activate
idf.py --version
qemu-system-xtensa --version
openocd --version
```

---

## Shell Functions (from esp-aliases.sh)

| Command | Action |
|---------|--------|
| `idf-activate` | Source ESP-IDF export.sh, add QEMU + OpenOCD to PATH |
| `idf-build` | `idf.py build` in current project dir |
| `idf-flash` | Flash to `$ESP_PORT` (default `/dev/ttyUSB0`) |
| `idf-monitor` | Open serial monitor on `$ESP_PORT` |
| `idf-flash-monitor` | Flash then open monitor in one step |
| `idf-qemu` | Build (if needed), create merged flash image, run in QEMU |
| `idf-debug-qemu` | QEMU + GDB server; attach GDB to `app_main` breakpoint |
| `idf-debug [IFACE]` | OpenOCD + GDB for hardware JTAG (default: `esp_usb_jtag`) |
| `idf-menuconfig` | Open Kconfig menu |
| `idf-clean` | `idf.py fullclean` |
| `idf-size` | `idf.py size-components` |
| `idf-new NAME [TARGET]` | Scaffold new project under `~/projects/firmware/` |

Environment overrides (set before `idf-activate`):

```bash
export IDF_TARGET=esp32s3     # default: esp32
export ESP_PORT=/dev/ttyACM0  # default: /dev/ttyUSB0
export ESP_BAUD=460800        # default: 921600
```

---

## New Project Workflow

```bash
idf-activate
idf-new my_board_project esp32s3   # scaffolds ~/projects/firmware/my_board_project/
cd ~/projects/firmware/my_board_project
idf-build
idf-qemu                            # test logic without hardware
idf-flash-monitor                   # once hardware is connected
```

Scaffold creates:

```
my_board_project/
├── CMakeLists.txt          # root cmake
├── main/
│   ├── CMakeLists.txt      # component registration
│   └── main.c              # app_main entry point
├── sdkconfig.defaults      # non-committed default kconfig overrides
├── .gitignore              # excludes build/, sdkconfig, etc.
└── README.md
```

---

## Project CMakeLists.txt Template

```cmake
cmake_minimum_required(VERSION 3.16)
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(my_board_project)
```

## main/CMakeLists.txt Template

```cmake
idf_component_register(SRCS "main.c"
                        INCLUDE_DIRS ".")
```

---

## QEMU Usage

```bash
# Run firmware (Ctrl+A then X to quit)
idf-qemu

# GDB debug in QEMU (halts at app_main)
idf-debug-qemu

# Manual QEMU command (ESP32)
qemu-system-xtensa -nographic \
  -machine esp32 \
  -drive file=build/flash_image.bin,if=mtd,format=raw \
  -nic none \
  -serial mon:stdio

# With GDB server (halted, waiting for attach)
qemu-system-xtensa -nographic \
  -machine esp32 \
  -drive file=build/flash_image.bin,if=mtd,format=raw \
  -nic none -serial mon:stdio \
  -gdb tcp::1234 -S
```

## GDB (QEMU)

```bash
xtensa-esp32-elf-gdb build/hello_world.elf \
  -ex "target remote :1234" \
  -ex "break app_main" \
  -ex "continue"
```

## OpenOCD + GDB (Hardware)

```bash
# Start OpenOCD (in one terminal)
openocd -s ~/esp/openocd/share/openocd/scripts \
        -f interface/esp_usb_jtag.cfg \
        -f target/esp32s3.cfg

# Attach GDB (in another terminal)
xtensa-esp32s3-elf-gdb build/my_project.elf \
  -ex "target remote :3333" \
  -ex "monitor reset halt" \
  -ex "break app_main" \
  -ex "continue"
```

OpenOCD interface configs:

| Interface | Config file |
|-----------|-------------|
| ESP32-S3/C3/H2 built-in USB JTAG | `interface/esp_usb_jtag.cfg` |
| FTDI (ESP32 DevKit) | `interface/ftdi/esp32_devkitj_v1.cfg` |
| J-Link | `interface/jlink.cfg` |

---

## QEMU Limitations

**Works:** CPU, FreeRTOS, SPI flash R/W, UART console, timers, watchdog, software crypto, boot sequence.

**Does not work:** WiFi, Bluetooth/BLE, ADC, DAC, I2C/SPI hardware, USB OTG, camera/LCD, real power management.

Use QEMU for: logic testing, boot debug, flash operations, CI pipelines.
Switch to hardware for: connectivity, peripheral I/O, timing-sensitive code, production validation.

---

## Supported Targets

| Chip | IDF_TARGET | GDB binary | QEMU machine |
|------|-----------|------------|-------------|
| ESP32 | `esp32` | `xtensa-esp32-elf-gdb` | `esp32` |
| ESP32-S3 | `esp32s3` | `xtensa-esp32s3-elf-gdb` | `esp32s3` |

---

## USB / Serial Permissions

User must be in `dialout` and `plugdev` groups (done by setup-openocd.sh):

```bash
groups | grep -E "dialout|plugdev"   # verify
ls /dev/ttyUSB*                       # CP210x / CH340
ls /dev/ttyACM*                       # ESP32-S3 built-in USB
```

---

## Reference

- Full docs: `~/esp/scripts/README.md`
- Setup scripts: `~/esp/scripts/`
- Aliases source: `~/esp/scripts/esp-aliases.sh`
- Workspace repo: https://github.com/asteinig4018/esp32-dev-workspace
- ESP-IDF docs: https://docs.espressif.com/projects/esp-idf/
- Espressif QEMU releases: https://github.com/espressif/qemu/releases
- Espressif OpenOCD releases: https://github.com/espressif/openocd-esp32/releases
