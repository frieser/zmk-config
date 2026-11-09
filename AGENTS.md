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
├── cornix.yaml                # Build matrix per keyboard (50 keys)
├── totem.yaml                 # Build matrix per keyboard (38 keys)
├── forager.yaml               # Build matrix per keyboard (34 keys)
├── build-all.sh               # Local build via Podman (reads the matrices)
├── .tekton/                   # CI entry points for Pipelines-as-Code
│   ├── firmware.yaml          # push main + v* tags -> build + release
│   └── firmware-pr.yaml       # PRs -> build only (no release)
├── ci/
│   ├── tekton/pipeline.yaml   # Tekton Pipeline used by both
│   ├── build-firmware.sh      # Build logic (runs in the ZMK image)
│   └── publish-release.sh     # Uploads .uf2 to a Forgejo release
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
| Add build target | `<keyboard>.yaml` | Same matrix feeds local build, CI and PR check |

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
1.  Edit the matrix of the keyboard you want to test (`cornix.yaml`,
    `totem.yaml`, `forager.yaml`) and comment out the targets you don't need.
2.  Run `bash build-all.sh`.
3.  Once verified, restore the entries before committing.
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
| Change a build target in `<keyboard>.yaml` without checking CI | The same matrix drives the local build and the Forgejo pipeline |
| Edit `ci/build-firmware.sh` without keeping `build-all.sh` in sync | Both encode the same west invocation; drift = local builds pass, CI fails (or the reverse) |
| Git operations without asking | NO commit/push unless user requests |
| Assume build succeeded | WAIT for exit code 0 |

## CI — FORGEJO + TEKTON (PIPELINES-AS-CODE)
- **Repo**: https://forge.homelab.frieserlabs.dev/frieser/zmk-config (private). GitHub is a mirror only.
- **Runs**: https://forge.homelab.frieserlabs.dev/frieser/zmk-config/actions (or `kubectl -n ci-build get pipelinerun`)
- **Trigger**: push to `main` or a `v*` tag builds every matrix and publishes a release; a PR builds only.
- **Releases**: tag `firmware-<shortsha>` (or the pushed `v*` tag) with the `.uf2` files attached.
- **Pipeline**: `.tekton/*.yaml` → `ci/tekton/pipeline.yaml` (one Task, three steps: clone → build → publish).
- **Workspaces**: `source` = emptyDir (clone, pristine build trees, `.uf2`); `cache` = PVC `zmk-west-cache` (20Gi, `ci-build`) holding only the west workspace (`zephyr/`, `zmk/`, modules).
- **Cache**: `CACHE_DIR` in `ci/build-firmware.sh`. `config/` is recopied from the clone every run; build trees stay out of the PVC. A failed `west update` wipes and retries once. Cold build ≈22 min, warm ≈15 min.
- **RWO**: the cache PVC admits one build at a time. A push build and a PR build that overlap queue (second pod Pending) instead of corrupting the workspace. Do not create a second PVC-less pipeline expecting parallelism.
- **Actions are disabled on the Forgejo repo** (`has_actions: false`): the old `.github/workflows/*` fail in 0s there (no runner) and paint the commit red. They stay for the GitHub mirror only.
- **Post-push**: MUST verify the PipelineRun succeeds.
- **On failure**: `kubectl -n ci-build logs pipelinerun/<name> --all-containers` → fix → push → re-verify.

## NOTES
- **Build time**: `build-all.sh` takes 10-15+ minutes
- **Dongle builds**: `*_for_dongle` artifacts pair with `*_dongle` receiver
- **Mouse support**: Enabled via `CONFIG_ZMK_POINTING=y` in `default.conf`
- **ZMK Studio**: Cornix dongle supports live configuration
- **External modules**: `zmk-helpers`, `zmk-dongle-display` via `config/west.yml`
