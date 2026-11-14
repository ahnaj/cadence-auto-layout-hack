#!/bin/sh
# SPDX-License-Identifier: MIT
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
command -v python3 >/dev/null || { echo "Python 3.6+ is required." >&2; exit 1; }
mkdir -p "$ROOT/.local"
if [ ! -f "$ROOT/.local/config.json" ]; then
    cp "$ROOT/config/tech/ncsu_tsmc03.example.json" "$ROOT/.local/config.json"
fi
chmod +x "$ROOT/bin/autolayout"
"$ROOT/bin/autolayout" --cds-lib "${1:-cds.lib}" doctor
echo "Set the null physical constraints in .local/config.json from your installed PDK."
echo "Add $ROOT/bin to PATH, or invoke bin/autolayout directly."
