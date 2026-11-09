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
│   │   ├── common.dtsi        # SHARED include contract, one list for all families
│   │   ├── keymap.dtsi        # SHARED layer assembly (layer order lives here)
│   │   ├── layers/            # One file per layer, per family:
│   │   │   ├── 34-keys/       #   base|symbol|navi|numpad|macro|debug.dtsi
│   │   │   ├── 38-keys/
│   │   │   └── 50-keys/
│   │   ├── 34-keys/base.dtsi  # Forager/Urchin family adapter
│   │   ├── 38-keys/base.dtsi  # Totem family adapter
│   │   ├── 50-keys/base.dtsi  # Cornix family adapter
│   │   ├── layers.dtsi        # Layer index #defines (BASE, SYMBOL, ...)
│   │   ├── behaviours.dtsi    # Custom hold-taps, tap-dances (+ HM_* constants)
│   │   ├── combos.dtsi        # Chord combos
│   │   ├── macros.dtsi        # Macros
│   │   └── mouse.dtsi         # Pointing/mouse config
│   └── layouts/
│       └── XX-keys.h          # Physical→logical key mapping macros
├── cornix.yaml                # Build matrix per keyboard (50 keys)
├── totem.yaml                 # Build matrix per keyboard (38 keys)
├── forager.yaml               # Build matrix per keyboard (34 keys)
├── build-all.sh               # Local build via Podman (wraps ci/build-firmware.sh)
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
| Modify keybindings | `config/includes/layers/<N>-keys/<layer>.dtsi` | One file per layer (base, symbol, navi, numpad, macro, debug) per family |
| Change layer order / add a layer | `config/includes/keymap.dtsi` + `config/includes/layers.dtsi` | Assembly order == layer index |
| Add a shared include | `config/includes/common.dtsi` | One list for all three families |
| Add behavior | `config/includes/behaviours.dtsi` | Home-row mods and HM_* timing constants live here |
| Add combo | `config/includes/combos.dtsi` | |
| Add macro | `config/includes/macros.dtsi` | |
| Keyboard-specific tweaks | `config/includes/XX-keys/base.dtsi` | Layout adapter per key count |
| Enable feature | `config/default.conf` or `config/<keyboard>.conf` | |
| Add build target | `<keyboard>.yaml` | Same matrix feeds local build, CI and PR check |

## BUILD COMMANDS
```bash
# Full build (all keyboards). Incremental: the west workspace and builds/ are reused.
bash build-all.sh

# Only some matrices
bash build-all.sh totem.yaml forager.yaml

# Throw the workspace and the build trees away first (was the old default)
bash build-all.sh --clean

# Single target
west build -p -s zmk/app -b <board> -d builds/<name> -- \
  -DSHIELD="<shields>" -DKEYMAP_FILE=config/<keymap>

# Lint DTS syntax
dtc -I dts -O dtb <file>.dtsi
```

## LOCAL TESTING WORKFLOW
To test firmwares locally without waiting for the full build:
1.  Pass the matrices you want: `bash build-all.sh totem.yaml` (no edit needed).
2.  Repeat as often as you like: the second run only rebuilds what changed,
    unless you add `--clean`.
3.  Run `grep '^TIME' log` to see how long each target took.

## CONVENTIONS

