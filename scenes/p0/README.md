# P0 lighting tests

Flooded roof vs Dry street. Same kit, same camera, dusk look A. These are composition / projection pictures, not BowlMap, LOS, or combat.

**Falling vs Flooded is not in this folder.** A/B here is **Flooded vs Dry**. Both planes use `assets/shaders/water.tres` (`step` 0 or 3). `make run` opens `presentation/gallery.gd` on the flooded bowl plus HUD/humanoid — that is art wiring, not a fight.

## Open

From the repo root, Godot 4.7.2 (`docs/ENGINE.md`):

```
make editor
```

or `$HOME/bin/godot --path . --editor`. Then open `scenes/p0/flooded_roof.tscn` or `scenes/p0/dry_street.tscn`. Run a scene with F6.

`scenes/main.tscn` is still the project main scene stub.

Regenerate (overwrites the two `.tscn` files):

```
$HOME/bin/godot --headless --path . --script res://scenes/p0/_build_p0_scenes.gd
```

## What to look at

| | Flooded | Dry |
| --- | --- | --- |
| Scene | `flooded_roof.tscn` | `dry_street.tscn` |
| Plane | `WaterPlane` at **Y = 2.4 m** (`env_water_flooded.png`, slight alpha) | `WaterPlane` at **Y = −0.04 m** (`env_ground_dry.png`) |
| Street | Swim / dive; first-floor windows under | Walkable asphalt, long open sightline |
| Roofs | Walkable (~3.7 m freeboard to eaves) | Same decks; roofs read taller because the water is gone |
| Boat | Floated at the pier (`Y = 1.9`) | Keel on the dry canal (`Y = 0`) |

Shared: terrace run of four house shells, two roof decks + tarp / pallet shanty, tall canal quay, levee far bank, pump house, sluice, pier, cover props (crate, plank, masonry corner), ridge on the **left-forward horizon, not dead-centre**. Painted waterline on House D; `ON` plate on the pump; terrace grade plate on the levee. No ridge nameplate.

Water plane uses `res://assets/shaders/water.tres`.

## Camera / light / grid

- **`CameraRig`** (`presentation/camera_rig.gd`) — same code path as `make run`. Fixed pitch, 25° FOV, 90° snap (`[` `]`), three zooms (wheel), `O` for ortho, MMB / Alt-drag peek. Rest looks +X down the street. Regenerated into both scenes by `_build_p0_scenes.gd`.
- **`LightDay`** — dusk look A, high overcast directional, cool, no golden hour. **`WorldEnvironment`** procedural sky + light fog.
- Cell size **2.0 m**. House / pump / sluice footprints are 2×2 cells (place on even metres). Pieces are `MeshInstance3D` instances, not a GridMap.

## Instanced glb

All of these appear in both scenes:

**Terrace kit** (`assets/env/kits/terrace/`)

- `env_street_slab_a.glb`, `env_street_slab_b.glb`, `env_street_slab_c.glb`
- `env_curb.glb`
- `env_canal_wall_tall.glb`
- `env_levee_straight.glb`, `env_levee_inner_corner.glb`, `env_levee_outer_corner.glb`, `env_levee_slope.glb`
- `env_house_2storey_a.glb`, `env_house_2storey_b.glb`, `env_house_2storey_c.glb`, `env_house_2storey_d.glb`
- `env_floor_interior_1.glb`, `env_floor_interior_2.glb`
- `env_roof_deck_a.glb`, `env_roof_deck_b.glb`
- `env_shanty_tarp.glb`, `env_shanty_pallet_wall.glb`, `env_shanty_plot_box.glb`
- `env_hatch.glb`, `env_ladder.glb`, `env_stair.glb`
- `env_pump_house.glb`, `env_sluice_gauge.glb`, `env_pier.glb`
- `env_furn_lamp.glb`, `env_furn_bench.glb`, `env_furn_bollard.glb`, `env_furn_rail.glb`

**Hero / vehicles / props**

- `assets/env/hero/env_ridge_farfield.glb`
- `assets/vehicles/veh_boat_camp.glb`
- `assets/props/prop_crate_wood.glb`
- `assets/props/prop_plank_wood.glb`
- `assets/props/prop_cover_masonry_corner.glb`

**Not meshes** (quads / decal / plane albedos): `worldtext_pump_held.png`, `worldtext_waterline_paint.png`, `worldtext_grade_terrace.png`, `env_decal_waterline_dirt.png`, plus `env_water_flooded.png` or `env_ground_dry.png`.
