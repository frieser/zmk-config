# Task List

## 1. Implementation
- [ ] 1.1 Update `config/layouts/38-keys.h` <!-- id: layout-header -->
    - Define macros for `LB5`, `RB5` (extra outer keys) and `LH2`, `RH2` (extra thumbs).
    - Update `LAYER_FROM38` macro to accept 38 arguments.
- [ ] 1.2 Update `config/boards/shields/forager_dongle/forager.dtsi` <!-- id: shield-transform -->
    - Expand `key_physical_attrs` to 38 keys.
    - Update `default_transform` to map 38 keys (likely 6 cols x 4 rows or similar expansion).
- [ ] 1.3 Update `config/forager.keymap` <!-- id: keymap-update -->
    - Include `38-keys.h`.
    - Refactor keymap to use `LAYER_FROM38`.
    - Add bindings for the new keys based on the example (or placeholders).