### Architecture Pattern
- **Stub Keymaps**: `*.keymap` files are 3-line includes, NOT full keymaps
- **Layer Slices**: one file per layer and key-count in `config/includes/layers/<N>-keys/<layer>.dtsi`; `config/includes/keymap.dtsi` assembles them in order, and `includes/layers.dtsi` holds only the layer indices (`#define BASE 0` … `DEBUG 5`). The assembly order in `keymap.dtsi` MUST match those indices.
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
| Edit `*.keymap` directly | They're stubs; edit the layer slice in `config/includes/layers/<N>-keys/<layer>.dtsi` (assembled by `config/includes/keymap.dtsi`) |
| Edit zmk/, zephyr/, modules/ | Dependencies; changes will be lost |
| Edit external modules from `config/west.yml` | External dependencies: `zmk`, `zmk-keyboard-cornix`, `zmk-helpers`, `zmk-dongle-display`, `forager-zmk-module`, `zmk-rgbled-widget`. These are cloned by `west update` and MUST NOT be modified. (`zmk-config-totem` was removed: it is not a module - no `zephyr/module.yml` - and its shield is the local `config/boards/shields/totem/`) |
| Change a build target in `<keyboard>.yaml` without checking CI | The same matrix drives the local build and the Forgejo pipeline |
| Duplicate a `settings_reset` target instead of `alias-of` | The image is identical per (board, shield, snippet); a duplicate costs ~20 s of build time and can drift |
| Point `alias-of` at an artifact that no matrix defines | The alias fails (or silently late-builds a foreign target); the source artifact must exist in some matrix |
| Reintroduce a build loop in `build-all.sh` | It must stay a thin podman wrapper around `ci/build-firmware.sh`; two copies of the west invocation = local builds pass while CI fails (or the reverse) |
| Git operations without asking | NO commit/push unless user requests |
| Assume build succeeded | WAIT for exit code 0 |

## CI — FORGEJO + TEKTON (PIPELINES-AS-CODE)
- **Repo**: https://forge.homelab.frieserlabs.dev/frieser/zmk-config (private). GitHub is a mirror only.
- **Runs**: https://forge.homelab.frieserlabs.dev/frieser/zmk-config/actions (or `kubectl -n ci-build get pipelinerun`)
- **Trigger**: push to `main` or a `v*` tag builds every matrix and publishes a release; a PR builds only.
- **Releases**: tag `firmware-<shortsha>` (or the pushed `v*` tag) with the `.uf2` files attached.
- **Pipeline**: `.tekton/*.yaml` → `ci/tekton/pipeline.yaml` (one Task, four steps: clone → select-matrices → build → publish).
- **Workspaces**: `source` = emptyDir (clone, `.uf2`); `cache` = PVC `zmk-west-cache` (20Gi, `ci-build`) holding the west workspace (`zephyr/`, `zmk/`, modules) and the build trees.
- **Cache**: `CACHE_DIR` in `ci/build-firmware.sh`. `config/` is recopied from the clone every run; the west workspace AND the build trees (`$CACHE_DIR/ws/builds`) live in the PVC. Builds are incremental (`-p` only when the workspace was recreated or an artifact's board/shield/snippet/cmake tuple OR the `zmk` core sha changed - tracked by a `.zmk-build-stamp` file per build dir, which contains `board=`, `shield=`, `snippet=`, `cmake=` and `zmk=`). A failed `west update` wipes and retries once. Measured: cold PipelineRun 15m52s (build step 15m08s), warm 11m30s (11m22s); the cached workspace is ~3.7 GiB.
- **Resets**: `settings_reset` images are identical per (board, shield, snippet) and never read the keymap, so only 3 are compiled. The duplicates use `alias-of: <artifact>` in the matrix files (totem/forager reset + dongle resets) and are copied after the real builds. PR runs skip them entirely (`--no-resets`).
- **PR builds are selective**: `.tekton/firmware-pr.yaml` sets `selective=true`, and the `select-matrices` step maps the diff against the target branch to the matrices to build (shared includes, `ci/**`, `config/west.yml`, layouts or a matrix file => all; per-keyboard config/shield files => that keyboard; docs => nothing).
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
- **`alias-of` vs the GitHub mirror**: the `.github/workflows/build-*.yml` files feed the matrices to ZMK's `build-user-config.yml` as a `build.yaml`, which requires `board` on every entry and does not know `alias-of`. Those mirror builds would fail on the reset entries; Forgejo + Tekton is the real CI (Actions are disabled there anyway).
