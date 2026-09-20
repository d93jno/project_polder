# Terrace kit — P0

GridMap mesh library for the first bowl. Rebuild:

```
/snap/bin/blender --background --python assets/env/kits/terrace/_build_kit.py
```

Writes `.glb` here and `assets/env/hero/env_ridge_farfield.glb`.

## Cell size

**2.0 m** (one GridMap cell). Every piece obeys it.

- Street slabs, curb, canal wall, levees, furniture, stair, ladder, hatch, shanty: **1 cell** (or smaller, origin at footprint centre).
- House shells, interior floors, roof decks, pump house, sluice: **2 × 2 cells** (4.0 m footprint), origin at footprint centre. Place on even coordinates, leave the other three cells empty.
- Pier: **1 × 3 cells** (2 × 6 m), origin at footprint centre.
- Ridge: far-field, not a GridMap tile.

Y-up, metres. Origin at tile / footprint centre. No baked ground shadow. Scale vs a 1.7 m human: door 2.1 m, storey 3.0 m, house eaves 6.15 m, ridge far-field ~10 m high over 80 m.

Street slab top is local **Y = 0** (thickness 0.15 m below). Buildings sit on **Y = 0**. Roof-deck walking surface is local **Y = 0** (place the instance at roof height). Interior floor 1 is at Y ≈ 0.02, floor 2 at Y = 3.0, so they drop in at the same origin as the house.

## Cover tags

Material is the only cover (GDD §5.4). Line preview names the class. Rails that look like cover but are not will break the read — `env_furn_rail` is Ø ~4 cm on purpose.

| Piece | Cover | Notes |
| --- | --- | --- |
| `env_street_slab_a/b/c` | none | Floor. |
| `env_curb` | none | 0.16 m upstand. |
| `env_canal_wall` | masonry | 1.2 m quay, walkable coping. |
| `env_canal_wall_tall` | masonry | 2.4 m variant. |
| `env_levee_straight` | masonry | 2.0 m earthen berm, hard cover. |
| `env_levee_inner_corner` | masonry | Concave L. |
| `env_levee_outer_corner` | masonry | Convex L. |
| `env_levee_slope` | masonry | Height falls toward local +X (Blender); Godot +X. |
| `env_house_2storey_a/b/c/d` | masonry | Brick / plaster shells. |
| `env_floor_interior_1/2` | none | Cutaway plates, stair well. |
| `env_roof_deck_a/b` | none | Walkable. Parapet 0.42 m is too low to tag. |
| `env_shanty_tarp` | none | Cloth. |
| `env_shanty_pallet_wall` | crate | ~1.5 m wood. Stops pistol, not rifle. |
| `env_shanty_water_tank` | metal | Stand + tank. |
| `env_shanty_plot_box` | crate | Low planter; pistol only if crouched. |
| `env_stair` | masonry | Concrete flight, 3.0 m rise. Handrail is thin, not the tag. |
| `env_ladder` | none | Thin iron. |
| `env_hatch` | none | Flat lid, not a blocker. |
| `env_pump_house` | masonry | `pump_house` mesh. |
| `env_sluice_gauge` | masonry | Abutments. Gate is metal but is the moving leaf, not a cover prop. |
| `env_pier` | crate | Wet wood deck. |
| `env_furn_lamp` | none | Pole. |
| `env_furn_bench` | none | Seat 0.42 m. |
| `env_furn_bollard` | none | Ø 0.22 m, 0.92 m. |
| `env_furn_rail` | **none** | Thin. Do not retag. |
| `env_ridge_farfield` | n/a | Horizon object, not tactical cover. |

## Piece list

### Streets / water edge

| File | Footprint | Notes |
| --- | --- | --- |
| `env_street_slab_a.glb` | 2 × 2 m | Wet asphalt, grate, joints. |
| `env_street_slab_b.glb` | 2 × 2 m | Concrete pavers. |
| `env_street_slab_c.glb` | 2 × 2 m | Patched asphalt, manhole. |
| `env_curb.glb` | 2 m run | Godot: along X, on the −Z edge of the cell. |
| `env_canal_wall.glb` | 2 m run | 1.2 m masonry quay. |
| `env_canal_wall_tall.glb` | 2 m run | 2.4 m. Extra SKU, same kit. |
| `env_levee_straight.glb` | 1 cell | Crest along X. Neutral colours, rotation-safe, **no text**. |
| `env_levee_inner_corner.glb` | 1 cell | Concave toward +X / −Z (Godot). Connect straights on the other two sides. |
| `env_levee_outer_corner.glb` | 1 cell | Convex L. |
| `env_levee_slope.glb` | 1 cell | Ramp down toward +X. |

Levee lighting is vertex/base colour only — rotate in 90° GridMap steps.

### Houses / roofs / interiors

