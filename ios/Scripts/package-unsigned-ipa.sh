#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="${1:-$ROOT/Build/EyeRest.xcarchive}"
APP="$ARCHIVE/Products/Applications/EyeRest.app"
OUT="$ROOT/Build/EyeRest-unsigned.ipa"
[[ -d "$APP" ]] || { echo "Missing app bundle: $APP" >&2; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Payload"; cp -R "$APP" "$WORK/Payload/"
ditto -c -k --sequesterRsrc --keepParent "$WORK/Payload" "$OUT"
unzip -l "$OUT" | grep -q 'Payload/EyeRest.app/Info.plist'
echo "Validated IPA structure: $OUT"
echo "WARNING: unsigned IPA is not installable on a normal iPhone; use valid signing for sideloading."
