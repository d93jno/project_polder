#!/usr/bin/env bash
# Render smoke (plan 3.0). Opens a real window, captures, fails on shader/script errors
# or pixel-probe failures inside tests/shots/capture.gd.
# Needs a GPU and a display — not part of `make test`.
#
#   scripts/shots.sh                      the named regression setups (also: make shots)
#   scripts/shots.sh --do=EXPR ...        one ad-hoc capture of whatever state you set up;
#                                         options are listed in the header of capture.gd, e.g.
#     scripts/shots.sh --do='set_process(false)' --do='set("_hover", Vector3i(10,5,0))' \
#                      --do='_state.set("in_contact", true)' --do='_try_watch()' --out=build/shots/watch.png --crop=10,590,300,60
#   SIZE=1166x689 scripts/shots.sh ...    window size (default 1280x720)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/build/shots"
SIZE="${SIZE:-1280x720}"
mkdir -p "$OUT_DIR"

if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
  echo "shots: no DISPLAY or WAYLAND_DISPLAY; a window cannot open." >&2
  exit 1
fi

# capture LABEL EXPECTED_PNG_OR_EMPTY ARGS... ; returns non-zero on any failure.
capture() {
  local label="$1" png="$2"
  shift 2
  local log run_rc
  log="$(mktemp)"
  "$ROOT/scripts/godot.sh" --path "$ROOT" \
    --resolution "$SIZE" \
    --audio-driver Dummy \
    -s tests/shots/capture.gd \
    -- "$@" \
    >"$log" 2>&1
  run_rc=$?
  cat "$log"

  if sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -qE 'SHADER ERROR|SCRIPT ERROR|ERROR:'; then
    echo "shots: stderr reported SHADER/SCRIPT/ERROR for $label; failing." >&2
    run_rc=1
  fi
  if [[ -n "$png" && ! -f "$png" ]]; then
    echo "shots: missing PNG for $label" >&2
    run_rc=1
  fi
  rm -f "$log"
  return "$run_rc"
}

if [[ $# -gt 0 ]]; then
  # Ad-hoc: pass everything through; capture.gd reports its own failures.
  capture adhoc "" "$@"
  exit $?
fi

SETUPS=(street_watch street_ap_spent street_yaw180 terrace_flooded terrace_falling terrace_roof_cutaway terrace_water_bare terrace_falling_bare terrace_fog_unknown terrace_fog_peeled street_fog_known_quiet)
rc=0

for setup in "${SETUPS[@]}"; do
  PNG="$OUT_DIR/${setup}.png"
  echo "shots: $setup → $PNG"
  extra=()
  case "$setup" in
    terrace_*) extra=(--bowl=terrace) ;;
  esac
  capture "$setup" "$PNG" --setup="$setup" --out="$PNG" "${extra[@]}" || rc=1
done

if [[ $rc -eq 0 ]]; then
  echo "shots: all setups ok → $OUT_DIR"
fi
exit "$rc"
