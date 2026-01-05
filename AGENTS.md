<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# ZMK Multi-Keyboard Config

**Generated:** 2026-01-05 | **Commit:** 8cc58e5 | **Branch:** totem_dongle

## OVERVIEW
Multi-keyboard ZMK firmware config using **Key-Count-Based Architecture**. Supports Totem (38-keys), Cornix (50-keys), Forager (34-keys), Urchin (34-keys). Dongle-centric design with shared logical layers.

## STRUCTURE
```
./
├── config/                    # YOUR CODE LIVES HERE
│   ├── *.keymap               # Entry points (stub files, include base.dtsi)
│   ├── *.conf                 # Kconfig per keyboard
│   ├── includes/
│   │   ├── 34-keys/base.dtsi  # Forager/Urchin layout adapter
│   │   ├── 38-keys/base.dtsi  # Totem layout adapter
│   │   ├── 50-keys/base.dtsi  # Cornix layout adapter
│   │   ├── layers.dtsi        # SHARED layer definitions (edit this!)
│   │   ├── behaviours.dtsi    # Custom hold-taps, tap-dances
│   │   ├── combos.dtsi        # Chord combos
│   │   ├── macros.dtsi        # Macros
│   │   └── mouse.dtsi         # Pointing/mouse config
│   └── layouts/
│       └── XX-keys.h          # Physical→logical key mapping macros
├── build.yaml                 # Build matrix (CI + local)
├── build-all.sh               # Local build via Podman
└── zmk/, zephyr/, modules/    # Dependencies (DON'T EDIT)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Modify keybindings | `config/includes/layers.dtsi` | Shared across all keyboards |
| Add behavior | `config/includes/behaviours.dtsi` | Home-row mods defined here |
| Add combo | `config/includes/combos.dtsi` | |
| Add macro | `config/includes/macros.dtsi` | |
| Keyboard-specific tweaks | `config/includes/XX-keys/base.dtsi` | Layout adapter per key count |
| Enable feature | `config/default.conf` or `config/<keyboard>.conf` | |
| Add build target | `build.yaml` AND `build-all.sh` | MUST sync both |

## BUILD COMMANDS
```bash
# Full build (all keyboards) - TAKES 10-15 MINUTES
bash build-all.sh

# Single target
west build -p -s zmk/app -b <board> -d builds/<name> -- \
  -DSHIELD="<shields>" -DKEYMAP_FILE=config/<keymap>

# Lint DTS syntax
dtc -I dts -O dtb <file>.dtsi
```

## LOCAL TESTING WORKFLOW
To test firmwares locally without waiting for the full build:
1.  Edit `build.yaml` to comment out all keyboards except the one you want to test.
2.  Run `bash build-all.sh`.
3.  Once verified, comment out that keyboard, uncomment the next one, and run `bash build-all.sh` again.
4.  Repeat until all necessary keyboards have been tested.

## CONVENTIONS

### Architecture Pattern
- **Stub Keymaps**: `*.keymap` files are 3-line includes, NOT full keymaps
- **Base Logic**: All layers in `includes/layers.dtsi`, shared by all keyboards
- **Layout Macros**: `LAYER_FROMXX()` maps logical keys to physical matrix

### Code Style
- **Naming**: snake_case for behaviors/macros/layers; UPPER_CASE for defines
- **Indentation**: 4 spaces; align bindings in columns
- **Key Codes**: Use `< >` angle brackets for key codes
- **Includes**: Relative paths; order: behaviors → layers → combos → macros

### Behaviors
- **Home-row mods**: Use positional hold-taps (`hm_l`, `hm_r`, `hm_shift_l`, `hm_shift_r`)
- **Tap-dance**: `td1`-`td0` = numbers on tap, F-keys on double-tap

## ANTI-PATTERNS

| Forbidden | Reason |
|-----------|--------|
| Edit `*.keymap` directly | They're stubs; edit `includes/layers.dtsi` |
| Edit zmk/, zephyr/, modules/ | Dependencies; changes will be lost |
| Edit external modules from `config/west.yml` | External dependencies: `zmk`, `zmk-keyboard-cornix`, `zmk-helpers`, `zmk-dongle-display`, `forager-zmk-module`, `zmk-rgbled-widget`, `zmk-config-totem`. These are cloned by `west update` and MUST NOT be modified |
| Change `build.yaml` without `build-all.sh` | MUST stay in sync |
| Git operations without asking | NO commit/push unless user requests |
| Assume build succeeded | WAIT for exit code 0 |

## GITHUB ACTIONS
- **URL**: https://github.com/frieser/zmk-config/actions
- **Post-push**: MUST verify workflow succeeds (green check)
- **On failure**: Analyze logs → fix → commit → push → re-verify

## NOTES
- **Build time**: `build-all.sh` takes 10-15+ minutes
- **Dongle builds**: `*_for_dongle` artifacts pair with `*_dongle` receiver
- **Mouse support**: Enabled via `CONFIG_ZMK_POINTING=y` in `default.conf`
- **ZMK Studio**: Cornix dongle supports live configuration
- **External modules**: `zmk-helpers`, `zmk-dongle-display` via `config/west.yml`
