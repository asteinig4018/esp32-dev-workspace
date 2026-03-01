#!/usr/bin/env bash
# =============================================================================
# esp-aliases.sh — ESP32 development shell functions
# Source this in ~/.bashrc or ~/.zshrc:
#   source ~/esp/scripts/esp-aliases.sh
# =============================================================================

# Core paths — adjust if you moved directories
export ESP_BASE="$HOME/esp"
export IDF_PATH="$ESP_BASE/esp-idf"
export IDF_TOOLS_PATH="$ESP_BASE/.espressif"
export ESP_QEMU_PATH="$ESP_BASE/qemu/bin"
export ESP_OPENOCD_PATH="$ESP_BASE/openocd/bin"
export ESP_OPENOCD_SCRIPTS="$ESP_BASE/openocd/share/openocd/scripts"

# Default serial port (override per-project or per-session)
export ESP_PORT="${ESP_PORT:-/dev/ttyUSB0}"
export ESP_BAUD="${ESP_BAUD:-921600}"

# Default chip (override per-project: export IDF_TARGET=esp32s3)
export IDF_TARGET="${IDF_TARGET:-esp32}"

# -----------------------------------------------------------------------
# idf-activate
#   Enter an IDF-enabled shell (sources export.sh, adds tools to PATH)
# -----------------------------------------------------------------------
idf-activate() {
    if [ -f "$IDF_PATH/export.sh" ]; then
        # Source in current shell
        # shellcheck disable=SC1090
        source "$IDF_PATH/export.sh"
        # Prepend QEMU and OpenOCD to PATH
        export PATH="$ESP_QEMU_PATH:$ESP_OPENOCD_PATH:$PATH"
        echo "==> ESP-IDF activated: $(idf.py --version 2>/dev/null)"
        echo "    IDF_PATH=${IDF_PATH}"
        echo "    IDF_TARGET=${IDF_TARGET}"
    else
        echo "ERROR: ESP-IDF not found at ${IDF_PATH}"
        echo "Run: bash ~/esp/scripts/setup-esp-idf.sh"
        return 1
    fi
}

# -----------------------------------------------------------------------
# idf-build [-- extra args]
#   Build current project. Must be inside a project directory.
# -----------------------------------------------------------------------
idf-build() {
    _idf_check || return 1
    echo "==> Building (target: ${IDF_TARGET})..."
    idf.py build "$@"
}

# -----------------------------------------------------------------------
# idf-flash [PORT] [-- extra args]
#   Flash to device. Defaults to ESP_PORT.
# -----------------------------------------------------------------------
idf-flash() {
    _idf_check || return 1
    local port="${1:-$ESP_PORT}"
    echo "==> Flashing to ${port} at ${ESP_BAUD} baud..."
    idf.py flash -p "$port" -b "$ESP_BAUD" "${@:2}"
}

# -----------------------------------------------------------------------
# idf-monitor [PORT]
#   Open serial monitor. Ctrl+] to quit.
# -----------------------------------------------------------------------
idf-monitor() {
    _idf_check || return 1
    local port="${1:-$ESP_PORT}"
    echo "==> Monitor on ${port} (Ctrl+] to quit)..."
    idf.py monitor -p "$port"
}

# -----------------------------------------------------------------------
# idf-flash-monitor [PORT]
#   Flash then immediately open monitor (most common workflow step)
# -----------------------------------------------------------------------
idf-flash-monitor() {
    _idf_check || return 1
    local port="${1:-$ESP_PORT}"
    idf.py flash monitor -p "$port" -b "$ESP_BAUD"
}

