#!/usr/bin/env bash

set -euo pipefail

# CONFIG
BUILD_DIR="builds"
FIRMWARE_OUT="firmwares"

rm -rf .west

# Ensure required dirs exist before entering container
mkdir -p "$BUILD_DIR" "$FIRMWARE_OUT"

echo "🐳 Launching podman container for ZMK build..."

podman run -it --rm --security-opt label=disable \
  --workdir /zmk-config \
  -v "$(pwd)":/zmk-config \
  zmkfirmware/zmk-build-arm:3.5-branch \
  /bin/bash -c "

set -euo pipefail

# Variables inside container
KEYMAP_CORNIX="/zmk-config/config/cornix.keymap"
KEYMAP_FORAGER="/zmk-config/config/forager.keymap"
KEYMAP_TOTEM="/zmk-config/config/totem.keymap"
ZMK_APP_PATH="zmk/app"
BUILD_DIR=\"builds\"
FIRMWARE_OUT=\"firmwares\"

# Init west workspace
echo '🔧 Initializing west workspace...'
west init -l config
west update
west zephyr-export

# Build all firmware targets
echo '🛠️  Building firmware targets...'

west build -p -s \$ZMK_APP_PATH -b cornix_dongle -d \$BUILD_DIR/cornix_dongle \\
  -- -DSHIELD=\"cornix_dongle_eyelash dongle_display\" -DSNIPPET=\"studio-rpc-usb-uart\" -DKEYMAP_FILE=\$KEYMAP_CORNIX

west build -p -s \$ZMK_APP_PATH -b cornix_left -d \$BUILD_DIR/cornix_left_default \\
  -- -DKEYMAP_FILE=\$KEYMAP_CORNIX

west build -p -s \$ZMK_APP_PATH -b cornix_ph_left -d \$BUILD_DIR/cornix_left_for_dongle \\
  -- -DKEYMAP_FILE=\$KEYMAP_CORNIX

west build -p -s \$ZMK_APP_PATH -b cornix_right -d \$BUILD_DIR/cornix_right \\
  -- -DKEYMAP_FILE=\$KEYMAP_CORNIX

west build -p -s \$ZMK_APP_PATH -b cornix_right -d \$BUILD_DIR/reset \\
  -- -DSHIELD=\"settings_reset\" -DKEYMAP_FILE=\$KEYMAP_CORNIX

west build -p -s \$ZMK_APP_PATH -b seeeduino_xiao_ble -S zmk-usb-logging -d \$BUILD_DIR/seeeduino_xiao_ble_forager_left_rgbled_adapter \\
  -- -DSHIELD=\"forager_left rgbled_adapter\" -DSNIPPET=\"studio-rpc-usb-uart\" -DKEYMAP_FILE=\$KEYMAP_FORAGER

west build -p -s \$ZMK_APP_PATH -b seeeduino_xiao_ble -S zmk-usb-logging -d \$BUILD_DIR/seeeduino_xiao_ble_forager_right_rgbled_adapter \\
  -- -DSHIELD=\"forager_right rgbled_adapter\" -DKEYMAP_FILE=\$KEYMAP_FORAGER

west build -p -s \$ZMK_APP_PATH -b seeeduino_xiao_ble -d \$BUILD_DIR/totem_left \\
  -- -DSHIELD=\"totem_left\" -DKEYMAP_FILE=\$KEYMAP_TOTEM -DBOARD_ROOT=\"/zmk-config/zmk-config-totem/config\" -DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=y

west build -p -s \$ZMK_APP_PATH -b seeeduino_xiao_ble -d \$BUILD_DIR/totem_right \\
  -- -DSHIELD=\"totem_right\" -DKEYMAP_FILE=\$KEYMAP_TOTEM -DBOARD_ROOT=\"/zmk-config/zmk-config-totem/config\" -DCONFIG_ZMK_SPLIT_ROLE_CENTRAL=n

west build -p -s \$ZMK_APP_PATH -b seeeduino_xiao_ble -S zmk-usb-logging -d \$BUILD_DIR/seeeduino_xiao_ble_settings_reset \\
  -- -DSHIELD=\"settings_reset\" -DKEYMAP_FILE=\$KEYMAP_FORAGER

# Collect firmware output
echo '📦 Collecting firmware files...'
mkdir -p \$FIRMWARE_OUT
shopt -s nullglob
for dir in \$BUILD_DIR/*; do
  fw=\"\$dir/zephyr/zmk.uf2\"
  if [[ -f \"\$fw\" ]]; then
    base=\$(basename \"\$dir\")
    cp \"\$fw\" \"\$FIRMWARE_OUT/\$base.uf2\"
    echo \"✅ Copied: \$FIRMWARE_OUT/\$base.uf2\"
  else
    echo \"⚠️  No firmware found in \$dir\"
  fi
done

echo '🎉 All builds completed successfully!'
"
