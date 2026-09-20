# Terrace kit albedos — P0 pass

All fills are 1024² PNG. Decal is 1024² RGBA. Derived from `assets/_style/env_style_lock.png` (palette: wet-slate teal, ochre brick, rust, dirty cream, overcast North Sea). No text in albedos. Falling water is not in this pass.

2×2 composites live next to each fill as `_verify_<name>_2x2.png` (real PIL repeat, not a generated grid).

## How they were made

`image_edit` from the 16:9 style lock kept 16:9 and often rebuilt a *scene* (houses, curbs, oil puddles, wall caps). Square wrap-aware bases were authored so pitch divides 1024, then photorealized with `image_edit`. Where photorealize broke wrap (vignette, coping row, unique blotch), **high-frequency grain was transferred onto the tiling base** and edges wrap-blended. That is the shipped brick / klinker / asphalt / curb set.

Session JPGs converted to PNG: `textures/_session/`.

## Production files

| File | Kind | 2×2 | Notes / unfixed defects |
| --- | --- | --- | --- |
| `env_street_slab_a.png` | wet asphalt fill | **pass** | Anonymous aggregate. Faint hairline cracks near wrap from grain transfer — not a landmark puddle. Mean luma ~35. |
| `env_street_slab_a_wet.png` | wetter material of A | **pass** | Colour-grade of A; darker (luma ~29). Same layout. |
| `env_street_slab_a_dry.png` | dry material of A | **pass** | Colour-grade of A; pale dusty (luma ~127). Same layout. |
| `env_street_slab_b.png` | wet klinker pavers | **pass** (mild) | Running bond wraps. **FLAG:** slight large-scale value cloud repeats once per tile. |
| `env_street_slab_b_wet.png` | extra wet klinker | **pass** (mild) | Darker grade of B. Same value-cloud flag. |
| `env_street_slab_c.png` | worn concrete street | **pass** | Even dirty-cream grit. Direct photorealize that survived 2×2. |
| `env_curb.png` | sidewalk / curb pavers | **pass** (mild) | 4×4 slabs, grout on the wrap. **FLAG:** one cooler-grey slab and a transferred hairline repeat. Neutral enough to rotate. |
| `env_canal_wall.png` | wet quay masonry | **pass** | Running-bond concrete, algae even, no waterline band (that's the decal). Tiles X and Y. Direct photorealize. |
| `env_brick_wall_wet.png` | wet ochre brick | **pass** (mild) | Stretcher bond wraps. **FLAG:** a soft darker cloud in the upper third repeats. No cap, no waterline. |
| `env_brick_wall_dry.png` | dry ochre brick | **pass** (mild) | Same bond as wet; paler clay, lighter mortar (luma ~115 vs wet ~64). Same mild cloud. |
| `env_water_flooded.png` | Flooded water look | **pass** | Deep dark wet-slate (luma ~41), small even ripples, no foam swirl. **FLAG:** very slight ripple discontinuity at the wrap if you hunt. |
| `env_ground_dry.png` | Dry ground look | **pass** | Pale matte silt (luma ~175). Value *and* detail differ from Flooded water, not hue alone. Puddles at most (tiny damp specks). |
| `env_levee_fill.png` | levee concrete | **pass** | Packed sand-cement, even aggregate, **non-directional** light — rotation-safe. |
| `../decals/env_decal_waterline_dirt.png` | wall waterline decal | **pass** horizontal | RGBA; black keyed to alpha. Horizontal band of algae/rust-scum. **FLAG:** a couple of rust blotches are readable twice when tiled. Not a building mesh. 1×2 at `_verify_env_decal_waterline_dirt_1x2.png`. |

## Value contract (greyscale)

Flooded water luma ~41 vs dry ground ~175. Wet brick ~64 vs dry brick ~115. Wet asphalt A ~35 vs dry A ~127. Colour is reinforcement only.

## Rotation

Safe to rotate: `env_levee_fill`, asphalt fills, `env_ground_dry`, `env_water_flooded`, `env_street_slab_c`. Brick / canal / curb encode a grid but lighting is flat — rotate if the mesh wants it. Do not rotate anything with the waterline decal applied.

## Not in this drop

Falling water, normals/roughness packs, meshes (`.glb`), characters, UI, world plates.
