# Shaders — P0 water / fog / cones / selection

Godot 4.7 Forward+. `shader_type spatial` on every file here. Drop-in materials are the `.tres` next to each shader. Preview: `water_preview.tscn` (open in the editor; four water steps in a row, ghost / fog / cones / selection behind them).

Albedos live under `assets/env/kits/terrace/textures/`. Pattern textures under `assets/vfx/`.

## Drop a water plane

1. `MeshInstance3D` + `PlaneMesh` (subdivide if you want Flooded vertex waves).
2. Assign `water.tres` (or a duplicate).
3. Set the node’s Y to `water_height` metres from data. Leave `displace_to_height` off.
4. Set `step` from `Taxonomy.WaterStep` (0 Flooded, 1 Falling, 2 Mud, 3 Dry).
5. A levee map holds two planes, one material each.

Optional: `displace_to_height = true` and leave the node at y=0 — the shader writes `VERTEX.y = water_height`. Do not do both.

`reduced_motion` (UI §14): freeze UV scroll and vertex waves. Flooded stays dark; Falling keeps debris in the albedo.

## Uniforms

### `water.gdshader` — `water.tres`

| Uniform | Type | Default | Notes |
| --- | --- | --- | --- |
| `step` | int enum | 0 Flooded | 0 Flooded, 1 Falling, 2 Mud, 3 Dry |
| `water_height` | float m | 2.0 | From data. Placement, not the look. |
| `reduced_motion` | bool | false | Motion is extra. Looks still split. |
| `displace_to_height` | bool | false | Vertex Y = `water_height` |
| `albedo_flooded` | sampler | `env_water_flooded.png` | Deep, dark. Luma ~41. |
| `albedo_falling` | sampler | `env_water_falling.png` | Murky + debris. Luma ~104. |
| `albedo_mud` | sampler | `env_ground_mud.png` | Wet ground, pools. Luma ~81. |
| `albedo_dry` | sampler | `env_ground_dry.png` | Pale silt. Luma ~175. |
| `uv_scale` | float | 0.25 | World-XZ; 4 m per tile at 0.25 |
| `flood_speed` | float | 1.0 | UV scroll. 0 when reduced. |
| `falling_speed` | float | 0.28 | Quieter than Flooded. |
| `flood_wave_cm` | float | 4.0 | Vertex amp, Flooded. Needs subdiv. |

Include: `water.gdshaderinc` (UV helper, hash, luma, rings). Ghost / fog / cone / selection include it too.

### `water_ghost.gdshader` — `water_ghost.tres`

Redirection preview. Transparent. No fade-to-black.

| Uniform | Type | Default | Notes |
| --- | --- | --- | --- |
| `step` | int enum | 0 | Ghost of the target look |
| `is_range` | bool | false | Half-fixed ring: hatch + dashed world rings |
| `reduced_motion` | bool | false | Rings stay; dashes stop crawling |
| `ghost_alpha` | float | 0.38 | |
| albedo_* | sampler | same four | |
| `hatch_tex` | sampler | `vfx_cone_hatch.png` | |
| `uv_scale` | float | 0.25 | |
| `tint` | color | pale slate | Reinforces. Pattern carries “preview”. |

### `fog_ageing.gdshader` — `fog_ageing.tres`

Known-quiet overlay (second mesh or `next_pass`). Unknown = engine draws nothing. Live = `staleness` 0 (shader discards).

| Uniform | Type | Default | Notes |
| --- | --- | --- | --- |
| `staleness` | 0..1 | 0.65 in .tres | Dust, flatter, colder. No digits. |
| `reduced_motion` | bool | false | Grade holds; grain drift is extra |
| `dust_tint` | color | warm grey | |
| `cold_tint` | color | cool grey | Mixes in with staleness |
| `veil` | float | 0.34 | Base alpha scale |
| `dust_scale` | float | 18 | World-XZ specks |

### `watch_cone.gdshader` — `watch_cone.tres`

Same tint for every faction. Vanguard is a longer mesh, not a hue. Overlap is named in UI.

