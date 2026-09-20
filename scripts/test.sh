#!/usr/bin/env bash
# Run the GUT suite headless. Exit non-zero on any failure.
#
# GUT itself exits 0 when a test file fails to load (syntax error, missing
# preload) or when no tests are found, so a broken rules/ file would leave the
# suite green. Scan the output for those cases and fail on them.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

"$ROOT/scripts/godot.sh" --headless --path "$ROOT" -s addons/gut/gut_cmdln.gd "$@" 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}

if sed 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -qE 'SCRIPT ERROR|Failed to load script|\[GUT ERROR\]|Nothing was run'; then
  echo "test.sh: GUT reported a load error or an empty run; failing." >&2
  [ "$rc" -eq 0 ] && rc=1
fi
exit "$rc"
