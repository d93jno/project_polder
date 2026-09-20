# Presentation

Scenes draw. `rules/` decides. This folder instances art under `res://assets/` and applies **already-validated** commands.

It does not reimplement LOS, break, contact, or AP. Hover previews call `Los.line_of_sight`, `Movement.path`, `ExposureQuery.exposure`, `Cones.watch_cone`, and `BreakRule.check` — the same functions the tests use (UI §1).

`make run` opens `fight_view.gd`: the scripted-fight street (dry, masonry wall, four squad, three Drifters). Kit meshes come from `PresentationCatalog` via `bowl_draw`. Shared `PresentationCameraRig` handles yaw snap, zoom, ortho, and peek. Click a tile to walk (free until contact, then AP). Click a hostile to shoot. Q sets a Watch toward the hovered cell. Space / the phase plaque ends a phase; the enemy then takes legal shots and yields.

Lighting tests stay under `scenes/p0/`. `gallery.gd` is still the art-only flooded bowl, not a fight.
