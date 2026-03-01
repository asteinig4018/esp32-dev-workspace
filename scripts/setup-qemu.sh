#!/usr/bin/env bash
# =============================================================================
# setup-qemu.sh — Install Espressif's QEMU fork for ESP32/ESP32-S3
# Binary lands in ~/esp/qemu/
# Usage: bash setup-qemu.sh [VERSION]
# Check latest at: https://github.com/espressif/qemu/releases
# =============================================================================
set -euo pipefail

QEMU_DIR="$HOME/esp/qemu"
# As of 2025-2026, Espressif QEMU is based on QEMU 8.x
# Set QEMU_VERSION to the release tag you want, e.g. esp-develop-8.2.0-20240122
QEMU_VERSION="${1:-esp-develop-8.2.0-20240122}"
QEMU_ARCHIVE="qemu-v8.2.0-esp_develop_20240122-x86_64-linux-gnu.tar.xz"
QEMU_URL="https://github.com/espressif/qemu/releases/download/${QEMU_VERSION}/${QEMU_ARCHIVE}"

echo "==> Downloading Espressif QEMU ${QEMU_VERSION}..."
echo "    URL: ${QEMU_URL}"
echo ""
echo "    NOTE: Check https://github.com/espressif/qemu/releases for the"
echo "    latest version and update QEMU_VERSION/QEMU_ARCHIVE accordingly."
echo ""

mkdir -p "$QEMU_DIR"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "==> Downloading..."
wget -q --show-progress -O "$TMP/$QEMU_ARCHIVE" "$QEMU_URL"

echo "==> Extracting to ${QEMU_DIR}..."
tar -xf "$TMP/$QEMU_ARCHIVE" -C "$QEMU_DIR" --strip-components=1

# Verify
QEMU_BIN="$QEMU_DIR/bin/qemu-system-xtensa"
if [ ! -x "$QEMU_BIN" ]; then
    echo "ERROR: qemu-system-xtensa not found at ${QEMU_BIN}"
    echo "Check the archive structure and adjust --strip-components."
    exit 1
fi

echo ""
echo "==> QEMU installed: $("$QEMU_BIN" --version | head -1)"
echo "==> Binary: ${QEMU_BIN}"
echo "==> Add to PATH via esp-aliases.sh (already handled if sourced)."
