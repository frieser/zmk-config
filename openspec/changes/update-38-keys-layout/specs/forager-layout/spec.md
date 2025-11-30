## ADDED Requirements

### Requirement: 38-Key Matrix Support
The Forager shield configuration MUST support a 38-key matrix layout, consisting of 19 keys per half.

#### Scenario: Key Availability
- **GIVEN** the Forager firmware is built
- **WHEN** all keys are pressed
- **THEN** the system registers 38 distinct key codes (19 left, 19 right).

### Requirement: Extended Thumb Cluster
The layout MUST support 3 keys in the thumb cluster per half.

#### Scenario: Thumb Keys
- **GIVEN** the 38-key layout
- **THEN** there are 3 defined keys for the left thumb and 3 for the right thumb.

### Requirement: Outer Column Extension
The layout MUST support an additional key on the outer column of the bottom row (or middle row depending on interpretation, strictly "outer" side).

#### Scenario: Layout Macros
- **GIVEN** `config/layouts/38-keys.h`
- **THEN** it provides macros to map the extra outer keys (e.g., `LB5` or similar).
