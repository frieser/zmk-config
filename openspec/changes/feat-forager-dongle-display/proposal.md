# Proposal: Enable Forager Dongle with Display

## Summary
Configure the `forager_dongle` shield to act as a split central (dongle) and support the Nice!View display for status information (battery, connectivity, etc.), leveraging the `zmk-dongle-display` module.

## Motivation
The user wants to use a Forager keyboard with a dongle setup that includes a Nice!View display. While the `forager_dongle` shield exists, it currently has an incorrect display configuration (I2C OLED instead of SPI Nice!View) and may lack necessary dongle configurations found in working examples like `urchin_dongle`.

## Proposed Changes
1.  **Dongle Configuration**: Ensure `forager_dongle` is correctly configured as a central device with appropriate peripheral counts and input settings.
2.  **Display Support**: Replace the existing I2C OLED configuration in `forager_dongle.overlay` with a configuration suitable for Nice!View (SPI Sharp display).
3.  **Module Integration**: Enable and configure the `zmk-dongle-display` module to show relevant status information on the screen.

## Risks & Mitigation
-   **Pinout Mismatch**: The Nice!View pinout might differ if not using a standard Nice!Nano backpack.
    -   *Mitigation*: Use standard Nice!View pin mappings for Nice!Nano and document them for user verification.
-   **Module Compatibility**: Ensure `zmk-dongle-display` is compatible with the current ZMK version.
    -   *Mitigation*: The module is already in `west.yml`, assuming compatibility.
