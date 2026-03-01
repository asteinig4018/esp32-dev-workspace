#!/usr/bin/env bash
# =============================================================================
# setup-openocd.sh — Install Espressif's OpenOCD fork for ESP32/ESP32-S3
# Binary lands in ~/esp/openocd/
# Check latest at: https://github.com/espressif/openocd-esp32/releases
# =============================================================================
set -euo pipefail

OPENOCD_DIR="$HOME/esp/openocd"
# Example release tag: v0.12.0-esp32-20240318
OPENOCD_VERSION="${1:-v0.12.0-esp32-20240318}"
OPENOCD_ARCHIVE="openocd-esp32-linux-amd64-${OPENOCD_VERSION}.tar.gz"
OPENOCD_URL="https://github.com/espressif/openocd-esp32/releases/download/${OPENOCD_VERSION}/${OPENOCD_ARCHIVE}"

echo "==> Installing Espressif OpenOCD ${OPENOCD_VERSION}..."
echo "    URL: ${OPENOCD_URL}"
echo ""
echo "    NOTE: Check https://github.com/espressif/openocd-esp32/releases"
echo "    for the latest version."
echo ""

mkdir -p "$OPENOCD_DIR"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "==> Downloading..."
wget -q --show-progress -O "$TMP/$OPENOCD_ARCHIVE" "$OPENOCD_URL"

echo "==> Extracting to ${OPENOCD_DIR}..."
tar -xf "$TMP/$OPENOCD_ARCHIVE" -C "$OPENOCD_DIR" --strip-components=1

OPENOCD_BIN="$OPENOCD_DIR/bin/openocd"
if [ ! -x "$OPENOCD_BIN" ]; then
    echo "ERROR: openocd not found at ${OPENOCD_BIN}"
    exit 1
fi

echo ""
echo "==> OpenOCD installed: $("$OPENOCD_BIN" --version 2>&1 | head -1)"

# ---------- udev rules for JTAG/USB ----------------------------------------
echo ""
echo "==> Installing udev rules for USB JTAG access..."
RULES_FILE="$OPENOCD_DIR/share/openocd/contrib/60-openocd.rules"
if [ -f "$RULES_FILE" ]; then
    sudo cp "$RULES_FILE" /etc/udev/rules.d/60-openocd.rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    echo "    udev rules installed. You may need to re-plug the device."
else
    echo "    WARNING: Rules file not found at ${RULES_FILE}"
    echo "    Install manually from the openocd-esp32 package."
fi

# ---------- add user to dialout/plugdev -------------------------------------
echo ""
echo "==> Adding $USER to dialout and plugdev groups..."
sudo usermod -aG dialout "$USER"
sudo usermod -aG plugdev "$USER"

echo ""
echo "==> OpenOCD setup complete."
echo "==> Log out and back in (or run: newgrp dialout) for group changes."
echo "==> Binary: ${OPENOCD_BIN}"
