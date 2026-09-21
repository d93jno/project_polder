# Hero environment meshes

## `env_basin_world_map.glb`

Continuous table-scale terrain for the one authored basin. Build it with:

```bash
/snap/bin/blender --background --python assets/env/hero/_build_basin_world.py
```

- **Extent:** 30.72 × 30.72 km, centred at the origin.
- **Tactical scale:** 15,360 × 15,360 cells at 2 m per cell. It matches
  `PresentationCoords.CELL_M`; the grid is not painted onto the terrain.
- **Mesh density:** sampled every 64 m (32 tactical cells), appropriate for the
  table-scale LOD. Tactical bowls retain their own 2 m authored geometry.
- **Contents:** continuous floor terrain, low central ridge/Citadel footprint,
  depressed canals, and ring/cross dikes that divide visible bowls.
- **Scale:** a 1.7 m party member remains proportionate to a 2 × 2 m cell.
- **Water:** intentionally absent. Per-bowl water remains a step-driven plane
  from `presentation/water_plane.gd`; do not bake or add a basin-wide water
  surface here.
- **Use:** table-scale same-basin LOD and far terrain only. Do not use it as a
  second geoscape or as tactical cover/collision data.
- **Lighting:** no baked lighting or shadows.