# -----------------------------------------------------------------------
# idf-qemu [-- extra qemu args]
#   Build (if needed) then run in QEMU. No hardware required.
#   Ctrl+A then X to quit QEMU. Ctrl+A then C for QEMU monitor.
# -----------------------------------------------------------------------
idf-qemu() {
    _idf_check || return 1
    local qemu_bin
    qemu_bin=$(command -v qemu-system-xtensa 2>/dev/null || echo "$ESP_QEMU_PATH/qemu-system-xtensa")

    if [ ! -x "$qemu_bin" ]; then
        echo "ERROR: qemu-system-xtensa not found."
        echo "Run: bash ~/esp/scripts/setup-qemu.sh"
        return 1
    fi

    # Build if no build artifacts
    if [ ! -f "build/${PWD##*/}.bin" ] && [ ! -f "build/app-template.bin" ]; then
        echo "==> No build found. Building first..."
        idf.py build || return 1
    fi

    # Create merged flash image
    echo "==> Creating merged flash image..."
    idf.py merge-bin -o build/flash_image.bin || {
        echo "ERROR: merge-bin failed. Ensure project is built."
        return 1
    }

    echo "==> Starting QEMU (${IDF_TARGET})..."
    echo "    Ctrl+A then X to quit | Ctrl+A then C for QEMU monitor"
    echo ""

    case "$IDF_TARGET" in
        esp32)
            "$qemu_bin" -nographic \
                -machine esp32 \
                -drive file=build/flash_image.bin,if=mtd,format=raw \
                -nic none \
                -serial mon:stdio \
                "$@"
            ;;
        esp32s3)
            "$qemu_bin" -nographic \
                -machine esp32s3 \
                -drive file=build/flash_image.bin,if=mtd,format=raw \
                -nic none \
                -serial mon:stdio \
                "$@"
            ;;
        *)
            echo "ERROR: QEMU not configured for IDF_TARGET=${IDF_TARGET}"
            echo "Supported: esp32, esp32s3"
            return 1
            ;;
    esac
}

