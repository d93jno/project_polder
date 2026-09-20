#!/usr/bin/env bash
# Resolve the pinned Godot editor. Override with GODOT=/path/to/godot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED="$(tr -d '[:space:]' < "$ROOT/.godot-version")"
GODOT="${GODOT:-$HOME/bin/godot}"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot not found at $GODOT" >&2
  echo "Install Godot ${EXPECTED} to \$HOME/bin (see docs/ENGINE.md)." >&2
  exit 1
fi

VERSION_OUT="$("$GODOT" --version)"
if [[ "$VERSION_OUT" != *"$EXPECTED"* ]]; then
  echo "Expected Godot ${EXPECTED}, got: ${VERSION_OUT}" >&2
  exit 1
fi

exec "$GODOT" "$@"
