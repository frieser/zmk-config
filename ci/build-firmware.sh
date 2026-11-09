#!/usr/bin/env bash
# Build every firmware target declared in the per-keyboard matrices.
#
# Runs INSIDE zmkfirmware/zmk-build-arm:3.5-branch (west + arm toolchain +
# python3/PyYAML already there), not inside podman: this is the CI counterpart
# of build-all.sh, which wraps the same logic in a container for local use.
#
# Differences from build-all.sh, on purpose:
#   - no podman (we are already the container);
#   - -DZMK_CONFIG and cmake-args use $WS (the clone) instead of /zmk-config,
#     because the Tekton workspace path is not fixed;
#   - outputs land in $OUT_DIR (a directory of the same workspace the publish
#     step reads) instead of ./firmwares, so nothing is committed back to git.
#
# Usage: build-firmware.sh <workspace-dir> <out-dir> [matrix.yaml ...]
#
# Env:
#   CACHE_DIR  optional. When set, the west workspace (zephyr + zmk + modules,
#              ~3 GiB) lives here and survives between builds; only the small
#              `config/` tree is refreshed from the clone on every run. Without
#              it, `west update` refetches everything (~5 min of every build).
#              Never point two concurrent builds at the same cache directory.
set -euo pipefail

SRC="$(cd "${1:?workspace dir required}" && pwd)"
OUT_DIR="${2:?out dir required}"
shift 2
MATRICES=("$@")
if [ ${#MATRICES[@]} -eq 0 ]; then
  MATRICES=(cornix.yaml totem.yaml forager.yaml)
fi

# Build trees are big (18 targets) and useless across runs because every build
# is pristine (`-p`), so they stay next to the clone and never in the cache PVC.
BUILDS_DIR="$SRC/builds"
mkdir -p "$OUT_DIR" "$BUILDS_DIR"

if [ -n "${CACHE_DIR:-}" ]; then
  WS="$CACHE_DIR/ws"
  mkdir -p "$WS"
  # config/ carries the keymaps: always re-copied, never cached.
  rm -rf "$WS/config"
  cp -a "$SRC/config" "$WS/config"
  echo "== cached west workspace: $WS ($(du -sh "$WS" 2>/dev/null | cut -f1))"
else
  WS="$SRC"
fi

west_update() {
  if [ ! -d "$WS/.west" ]; then
    ( cd "$WS" && west init -l config )
  fi
  ( cd "$WS" && west update )
}

echo "== west init/update in $WS"
if ! west_update; then
  # A cached workspace can rot (interrupted checkout, rewritten upstream ref,
  # half-fetched module). One wipe-and-retry is cheaper than failing the build,
  # and the cold path is exactly what a first run does anyway.
  echo "!! west update failed; rebuilding the west workspace from scratch"
  cd /
  rm -rf "$WS"
  mkdir -p "$WS"
  cp -a "$SRC/config" "$WS/config"
  west_update
fi
( cd "$WS" && west zephyr-export )

echo "== matrices: ${MATRICES[*]}"
python3 - "$WS" "$OUT_DIR" "$BUILDS_DIR" "$SRC" "${MATRICES[@]}" <<'PYTHON'
import os
import shlex
import shutil
import subprocess
import sys

import yaml

ws, out_dir, builds_dir, src = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
matrices = sys.argv[5:]

failed = []
for matrix in matrices:
    keyboard = os.path.splitext(os.path.basename(matrix))[0]
    # The matrices come from the clone, not from the cached west workspace.
    path = os.path.join(src, matrix)
    if not os.path.exists(path):
        print(f"skip {matrix}: not found")
        continue
    with open(path) as fh:
        config = yaml.safe_load(fh) or {}

    dest = os.path.join(out_dir, keyboard)
    os.makedirs(dest, exist_ok=True)

    for target in config.get("include", []):
        board = target["board"]
        artifact = target["artifact-name"]
        shield = target.get("shield", "")
        snippet = target.get("snippet", "")

        build_dir = os.path.join(builds_dir, artifact)
        cmd = ["west", "build", "-s", "zmk/app", "-p", "-b", board,
               "-d", build_dir]
        for s in snippet.split():
            cmd.extend(["-S", s])

        cmake = []
        if shield:
            cmake.append(f"-DSHIELD={shield}")
        if "settings_reset" not in shield:
            cmake.append(f"-DZMK_CONFIG={os.path.join(ws, 'config')}")
        for arg in shlex.split(target.get("cmake-args", "") or ""):
            if arg.startswith("-D"):
                cmake.append(arg.replace("../../", src + "/"))
        if cmake:
            cmd.append("--")
            cmd.extend(cmake)

        print(f"\n--- {keyboard}: {artifact} (board={board} shield={shield or '-'})", flush=True)
        rc = subprocess.run(cmd, cwd=ws).returncode
        uf2 = os.path.join(build_dir, "zephyr", "zmk.uf2")
        if rc != 0 or not os.path.exists(uf2):
            failed.append(artifact)
            print(f"FAIL {artifact} (rc={rc}, uf2={'yes' if os.path.exists(uf2) else 'no'})", flush=True)
            continue
        shutil.copy2(uf2, os.path.join(dest, f"{artifact}.uf2"))
        print(f"OK   {artifact}.uf2", flush=True)

print("\n== collected")
for keyboard in sorted(os.listdir(out_dir)):
    for name in sorted(os.listdir(os.path.join(out_dir, keyboard))):
        size = os.path.getsize(os.path.join(out_dir, keyboard, name))
        print(f"  {keyboard}/{name} ({size} bytes)")

if failed:
    print("\nFAILED targets: " + ", ".join(failed))
    sys.exit(1)
PYTHON

echo "== build-firmware.sh done"