| File | Footprint | Notes |
| --- | --- | --- |
| `env_house_2storey_a.glb` | 4 × 4 m | Ochre brick, cream door, chimney. |
| `env_house_2storey_b.glb` | 4 × 4 m | Red brick, dormer, dark door. |
| `env_house_2storey_c.glb` | 4 × 4 m | Dirty cream plaster, darker roof. |
| `env_house_2storey_d.glb` | 4 × 4 m | Brown brick, boarded window, end-unit side window. |
| `env_floor_interior_1.glb` | 4 × 4 m | Ground plate + stair well. Same origin as house. |
| `env_floor_interior_2.glb` | 4 × 4 m | Storey-2 plate at Y = 3.0 m. |
| `env_roof_deck_a.glb` | 4 × 4 m | Bitumen, parapet, vents. Walkable. |
| `env_roof_deck_b.glb` | 4 × 4 m | Skylight bump. Walkable. |

Shells have no interior floors. Cutaway is a visibility toggle on the floor nodes (UI §2). Street face is local −Z (Godot).

### Shanty / climb

| File | Notes |
| --- | --- |
| `env_shanty_tarp.glb` | Blue fly, orange strap. Snaps to a roof deck. |
| `env_shanty_pallet_wall.glb` | Crate cover. |
| `env_shanty_water_tank.glb` | Metal cover. |
| `env_shanty_plot_box.glb` | Planter. |
| `env_stair.glb` | 2 m run, 3.0 m rise, along Godot −Z → +Z. |
| `env_ladder.glb` | One storey (3.25 m). Scale in Y for two. |
| `env_hatch.glb` | Closed lid, sits on a deck. |

### Hero machines / extract

| File | Nodes | Notes |
| --- | --- | --- |
| `env_pump_house.glb` | `env_pump_house` / `pump_house` / `dressing_damaged` | Hide `dressing_damaged` when the pump is kept. Show for damaged / dead. Upkeep (kept / thin / failing) is a material pass, not extra meshes. |
| `env_sluice_gauge.glb` | `env_sluice_gauge` / `sluice_frame` / **`sluice_gate`** | Animate `sluice_gate` **local +Y** (Godot) to open. Closed = 0. Full open ≈ **2.2 m**. Blank cabinet, no meter. |
| `env_pier.glb` | single | Extract dock. Posts drop to Y = −1.4 m. |

### Street furniture

| File | Cover |
| --- | --- |
| `env_furn_lamp.glb` | none |
| `env_furn_bench.glb` | none |
| `env_furn_bollard.glb` | none |
| `env_furn_rail.glb` | **none** (thin) |

### Far field (not this folder)

| File | Notes |
| --- | --- |
| `assets/env/hero/env_ridge_farfield.glb` | Low sandy moraine, ~80 × 34 m, peak ~10 m. Nodes: `ridge_terrain`, `ridge_glint`. Glint is a tiny glass box on a shoulder — not a nameplate, not a compass pip, not alpine. |

## Materials

Principled BSDF, lock palette: wet-slate teal (coat on asphalt), ochre / red / brown brick, rust iron, dirty cream plaster, terracotta roofs, sand levees. Box-projected UVs, one repeat per 2 m cell.

Albedos from `textures/` packed into the glb where they tile:

| Texture | Assigned to |
| --- | --- |
| `env_street_slab_a.png` | asphalt slabs a/b/c base |
| `env_curb.png` | curb, pavers (slab b), concrete |
| `env_canal_wall.png` | canal wall masonry; sluice abutments |
| `env_levee_fill.png` | all levee pieces + ridge sand |

`env_street_slab_c.png` is a peeling-plaster / photo ghost, not a road — not assigned. `env_water_flooded.png` is a water look, not a kit mesh. Houses, shanties, furniture, pump, sluice, pier stay base colour.

**Wet + dry (same mesh).** Default look is wet. Dry is a Godot material duplicate: higher roughness, slightly lifted albedo, coat weight 0. Do not duplicate meshes per water step.

## Missing SKUs (P0 env pack, not this pass)

Owned elsewhere, or not in the mesh brief:

- Flooded / Dry water-plane looks (shader, one plane per bowl)
- 8 terrace world plates (step, grade, pump state, upkeep — own machine only)
- One painted waterline decal
- Cover-tagged crates and planks (3) — kit has pallet wall / plot box as crate stand-ins; dedicated street crates are still open
- Authored second material slots for dry (use a duplicate, above)
- Kit A extras not in P0: 3–4 storey block, shed, fire escape, door/window sets, overpass, parking deck, church loft, rooftop bridge, vegetation, levee gate fill

## Do not

- Invent Alpine mountains
- Duplicate meshes per water step
- Bake a lightmap that assumes one water height
- Put text on levee pieces
- Put a nameplate or compass on the ridge
- Tag `env_furn_rail` as cover
