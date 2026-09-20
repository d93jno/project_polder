#!/usr/bin/env bash
# Open the Godot editor for this project.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/scripts/godot.sh" --path "$ROOT" --editor "$@"
