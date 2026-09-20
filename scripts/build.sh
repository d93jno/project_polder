#!/usr/bin/env bash
# Export a Linux x86_64 release build to build/linux/.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/build/linux/project_polder.x86_64}"
mkdir -p "$(dirname "$OUT")"
"$ROOT/scripts/godot.sh" --headless --path "$ROOT" --export-release "Linux" "$OUT"
echo "Exported to $OUT"
