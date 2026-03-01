#!/usr/bin/env bash
# =============================================================================
# setup-esp-idf.sh — Install ESP-IDF into ~/esp/esp-idf
# Toolchains/venv land in ~/esp/.espressif (IDF_TOOLS_PATH)
# Usage: bash setup-esp-idf.sh [VERSION]
#   VERSION: git tag or branch, e.g. v5.3.2  (default: latest stable v5.3.x)
# =============================================================================
set -euo pipefail

IDF_VERSION="${1:-v5.3.2}"
IDF_PATH="$HOME/esp/esp-idf"
IDF_TOOLS_PATH="$HOME/esp/.espressif"

echo "==> ESP-IDF setup: version=${IDF_VERSION} path=${IDF_PATH}"

# ---------- system dependencies ----------------------------------------------
echo "==> Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    git wget curl flex bison gperf python3 python3-pip python3-venv \
    cmake ninja-build ccache libffi-dev libssl-dev dfu-util \
    libusb-1.0-0 udev \
    2>&1 | grep -v "^Get\|^Fetch\|^Hit"

# ---------- clone ESP-IDF ----------------------------------------------------
if [ -d "$IDF_PATH/.git" ]; then
    echo "==> ESP-IDF already cloned. Fetching ${IDF_VERSION}..."
    git -C "$IDF_PATH" fetch --tags --depth=1 origin
    git -C "$IDF_PATH" checkout "$IDF_VERSION"
    git -C "$IDF_PATH" submodule update --init --recursive --depth=1
else
    echo "==> Cloning ESP-IDF ${IDF_VERSION}..."
    git clone --branch "$IDF_VERSION" --depth=1 --recursive \
        https://github.com/espressif/esp-idf.git "$IDF_PATH"
fi

# ---------- install toolchains -----------------------------------------------
echo "==> Installing ESP-IDF toolchains (IDF_TOOLS_PATH=${IDF_TOOLS_PATH})..."
export IDF_TOOLS_PATH
# Install tools for ESP32 and ESP32-S3
"$IDF_PATH/install.sh" esp32,esp32s3

echo ""
echo "==> ESP-IDF ${IDF_VERSION} installed successfully."
echo "==> Add to ~/.bashrc: source ~/esp/scripts/esp-aliases.sh"
echo "==> Then run: idf-activate  to enter an IDF-enabled shell"
