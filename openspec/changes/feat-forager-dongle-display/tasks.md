# Task List

-   [ ] **Review and Update Dongle Config** <!-- id: config-check -->
    -   Verify `forager_dongle.conf` matches requirements for a central dongle (role, peripherals).
    -   Ensure `zmk-dongle-display` related configs are enabled.
-   [ ] **Update Forager Dongle Overlay** <!-- id: overlay-update -->
    -   Remove `sh1106` (I2C OLED) definition from `forager_dongle.overlay`.
    -   Add `nice_view` (SPI Sharp display) definition or include `nice_view` shield compatibility.
    -   Define correct pins for Nice!View on Nice!Nano (CS, MOSI, CLK).
-   [ ] **Configure Display Widget** <!-- id: widget-config -->
    -   Add `CONFIG_ZMK_DONGLE_DISPLAY=y` to `forager_dongle.conf`.
    -   Configure display options (battery, output status) as per user request.
-   [ ] **Validate Build** <!-- id: build-verify -->
    -   Run a build command for `forager_dongle` to ensure DTS and Kconfig are valid.
