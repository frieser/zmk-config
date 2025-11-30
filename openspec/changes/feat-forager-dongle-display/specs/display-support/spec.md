# Spec: Display Support

## ADDED Requirements

### Requirement: Nice!View Hardware Support
The `forager_dongle` firmware MUST support the Nice!View (Sharp LS0XX) display hardware via SPI.

#### Scenario: Display Initialization
Given the `forager_dongle` hardware with a Nice!View
When firmware boots
Then the display should initialize successfully using the correct SPI pins (CS, MOSI, CLK).

### Requirement: Dongle Status Display
The display MUST show dongle-specific status information including battery levels of peripherals and connection state.

#### Scenario: Visual Feedback
Given the `zmk-dongle-display` module enabled
When the dongle is running
Then the screen should render the configured widgets (e.g., battery icon, layer, connection status).

## MODIFIED Requirements

### Requirement: Remove OLED Support
The previous support for I2C OLED (SH1106) MUST be replaced by Nice!View support to match the user's hardware.

#### Scenario: Overlay Update
Given `forager_dongle.overlay`
Then the `sh1106` node should be removed or disabled in favor of the Nice!View configuration.
