#!/usr/bin/env bash
# Run the project (debug / editor binary, not an export).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/scripts/godot.sh" --path "$ROOT" "$@"
