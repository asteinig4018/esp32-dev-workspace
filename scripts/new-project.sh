#!/usr/bin/env bash
# =============================================================================
# new-project.sh — Scaffold a new ESP-IDF firmware project
# Usage: bash new-project.sh <project-name> [target=esp32|esp32s3]
# Creates: ~/projects/firmware/<project-name>/
# =============================================================================
set -euo pipefail

PROJECT_NAME="${1:-}"
IDF_TARGET="${2:-esp32}"
FIRMWARE_DIR="$HOME/projects/firmware"
IDF_PATH="$HOME/esp/esp-idf"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: $0 <project-name> [esp32|esp32s3]"
    exit 1
fi

PROJECT_DIR="$FIRMWARE_DIR/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    echo "ERROR: ${PROJECT_DIR} already exists."
    exit 1
fi

echo "==> Creating project: ${PROJECT_NAME} (target: ${IDF_TARGET})"
echo "    Location: ${PROJECT_DIR}"

mkdir -p "$PROJECT_DIR/main"

# ---- CMakeLists.txt (root) --------------------------------------------------
cat > "$PROJECT_DIR/CMakeLists.txt" << EOF
cmake_minimum_required(VERSION 3.16)
include(\$ENV{IDF_PATH}/tools/cmake/project.cmake)
project(${PROJECT_NAME})
EOF

# ---- main/CMakeLists.txt ----------------------------------------------------
cat > "$PROJECT_DIR/main/CMakeLists.txt" << EOF
idf_component_register(SRCS "main.c"
                        INCLUDE_DIRS ".")
EOF

# ---- main/main.c ------------------------------------------------------------
cat > "$PROJECT_DIR/main/main.c" << EOF
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_chip_info.h"
#include "esp_flash.h"

static const char *TAG = "${PROJECT_NAME}";

void app_main(void)
{
    esp_chip_info_t chip_info;
    uint32_t flash_size;

    esp_chip_info(&chip_info);
    esp_flash_get_size(NULL, &flash_size);

    ESP_LOGI(TAG, "Hello from ${PROJECT_NAME}!");
    ESP_LOGI(TAG, "Chip: cores=%d, features=0x%lx", chip_info.cores, chip_info.features);
    ESP_LOGI(TAG, "Flash: %lu MB", flash_size / (1024 * 1024));

    int count = 0;
    for (;;) {
        ESP_LOGI(TAG, "Running... count=%d", count++);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
EOF

# ---- sdkconfig.defaults -----------------------------------------------------
cat > "$PROJECT_DIR/sdkconfig.defaults" << EOF
# Default config for ${PROJECT_NAME}
# Override specific Kconfig values here (no need to commit sdkconfig itself)
CONFIG_IDF_TARGET="${IDF_TARGET}"

# Increase log level for development
CONFIG_LOG_DEFAULT_LEVEL_DEBUG=y

# Disable brownout detector for dev boards with weak USB power
# CONFIG_ESP_BROWNOUT_DET=n

# Optional: use smaller stack for simple apps
# CONFIG_ESP_MAIN_TASK_STACK_SIZE=4096
EOF

# ---- .gitignore -------------------------------------------------------------
cat > "$PROJECT_DIR/.gitignore" << 'EOF'
# ESP-IDF build artifacts
build/
sdkconfig
sdkconfig.old
dependencies.lock
managed_components/
.cache/
EOF

# ---- README -----------------------------------------------------------------
cat > "$PROJECT_DIR/README.md" << EOF
# ${PROJECT_NAME}

ESP-IDF firmware project targeting \`${IDF_TARGET}\`.

## Build

\`\`\`bash
cd ~/projects/firmware/${PROJECT_NAME}
idf-activate
idf-build
\`\`\`

## Flash & Monitor

\`\`\`bash
idf-flash-monitor
\`\`\`

## QEMU

\`\`\`bash
idf-qemu
\`\`\`

## GDB (QEMU)

\`\`\`bash
idf-debug-qemu
\`\`\`

## GDB (Hardware via OpenOCD)

\`\`\`bash
idf-debug
\`\`\`
EOF

# ---- Init git ---------------------------------------------------------------
git -C "$PROJECT_DIR" init -q
git -C "$PROJECT_DIR" add .
git -C "$PROJECT_DIR" commit -q -m "Initial scaffold for ${PROJECT_NAME} (target: ${IDF_TARGET})"

echo ""
echo "==> Project created: ${PROJECT_DIR}"
echo ""
echo "    cd ${PROJECT_DIR}"
echo "    idf-activate"
echo "    idf-build"
