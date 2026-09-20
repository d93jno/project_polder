# Presentation

Scenes draw. `rules/` decides. This folder instances art under `res://assets/` and applies **already-validated** commands.

It does not reimplement LOS, break, contact, or AP. Hover previews call `Los.line_of_sight`, `Movement.path`, `ExposureQuery.exposure`, `Cones.watch_cone`, and `BreakRule.check` — the same functions the tests use (UI §1).

`make run` opens `fight_view.gd` on the **shared scripted-fight opening** (`rules/fixtures/scripted_fight.gd` — same state the headless fight asserts). Dry street, wall, four players, three Drifters. Overlays come only from `overlay_queries.gd`. Camera is **perspective 25° + hold-to-peek** (plan 2.5). Click walk until contact, shoot, Q Watch, Space end phase. `F` toggles Falling ↔ Flooded for the exposure word. Cutaway roof fixture stays for presentation tests only (`presentation/fixtures/cutaway_bowl.gd`).

Lighting tests stay under `scenes/p0/`. `gallery.gd` is still the art-only flooded bowl, not a fight.
