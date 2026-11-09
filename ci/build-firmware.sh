#!/usr/bin/env bash
# Build every firmware target declared in the per-keyboard matrices.
#
# Runs INSIDE zmkfirmware/zmk-build-arm:3.5-branch (west + arm toolchain +
# python3/PyYAML already there), not inside podman: this is the CI counterpart
# of build-all.sh, which wraps the same logic in a container for local use.
# build-all.sh calls THIS script, so the two cannot drift.
#
# Differences from build-all.sh, on purpose:
#   - no podman (we are already the container);
#   - -DZMK_CONFIG and cmake-args use $WS (the clone) instead of /zmk-config,
#     because the Tekton workspace path is not fixed;
#   - outputs land in $OUT_DIR (a directory of the same workspace the publish
#     step reads) instead of ./firmwares, so nothing is committed back to git.
#
# Usage: build-firmware.sh [--no-resets] <workspace-dir> <out-dir> [matrix.yaml ...]
#
#   --no-resets  skip every settings_reset target (and every alias of one).
#                Reset images do not depend on the keymap, so PR runs skip them.
#   matrix.yaml  optional. Without it every matrix is built (cornix, totem,
#                forager). The CI PR pipeline passes a computed subset.
#
# Matrix entries: an entry with `alias-of: <artifact-name>` and no board/shield
# does not compile anything. Its .uf2 is a byte-identical copy of the named
# artifact, resolved after all real builds finish. That is how the duplicated
# settings_reset images are built once instead of six times.
#
# Timing: every target prints machine-readable `TIME ...` lines (start, end,
# duration) and the run ends with a summary, slowest first. `grep '^TIME'` gives
# the whole timeline.
#
# Env:
#   CACHE_DIR  optional. When set, the west workspace (zephyr + zmk + modules,
#              ~3 GiB) AND the build trees live here and survive between builds;
#              only the small `config/` tree is refreshed from the clone on every
#              run. Without it, `west update` refetches everything (~5 min of
#              every build).
#              Never point two concurrent builds at the same cache directory.
set -euo pipefail

NO_RESETS=0
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --no-resets) NO_RESETS=1 ;;
    --) ;;
    -h|--help)
      echo "usage: build-firmware.sh [--no-resets] <workspace-dir> <out-dir> [matrix.yaml ...]"
      exit 0
      ;;
    -*)
      echo "build-firmware.sh: unknown option $arg" >&2
      exit 2
      ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done

