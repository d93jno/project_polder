---
name: screenshot
description: Capture a frame of Project Polder's running Godot scene in a real window, so you can see and debug layout, HUD, overlay, shader, camera or cutaway problems that `make test` cannot see. Use when the user reports a visual artifact, or after changing anything under presentation/, assets/shaders/ or the HUD, before calling it done. Also covers running the `make shots` render smoke.
---

# Screenshot a Polder scene

`make test` runs headless, so it cannot see a shader that fails to compile, a HUD that never updates, or a label sitting on a unit. To see the screen, open a window, put the scene in the state you care about, save one frame, and Read the PNG.

One driver does both jobs: `tests/shots/capture.gd`, run by `scripts/shots.sh`.

## Ad-hoc capture (troubleshooting one state)

```bash
scripts/shots.sh --out=build/shots/name.png \
  --do='set_process(false)' \
  --do='set("_hover", Vector3i(10,5,0))' \
  --do='_try_watch()'
```

Then `Read build/shots/name.png`. `build/` is gitignored; use the session scratchpad instead if you would rather not write there.

| Option | Meaning |
| --- | --- |
| `--do=EXPR` | GDScript expression run on the scene root, in order; repeat it. Expressions cannot assign: use `set("name", v)` or call methods. |
| `--hook=res://x.gd` | Script with a synchronous `func setup(scene: Node)`, for setups too long for `--do`. |
| `--scene=res://…tscn` | Scene to open. Default is the fight view (`scenes/main.tscn`). |
| `--crop=x,y,w,h` `--zoom=3` | Also write `<out>_crop.png`, enlarged. Use it for HUD detail. |
| `--probe=x,y` | Print the pixel colour there. Checks "is this pip lit?" without eyeballing. Repeat it. |
| `--warmup=N` `--settle=N` | Frames before setup (default 2) and after (default 20). Raise `--settle` if something animates or streams in. |
| `SIZE=1166x689` (env) | Window size, default 1280x720. Pixel coordinates in `--crop` and `--probe` depend on it. |

Success prints `shots: wrote …`. A failed `--do`, an engine `SHADER ERROR`/`SCRIPT ERROR`/`ERROR:`, or an empty frame exits non-zero.

## Handles on the fight view (`presentation/fight_view.gd`)

Always start with `set_process(false)`. Otherwise `_process` overwrites your hover from the real mouse position every frame.

| To… | `--do=` |
| --- | --- |
| Hover a cell | `set("_hover", Vector3i(10,5,0))`, then `_redraw()` |
| Select a unit | `set("_selected_id", 2)`, then `_redraw()` (ids 1–4 are the squad) |
| Set Piet's Watch | `_try_watch()` (faces the hovered cell; costs 3 AP) |
| Cycle selection / end phase | `_cycle_selected()` / `_end_phase()` |
| Cutaway level | `_set_cutaway(1)` |
| Flip Falling ↔ Flooded | `_toggle_falling_flooded()` |
| Rotate the camera 90° steps | `get_node("CameraRig").snap_yaw(2)` |
| Zoom (0 near … 2 far) | `get_node("CameraRig").set_zoom(0)` |
| Peek yaw | `get_node("CameraRig").set("peek_deg", 20.0)`, then `apply_pose()` on the rig |
| Hide something | `get_node("Ridge").set("visible", false)` |

These are private members and will drift with the code. If one fails, the error names it; read `fight_view.gd`.

## The regression suite

`make shots` (or `scripts/shots.sh` with no arguments) captures the named setups and runs pixel probes that guard two past bugs: a cone shader that failed to compile (cream cylinder), and HUD pips that stopped dimming. Add a new named setup to `capture.gd` when a visual bug is worth guarding, with a probe that fails on the bug.

## Gotchas

- **Needs a display.** It briefly opens a window on the user's desktop. `--headless` renders nothing and the run fails on purpose. `xvfb-run` is not installed here.
- **A frame that rendered is not proof it is right.** Look at it. Engine errors fail the run, but layout overlap, wrong aim and wrong colour do not.
- **Do not edit tracked files to test the tool's failure paths.** Use a bad `--do=nope()` for a failing run.
- Probe coordinates and label positions change with `SIZE`, camera yaw and zoom.
