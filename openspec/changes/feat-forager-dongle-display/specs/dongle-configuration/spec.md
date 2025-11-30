# Spec: Dongle Configuration

## ADDED Requirements

### Requirement: Central Role Configuration
The `forager_dongle` MUST be configured as a BLE central to connect to peripheral halves.

#### Scenario: Connecting to peripherals
Given the forager dongle firmware
When powered on
Then it should advertise as a central and accept connections from split peripherals (left/right).

### Requirement: Input Handling
The dongle MUST NOT scan its own matrix but rely on incoming events from peripherals.

#### Scenario: No local matrix
Given the `forager_dongle.overlay`
Then `zmk,kscan` should be assigned to a mock kscan driver (e.g., `zmk,kscan-mock`) to prevent local pin scanning.
