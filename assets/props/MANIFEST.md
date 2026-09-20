# Props — P0 cover + tile memory

Meshes are glTF 2.0 (`.glb`), Y-up, metres, origin at footprint centre (min Z = 0). Cover class is a material tag the line preview names (GDD §5.4, assets §1). The mesh is meant to make that class guessable before hover.

Concepts: isolated on mint `#00FFAA`, elevated three-quarter, no ground, no cast shadow. Palette from `assets/_style/env_style_lock.png`.

No `env_furn_*` pieces here — terrace street furniture is the environment kit’s slot; `assets/env/kits/terrace/` was empty at authoring, and those names are not duplicated.

| File | Cover tag | Stops pistol | Stops rifle | Notes |
| --- | --- | --- | --- | --- |
| `prop_crate_wood.glb` + `.png` | **pistol-stop** (`plank_crate`) | yes | no | Wet slatted crate, rust straps. Wood class. |
| `prop_plank_wood.glb` + `.png` | **pistol-stop** (`plank_crate`) | yes | no | Hip-high pallet + upright boards. Same class as the crate. |
| `prop_cover_masonry_corner.glb` + `.png` | **masonry** | yes | no (rifle may punch) | Ochre-brick L-corner, ~1 m. Tagged honestly: masonry, not rifle-stop. |
| `prop_dropped_crate.glb` + `.png` | **pistol-stop** (`plank_crate`) | yes | no | Tile-memory overlay (assets §4.6). Open, lid off, burst straps. Remaining wood still pistol-stop. |

Root extras on every mesh: `polder_cover`, `polder_cover_class`, `polder_stops_pistol`, `polder_stops_rifle`, `polder_material`. Dropped crate also has `polder_tile_memory`.

Footprints (metres):

| Asset | Size (X × Y × Z) |
| --- | --- |
| `prop_crate_wood` | 1.00 × 0.72 × 0.75 |
| `prop_plank_wood` | 1.22 × 0.82 × 0.93 |
| `prop_cover_masonry_corner` | 1.22 × 1.22 × 1.04 |
| `prop_dropped_crate` | ~1.00 × 1.00 × 0.78 |
