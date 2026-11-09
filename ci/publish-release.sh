#!/bin/sh
# Publish the .uf2 files produced by build-firmware.sh as a Forgejo release.
#
#   publish-release.sh <out-dir> <owner/repo> <tag> <release-name> <target-commit>
#
# `tag` is the pushed tag for a `v*` release, or `firmware-<short-sha>` for a
# push to main (Forgejo creates the tag at target-commit if it does not exist).
# Re-running with the same tag updates the existing release instead of failing:
# the firmware build is triggered again on every push that touches it.
set -eu

OUT_DIR="${1:?out dir}"
REPO="${2:?owner/repo}"
TAG="${3:?tag}"
NAME="${4:?release name}"
TARGET="${5:-}"

: "${FORGEJO_URL:?FORGEJO_URL not set}"
: "${FORGEJO_TOKEN:?FORGEJO_TOKEN not set}"

API="$FORGEJO_URL/api/v1/repos/$REPO"
AUTH="Authorization: token $FORGEJO_TOKEN"
SHORT=$(printf '%s' "$TARGET" | cut -c1-12)

# JSON is built with jq: the release body has newlines and shell-hostile
# characters, and hand-escaping it was the only fragile part of this script.
PAYLOAD_FILE=$(mktemp)
jq -n \
  --arg tag "$TAG" \
  --arg name "$NAME" \
  --arg target "$TARGET" \
  --arg body "Firmware ZMK construido por Tekton (Pipelines-as-Code) desde el commit $SHORT.

Contiene: cornix (50 teclas), totem (38), forager (34), incluidos los binarios
para dongle y los settings_reset.

Toolchain: zmkfirmware/zmk-build-arm:3.5-branch. Descarga el .uf2 del teclado
que vayas a flashear: un fichero por controlador." \
  '{tag_name: $tag, name: $name, body: $body, target_commitish: $target,
    draft: false, prerelease: false}' > "$PAYLOAD_FILE"

echo "== release $TAG on $REPO"
RESP=$(curl -sS -w '\n%{http_code}' -X POST -H "$AUTH" -H 'Content-Type: application/json' \
  "$API/releases" --data @"$PAYLOAD_FILE")
rm -f "$PAYLOAD_FILE"
CODE=$(printf '%s' "$RESP" | tail -1)
BODY=$(printf '%s' "$RESP" | sed '$d')

if [ "$CODE" = "201" ]; then
  ID=$(printf '%s' "$BODY" | jq -r .id)
else
  echo "create returned $CODE, looking up existing release for tag $TAG"
  ID=$(curl -sS -H "$AUTH" "$API/releases/tags/$TAG" | jq -r '.id // empty')
  if [ -z "$ID" ]; then
    echo "FAIL: cannot create or find release $TAG: $BODY"
    exit 1
  fi
fi
echo "release id: $ID"

COUNT=0
FAILED=0
for FILE in "$OUT_DIR"/*/*.uf2; do
  [ -f "$FILE" ] || continue
  KEYBOARD=$(basename "$(dirname "$FILE")")
  ASSET="$KEYBOARD-$(basename "$FILE")"
  # A re-run for the same tag hits "asset already exists" (409): delete and
  # re-upload so the release always matches the build that just finished.
  OLD=$(curl -sS -H "$AUTH" "$API/releases/$ID/assets?name=$ASSET" | jq -r '.id // empty')
  if [ -n "$OLD" ]; then
    curl -sS -o /dev/null -X DELETE -H "$AUTH" "$API/releases/$ID/assets/$OLD"
  fi
  ASSET_CODE=$(curl -sS -o /tmp/asset.json -w '%{http_code}' -X POST -H "$AUTH" \
    -F "attachment=@$FILE" "$API/releases/$ID/assets?name=$ASSET")
  if [ "$ASSET_CODE" = "201" ]; then
    COUNT=$((COUNT + 1))
    echo "  uploaded $ASSET"
  else
    FAILED=$((FAILED + 1))
    echo "  FAIL uploading $ASSET (HTTP $ASSET_CODE): $(cat /tmp/asset.json)"
  fi
done

echo "== published $COUNT assets ($FAILED failures) to $FORGEJO_URL/$REPO/releases/tag/$TAG"
[ "$COUNT" -gt 0 ] || { echo "FAIL: nothing uploaded"; exit 1; }
[ "$FAILED" -eq 0 ] || exit 1