if [ ${#POSITIONAL[@]} -lt 2 ]; then
  echo "usage: build-firmware.sh [--no-resets] <workspace-dir> <out-dir> [matrix.yaml ...]" >&2
  exit 2
fi

SRC="$(cd "${POSITIONAL[0]}" && pwd)"
mkdir -p "${POSITIONAL[1]}"
OUT_DIR="$(cd "${POSITIONAL[1]}" && pwd)"
MATRICES=("${POSITIONAL[@]:2}")
if [ ${#MATRICES[@]} -eq 0 ]; then
  MATRICES=(cornix.yaml totem.yaml forager.yaml)
fi

if [ -n "${CACHE_DIR:-}" ]; then
  mkdir -p "$CACHE_DIR"
  CACHE_DIR="$(cd "$CACHE_DIR" && pwd)"
  WS="$CACHE_DIR/ws"
  mkdir -p "$WS"
  # config/ carries the keymaps: always re-copied, never cached.
  rm -rf "$WS/config"
  cp -a "$SRC/config" "$WS/config"
  # Build trees are big and only pay off when they survive: they live in the
  # cache too, so ninja reuses objects between runs (no `-p`, see below).
  BUILDS_DIR="$WS/builds"
  echo "== cached west workspace: $WS ($(du -sh "$WS" 2>/dev/null | cut -f1))"
else
  WS="$SRC"
  BUILDS_DIR="$SRC/builds"
fi
mkdir -p "$OUT_DIR" "$BUILDS_DIR"
echo "== build trees: $BUILDS_DIR"

FORCE_PRISTINE=0

west_update() {
  # --filter=tree:0: fetch no trees/blobs on update. The checkout that follows
  # materialises the trees it needs, and most of the west update time is spent
  # downloading history the build never reads.
  if [ ! -d "$WS/.west" ]; then
    ( cd "$WS" && west init -l config )
  fi
  ( cd "$WS" && west update --fetch-opt=--filter=tree:0 )
}

echo "== west init/update in $WS"
if ! west_update; then
  if [ "$WS" = "$SRC" ]; then
    # Without CACHE_DIR the workspace IS the source checkout (local build via
    # build-all.sh). Wiping it would delete the repo, so fail loudly instead.
    echo "!! west update failed in the source checkout ($WS); not wiping it" >&2
    exit 1
  fi
  # A cached workspace can rot (interrupted checkout, rewritten upstream ref,
  # half-fetched module). One wipe-and-retry is cheaper than failing the build,
  # and the cold path is exactly what a first run does anyway.
  echo "!! west update failed; rebuilding the west workspace from scratch"
  cd /
  rm -rf "$WS"
  mkdir -p "$WS"
  cp -a "$SRC/config" "$WS/config"
  mkdir -p "$BUILDS_DIR"
  FORCE_PRISTINE=1
  west_update
fi
( cd "$WS" && west zephyr-export )

echo "== matrices: ${MATRICES[*]} (no-resets=$NO_RESETS)"
python3 - "$WS" "$OUT_DIR" "$BUILDS_DIR" "$SRC" "$FORCE_PRISTINE" "$NO_RESETS" "${MATRICES[@]}" <<'PYTHON'
import datetime
import os
import shlex
import shutil
import subprocess
import sys
import time

import yaml

ws, out_dir, builds_dir, src = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
force_pristine = sys.argv[5] == "1"
no_resets = sys.argv[6] == "1"
matrices = sys.argv[7:]

DEFAULT_MATRICES = ["cornix.yaml", "totem.yaml", "forager.yaml"]
STAMP_NAME = ".zmk-build-stamp"


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def keyboard_of(matrix):
    return os.path.splitext(os.path.basename(matrix))[0]


def matrix_path(matrix):
    return matrix if os.path.isabs(matrix) else os.path.join(src, matrix)


def load_matrix(matrix):
    path = matrix_path(matrix)
    if not os.path.exists(path):
        return None
    with open(path) as fh:
        return yaml.safe_load(fh) or {}


def cmake_args_for(spec):
    """The `--` arguments of `west build`, identical to build-all.sh's history."""
    cmake = []
    shield = spec.get("shield") or ""
    if shield:
        cmake.append(f"-DSHIELD={shield}")
    # settings_reset is board-only: it must not pull the keyboard config in.
    if "settings_reset" not in shield:
        cmake.append(f"-DZMK_CONFIG={os.path.join(ws, 'config')}")
    for arg in shlex.split(spec.get("cmake-args") or ""):
        if arg.startswith("-D"):
            cmake.append(arg.replace("../../", src + "/"))
    return cmake


def west_cmd(spec, build_dir, pristine):
    cmd = ["west", "build", "-s", "zmk/app"]
    if pristine:
        cmd.append("-p")
    cmd.extend(["-b", spec["board"], "-d", build_dir])
    for snippet in (spec.get("snippet") or "").split():
        cmd.extend(["-S", snippet])
    cmake = cmake_args_for(spec)
    if cmake:
        cmd.append("--")
        cmd.extend(cmake)
    return cmd


def stamp_for(spec, zmk_rev):
    """Identity of a build. Any change here forces a pristine (-p) rebuild."""
    return "\n".join([
        f"board={spec['board']}",
        f"shield={spec.get('shield') or ''}",
        f"snippet={spec.get('snippet') or ''}",
        f"cmake={' '.join(cmake_args_for(spec))}",
        f"zmk={zmk_rev}",
        "",
    ])


def git_rev(path):
    try:
        return subprocess.check_output(
            ["git", "-C", path, "rev-parse", "HEAD"],
            stderr=subprocess.DEVNULL, text=True).strip()
    except Exception:
        return "unknown"


def is_reset(spec):
    return "settings_reset" in (spec.get("shield") or "")


zmk_rev = git_rev(os.path.join(ws, "zmk"))

# Every artifact of the repo (not only the selected matrices), so an alias can
# still be resolved - and late-built - when its source matrix was not selected.
all_specs = {}
for name in DEFAULT_MATRICES + matrices:
    config = load_matrix(name)
    if config is None:
        continue
    for entry in config.get("include", []) or []:
        artifact = entry.get("artifact-name")
        if artifact:
            all_specs[artifact] = (keyboard_of(name), entry)


def real_spec(artifact, seen=()):
    """Follow `alias-of` chains down to a spec that carries a board."""
    if artifact in seen or artifact not in all_specs:
        return None
    spec = all_specs[artifact][1]
    if "alias-of" in spec:
        return real_spec(spec["alias-of"], seen + (artifact,))
    return spec


real_jobs = []
alias_jobs = []
for matrix in matrices:
    config = load_matrix(matrix)
    if config is None:
        print(f"skip {matrix}: not found")
        continue
    keyboard = keyboard_of(matrix)
    for entry in config.get("include", []) or []:
        artifact = entry.get("artifact-name")
        if not artifact:
            print(f"skip entry in {matrix}: no artifact-name")
            continue
        if "alias-of" in entry:
            alias_jobs.append((keyboard, artifact, entry["alias-of"]))
        else:
            real_jobs.append((keyboard, artifact, entry))

timings = []   # (artifact, seconds, status)
failed = []
built = {}     # artifact -> path of the .uf2 inside out_dir
run_start = time.time()


def skip(artifact, reason):
    print(f"TIME skip {artifact} {reason}", flush=True)
    timings.append((artifact, 0.0, "skipped"))


def build_one(artifact, spec, label="", note=""):
    """Compile spec into builds/<artifact>. Returns the build-tree .uf2 or None."""
    build_dir = os.path.join(builds_dir, artifact)
    stamp_path = os.path.join(build_dir, STAMP_NAME)
    want = stamp_for(spec, zmk_rev)
    pristine = force_pristine
    if not pristine:
        try:
            with open(stamp_path) as fh:
                pristine = fh.read() != want
        except OSError:
            pristine = True
    cmd = west_cmd(spec, build_dir, pristine)
    mode = "pristine" if pristine else "incremental"
    print(f"\n--- {label}: {artifact} (board={spec['board']} "
          f"shield={spec.get('shield') or '-'} {mode}){note}", flush=True)
    print(f"TIME start {artifact} {int(time.time())} {now_iso()}", flush=True)
    started = time.time()
    rc = subprocess.run(cmd, cwd=ws).returncode
    elapsed = time.time() - started
    print(f"TIME end {artifact} {int(time.time())} {now_iso()}", flush=True)
    uf2 = os.path.join(build_dir, "zephyr", "zmk.uf2")
    if rc != 0 or not os.path.exists(uf2):
        print(f"TIME duration {artifact} {elapsed:.2f} fail", flush=True)
        print(f"FAIL {artifact} (rc={rc}, uf2={'yes' if os.path.exists(uf2) else 'no'})",
              flush=True)
        failed.append(artifact)
        timings.append((artifact, elapsed, "fail"))
        return None
    # Written only after a good build: a failed build must not look up to date.
    with open(stamp_path, "w") as fh:
        fh.write(want)
    print(f"TIME duration {artifact} {elapsed:.2f} ok", flush=True)
    timings.append((artifact, elapsed, "ok"))
    return uf2


for keyboard, artifact, spec in real_jobs:
    if no_resets and is_reset(spec):
        skip(artifact, "reset (--no-resets)")
        continue
    dest = os.path.join(out_dir, keyboard)
    os.makedirs(dest, exist_ok=True)
    uf2 = build_one(artifact, spec, label=keyboard)
    if uf2 is None:
        continue
    dst = os.path.join(dest, f"{artifact}.uf2")
    shutil.copy2(uf2, dst)
    built[artifact] = dst
    print(f"OK   {artifact}.uf2", flush=True)

for keyboard, artifact, target in alias_jobs:
    spec = real_spec(target)
    if spec is None:
        print(f"TIME duration {artifact} 0.00 fail", flush=True)
        print(f"FAIL {artifact}: alias-of {target} is not defined in any matrix",
              flush=True)
        failed.append(f"{artifact} (alias-of {target})")
        timings.append((artifact, 0.0, "fail"))
        continue
    if no_resets and is_reset(spec):
        skip(artifact, f"reset (--no-resets, alias of {target})")
        continue
    dest = os.path.join(out_dir, keyboard)
    os.makedirs(dest, exist_ok=True)
    dst = os.path.join(dest, f"{artifact}.uf2")
    started = time.time()
    if target in built:
        shutil.copy2(built[target], dst)
        note = ""
    else:
        # The source matrix was not selected (e.g. `build-all.sh totem.yaml`):
        # build it once, silently into this artifact's slot.
        print(f"--- alias {artifact} -> {target}: source not built this run, "
              f"building it", flush=True)
        uf2 = build_one(target, spec, label=keyboard, note=f" (alias source of {artifact})")
        if uf2 is None:
            timings.append((artifact, time.time() - started, "fail"))
            failed.append(f"{artifact} (alias source {target})")
            continue
        shutil.copy2(uf2, dst)
        note = " (built as alias source)"
    built[target] = dst
    elapsed = time.time() - started
    print(f"TIME duration {artifact} {elapsed:.2f} alias", flush=True)
    timings.append((artifact, elapsed, "alias"))
    print(f"OK   {artifact}.uf2{note}", flush=True)

print("\n== timing summary (slowest first)")
for artifact, elapsed, status in sorted(timings, key=lambda t: (-t[1], t[0])):
    print(f"TIME summary {artifact} {elapsed:.2f} {status}", flush=True)
print(f"TIME total {time.time() - run_start:.2f}", flush=True)

print("\n== collected")
for keyboard in sorted(os.listdir(out_dir)):
    directory = os.path.join(out_dir, keyboard)
    if not os.path.isdir(directory):
        continue
    for name in sorted(os.listdir(directory)):
        print(f"  {keyboard}/{name} ({os.path.getsize(os.path.join(directory, name))} bytes)")

if failed:
    print("\nFAILED targets: " + ", ".join(failed))
    sys.exit(1)
PYTHON

echo "== build-firmware.sh done"
