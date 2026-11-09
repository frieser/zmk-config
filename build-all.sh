#!/usr/bin/env bash
# Local build of the firmware matrices, inside the same image CI uses.
#
# Usage: build-all.sh [--clean] [--no-resets] [matrix.yaml ...]
#
#   --clean        remove .west, builds/ and firmwares/ first. Without it the
#                  west workspace and the build trees are reused, so a second run
#                  only recompiles what changed (ninja), like CI does.
#   --no-resets    skip the settings_reset targets, exactly like a PR build
#                  (see ci/build-firmware.sh). Handy to check the PR path locally.
#   matrix.yaml    optional subset, e.g. `build-all.sh totem.yaml`. Without it
#                  every matrix is built (cornix, totem, forager).
#
# After a successful run this script prunes the .uf2 files of the built matrices
# that no longer belong to an artifact (renamed or deleted target). Otherwise an
# old file would sit next to the fresh ones and could be flashed by mistake.
# Nothing is pruned when the build fails, and the pruning never leaves this
# script: CI (ci/build-firmware.sh) is untouched.
#
# The build itself is ci/build-firmware.sh - the very script the Tekton pipeline
# runs - so local and CI behaviour cannot drift. Keep them in sync by keeping
# this file thin: it only adds podman, the ./firmwares output directory and the
# stale-file cleanup.
set -euo pipefail

CLEAN=0
NO_RESETS=0
MATRICES=()
for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    --no-resets) NO_RESETS=1 ;;
    --) ;;
    -h|--help)
      echo "usage: build-all.sh [--clean] [--no-resets] [matrix.yaml ...]"
      exit 0
      ;;
    -*)
      echo "build-all.sh: unknown option $arg" >&2
      exit 2
      ;;
    *) MATRICES+=("$arg") ;;
  esac
done

if [ "$CLEAN" = "1" ]; then
  echo "🧹 Removing .west, builds/ and firmwares/"
  rm -rf .west builds firmwares
fi

# Resolve the default matrix list here (not only in the container) so the stale
# cleanup below knows exactly which matrices this run produced.
if [ ${#MATRICES[@]} -eq 0 ]; then
  MATRICES=(cornix.yaml totem.yaml forager.yaml)
fi

FLAGS=()
if [ "$NO_RESETS" = "1" ]; then
  FLAGS+=(--no-resets)
fi

# -t only when there is a terminal, otherwise `podman run -it` fails in scripts
# and in CI-like environments.
PODMAN_ARGS=(--rm --security-opt label=disable -i)
if [ -t 1 ]; then
  PODMAN_ARGS+=(-t)
fi

echo "🐳 Launching podman container for ZMK build..."
podman run "${PODMAN_ARGS[@]}" \
  --workdir /zmk-config \
  -v "$(pwd)":/zmk-config \
  zmkfirmware/zmk-build-arm:3.5-branch \
  /bin/bash -c 'exec bash ci/build-firmware.sh /zmk-config /zmk-config/firmwares "$@"' \
  zmk-build ${FLAGS[@]+"${FLAGS[@]}"} ${MATRICES[@]+"${MATRICES[@]}"}

# Only reached when podman (and therefore the build) succeeded: set -e aborts
# above on any failure, so a broken build never loses the previous .uf2 files.
prune_stale_firmwares() {
  local matrix keyboard expected file artifact removed=0
  for matrix in "${MATRICES[@]}"; do
    keyboard="$(basename "$matrix" .yaml)"
    [ -d "firmwares/$keyboard" ] || continue
    # The .uf2 file names of this matrix, read from the same file the build read.
    expected="$(grep -E '^[[:space:]]*artifact-name:' "$matrix" 2>/dev/null \
      | sed -E 's/^[[:space:]]*artifact-name:[[:space:]]*//; s/[[:space:]]+$//; s/$/.uf2/')" || true
    for file in "firmwares/$keyboard"/*.uf2; do
      [ -f "$file" ] || continue
      artifact="$(basename "$file")"
      if ! printf '%s\n' "$expected" | grep -qxF -- "$artifact"; then
        echo "🧹 stale: $file (no such artifact in $matrix)"
        rm -f "$file"
        removed=$((removed + 1))
      fi
    done
    # Drop the directory if the matrix lost every artifact.
    rmdir "firmwares/$keyboard" 2>/dev/null || true
  done
  if [ "$removed" -eq 0 ]; then
    echo "🧹 no stale .uf2 files"
  else
    echo "🧹 removed $removed stale .uf2 file(s)"
  fi
}

prune_stale_firmwares

echo '🎉 Firmwares in ./firmwares/<matrix>/'