Mesh: `CylinderMesh` `top_radius` ~0, `bottom_radius` = `cone_radius`, `height` = `cone_height`, no caps. Godot Y is the axis (apex +Y). Offset −height/2 on Y and rotate +Y into the look direction so the apex sits on the watcher.

| `mode` | Look |
| --- | --- |
| 0 FriendlyOutline | Fresnel / rim / rings / spokes. No fill soup. |
| 1 EnemyLive | Full volume, hatch + rings. Always drawn. |
| 2 UnresolvedApex | Live volume; near end dissolves. No apex on a tile. |
| 3 Spent | `discard`. Tick is on the unit, not this shader. |

| Uniform | Type | Default |
| --- | --- | --- |
| `mode` | int enum | 1 EnemyLive |
| `reduced_motion` | bool | false (hatch still there) |
| `cone_height` | float m | 8 — **match the mesh** |
| `cone_radius` | float m | 3 — **match the mesh** |
| `apex_fade` | float | 0.22 along-axis, mode 2 |
| `tint` | color | paper-slate, one for all |
| `hatch_tex` | sampler | `vfx_cone_hatch.png` |
| `hatch_scale` | float | 1.1 world-XZ |
| `fill_alpha` | float | 0.16 |
| `outline_alpha` | float | 0.82 |
| `ring_count` | float | 6 |

### `selection.gdshader` — `selection.tres`

Ground torus under a unit. Same mark for every body. Not a founder crown.

Mesh: `PlaneMesh` ~1.4 m, a few cm above the tile.

| Uniform | Type | Default |
| --- | --- | --- |
| `tint` | color | paper |
| `ring_tex` | sampler | `vfx_selection_ring.png` (RGBA) |
| `use_ring_tex` | bool | true — procedural rings if false |
| `inner` / `outer` | float | procedural fallback |
| `alpha` | float | 0.85 |
| `reduced_motion` | bool | unused; mark is static |

## Textures this pass

| File | Size | Notes |
| --- | --- | --- |
| `textures/env_water_falling.png` | 1024² | From flooded albedo + style lock (image_edit), then wrap-safe debris composite. 2×2: `_verify_env_water_falling_2x2.png`. |
| `textures/env_ground_mud.png` | 1024² | From dry ground + style lock (image_edit), then periodic wrapped pools on the tiling dry grain. 2×2: `_verify_env_ground_mud_2x2.png`. |
| `vfx/vfx_cone_hatch.png` | 512² | Greyscale diagonal hatch, tileable. Identity of “this is a cone”. |
| `vfx/vfx_selection_ring.png` | 512² RGBA | Double torus, transparent outside. |

Value contract (greyscale still splits): Flooded ~41 / Falling ~104 + debris / Mud ~81 + pools / Dry ~175.

## Accessibility

- Colour reinforces. Flooded vs Falling is value + debris, not hue. Debris is in the albedo, so reduced motion still holds Falling.
- Cone vs ground is hatch / rings / fresnel, one tint.
- Fog ageing is a grade. Grain may drift; the veil does the work.
- Ghost range is hatch + rings, not a dark fade.

Compile-checked Godot 4.7.2.stable headless: include, five shaders, five `.tres`, and `water_preview.tscn` (13 children) all load.

## Defects

- Falling debris is stamped slats on a regraded flooded ripple field. Reads in greyscale; a bit graphic next to the photographic flood fill. Mild wrap-seam (~18 luma vs flooded ~7) from the murky-grade mix.
- Mud pools are periodic blobs so they wrap. Photographic mud ponds from the lock pass did not tile and were not shipped. Wet-ground grain is the dry albedo, darkened.
- No screen refraction, no depth-contact foam. Waterline stays `env/decals/env_decal_waterline_dirt.png`. A 1-poly plane will not show vertex waves (UV scroll still runs).
- Fog is a transparent veil, not a framebuffer grade. Live tiles must leave `staleness` at 0 or omit the overlay.
- Cone uniforms `cone_height` / `cone_radius` must match the mesh or `v_along` / dissolve are wrong.
- `hint_enum` labels are editor-only. Nothing in these shaders is world text.
