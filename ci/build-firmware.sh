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
set -euo pipefail

WS="$(cd "${1:?workspace dir required}" && pwd)"
OUT_DIR="${2:?out dir required}"
shift 2
MATRICES=("$@")
if [ ${#MATRICES[@]} -eq 0 ]; then
  MATRICES=(cornix.yaml totem.yaml forager.yaml)
fi

cd "$WS"
mkdir -p "$OUT_DIR"

echo "== west init/update in $WS"
rm -rf .west
west init -l config
west update
west zephyr-export

echo "== matrices: ${MATRICES[*]}"
python3 - "$WS" "$OUT_DIR" "${MATRICES[@]}" <<'PYTHON'
import os
import shlex
import shutil
import subprocess
import sys

import yaml

ws, out_dir = sys.argv[1], sys.argv[2]
matrices = sys.argv[3:]

failed = []
for matrix in matrices:
    keyboard = os.path.splitext(os.path.basename(matrix))[0]
    path = os.path.join(ws, matrix)
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

        cmd = ["west", "build", "-s", "zmk/app", "-p", "-b", board,
               "-d", os.path.join("builds", artifact)]
        for s in snippet.split():
            cmd.extend(["-S", s])

        cmake = []
        if shield:
            cmake.append(f"-DSHIELD={shield}")
        if "settings_reset" not in shield:
            cmake.append(f"-DZMK_CONFIG={os.path.join(ws, 'config')}")
        for arg in shlex.split(target.get("cmake-args", "") or ""):
            if arg.startswith("-D"):
                cmake.append(arg.replace("../../", ws + "/"))
        if cmake:
            cmd.append("--")
            cmd.extend(cmake)

        print(f"\n--- {keyboard}: {artifact} (board={board} shield={shield or '-'})", flush=True)
        rc = subprocess.run(cmd, cwd=ws).returncode
        uf2 = os.path.join(ws, "builds", artifact, "zephyr", "zmk.uf2")
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
