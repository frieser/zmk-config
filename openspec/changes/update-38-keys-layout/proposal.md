# Change: Update Forager to 38-key Layout

## Why
The user wants to expand the Forager keyboard configuration from the default 34-keys to a 38-key layout. This enables the use of additional keys in the thumb cluster and an extra outer column key, maximizing the available inputs.

## What Changes
- Update `config/layouts/38-keys.h` to correctly map a 38-key matrix (3x5 + 3 thumbs + 1 extra outer key per side).
- Update `config/boards/shields/forager_dongle/forager.dtsi` to expand the matrix transform and physical layout to support 38 keys.
- Update `config/forager.keymap` to use the new 38-key layout.

## Impact
- **Shields**: `forager_dongle` will now expose 38 keys.
- **Keymaps**: `forager.keymap` will be refactored to populate the new keys.
- **Layouts**: `38-keys.h` will be a distinct layout, not a clone of 34-keys.
