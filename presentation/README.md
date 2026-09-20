# Presentation

Scenes draw. `rules/` decides. This folder instances art under `res://assets/` and applies **already-validated** commands.

It does not reimplement LOS, break, contact, or AP. Hover previews call `Los.line_of_sight`, `Movement.path`, `ExposureQuery.exposure`, `Cones.watch_cone`, and `BreakRule.check` — the same functions the tests use (UI §1).

`make run` opens `fight_view.gd` on the **cutaway fixture** (flooded street + roof, plank rifle Watch, smoke apex). Overlays come only from `overlay_queries.gd` (cones, exposure words, path exposure, stack labels). Camera is the shared `PresentationCameraRig` — **perspective 25° + hold-to-peek** (plan 2.5). `PgUp`/`PgDn` cutaway; `F` toggles Falling ↔ Flooded. Click a tile to walk (free until contact, then AP). Click a hostile to shoot. Q sets a Watch toward the hovered cell. Space / the phase plaque ends a phase. The scripted-fight opening returns in 2.6.

Lighting tests stay under `scenes/p0/`. `gallery.gd` is still the art-only flooded bowl, not a fight.