# -----------------------------------------------------------------------
# idf-debug-qemu [PORT]
#   Run in QEMU with GDB server on tcp:1234, then attach GDB.
#   Opens QEMU in background, then launches GDB in foreground.
# -----------------------------------------------------------------------
idf-debug-qemu() {
    _idf_check || return 1
    local gdb_port="${1:-1234}"
    local qemu_bin
    qemu_bin=$(command -v qemu-system-xtensa 2>/dev/null || echo "$ESP_QEMU_PATH/qemu-system-xtensa")
    local elf
    elf=$(ls build/*.elf 2>/dev/null | head -1)

    if [ -z "$elf" ]; then
        echo "ERROR: No .elf found in build/. Run idf-build first."
        return 1
    fi

    # Find GDB for current target
    local gdb_bin
    case "$IDF_TARGET" in
        esp32)   gdb_bin="xtensa-esp32-elf-gdb" ;;
        esp32s3) gdb_bin="xtensa-esp32s3-elf-gdb" ;;
        *)       gdb_bin="xtensa-esp-elf-gdb" ;;
    esac

    echo "==> Creating merged flash image..."
    idf.py merge-bin -o build/flash_image.bin 2>/dev/null

    echo "==> Starting QEMU with GDB server on tcp::${gdb_port} (halted)..."
    "$qemu_bin" -nographic \
        -machine "${IDF_TARGET/s/_s}" \
        -drive file=build/flash_image.bin,if=mtd,format=raw \
        -nic none \
        -serial file:/dev/stdout \
        -gdb "tcp::${gdb_port}" -S &
    local qemu_pid=$!

    sleep 1
    echo "==> Attaching GDB to QEMU (${elf})..."
    echo "    Commands: continue | next | step | break app_main"
    "$gdb_bin" "$elf" \
        -ex "target remote :${gdb_port}" \
        -ex "monitor info registers" \
        -ex "break app_main" \
        -ex "continue"

    kill "$qemu_pid" 2>/dev/null || true
}

# -----------------------------------------------------------------------
# idf-debug [INTERFACE_CFG]
#   Hardware JTAG debugging via OpenOCD + GDB.
#   INTERFACE_CFG: openocd interface config (default: esp_usb_jtag)
# -----------------------------------------------------------------------
idf-debug() {
    _idf_check || return 1
    local interface="${1:-esp_usb_jtag}"
    local openocd_bin
    openocd_bin=$(command -v openocd 2>/dev/null || echo "$ESP_OPENOCD_PATH/openocd")

    if [ ! -x "$openocd_bin" ]; then
        echo "ERROR: openocd not found."
        echo "Run: bash ~/esp/scripts/setup-openocd.sh"
        return 1
    fi

    local elf
    elf=$(ls build/*.elf 2>/dev/null | head -1)
    if [ -z "$elf" ]; then
        echo "ERROR: No .elf in build/. Run idf-build first."
        return 1
    fi

    local target_cfg
    case "$IDF_TARGET" in
        esp32)   target_cfg="target/esp32.cfg" ;;
        esp32s3) target_cfg="target/esp32s3.cfg" ;;
        *)       echo "ERROR: Unknown target ${IDF_TARGET}"; return 1 ;;
    esac

    local gdb_bin
    case "$IDF_TARGET" in
        esp32)   gdb_bin="xtensa-esp32-elf-gdb" ;;
        esp32s3) gdb_bin="xtensa-esp32s3-elf-gdb" ;;
    esac

    echo "==> Starting OpenOCD (interface: ${interface}, target: ${IDF_TARGET})..."
    "$openocd_bin" \
        -s "$ESP_OPENOCD_SCRIPTS" \
        -f "interface/${interface}.cfg" \
        -f "$target_cfg" &
    local openocd_pid=$!

    sleep 2
    echo "==> Attaching GDB to OpenOCD (${elf})..."
    "$gdb_bin" "$elf" \
        -ex "target remote :3333" \
        -ex "monitor reset halt" \
        -ex "break app_main" \
        -ex "continue"

    kill "$openocd_pid" 2>/dev/null || true
}

# -----------------------------------------------------------------------
# idf-menuconfig
#   Open project configuration menu
# -----------------------------------------------------------------------
idf-menuconfig() {
    _idf_check || return 1
    idf.py menuconfig
}

# -----------------------------------------------------------------------
# idf-clean
#   Remove build artifacts for current project
# -----------------------------------------------------------------------
idf-clean() {
    _idf_check || return 1
    idf.py fullclean
}

# -----------------------------------------------------------------------
# idf-size
#   Show firmware size breakdown
# -----------------------------------------------------------------------
idf-size() {
    _idf_check || return 1
    idf.py size-components
}

# -----------------------------------------------------------------------
# idf-new NAME [TARGET]
#   Scaffold a new firmware project
# -----------------------------------------------------------------------
idf-new() {
    local name="${1:-}"
    local target="${2:-esp32}"
    if [ -z "$name" ]; then
        echo "Usage: idf-new <project-name> [target=esp32|esp32s3]"
        return 1
    fi
    bash ~/esp/scripts/new-project.sh "$name" "$target"
}

# -----------------------------------------------------------------------
# internal: check IDF is activated
# -----------------------------------------------------------------------
_idf_check() {
    if ! command -v idf.py &>/dev/null; then
        echo "ERROR: ESP-IDF not activated. Run: idf-activate"
        return 1
    fi
    if [ ! -f "CMakeLists.txt" ]; then
        echo "ERROR: No CMakeLists.txt found. Are you in a project directory?"
        return 1
    fi
}

# -----------------------------------------------------------------------
# Tab completion hints
# -----------------------------------------------------------------------
if [ -n "${BASH_VERSION:-}" ]; then
    complete -W "esp32 esp32s3" idf-new
fi

echo "ESP32 aliases loaded. Run 'idf-activate' to enable ESP-IDF tools."
echo "Commands: idf-activate | idf-build | idf-flash | idf-monitor |"
echo "          idf-qemu | idf-debug-qemu | idf-debug | idf-new | idf-clean"
