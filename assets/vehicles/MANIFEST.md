# Vehicles — P0 player boat

Meshes are glTF 2.0 (`.glb`), Y-up, metres, origin at footprint centre (min Z = 0). The player boat is a **place on the tactical map** (GDD §3.1): extract, MEDEVAC, dusk camp. Wake-Riders can take it. Not a Vanguard APC. Not a Wake-Rider skiff (P2).

Concept: `veh_boat_camp.png` — three-quarter, isolated on mint `#00FFAA`, palette from `assets/_style/env_style_lock.png`.

| File | Cover tag | Notes |
| --- | --- | --- |
| `veh_boat_camp.glb` + `.png` | **none** | Small wet camp boat. Hull, deck, cabin/helm, tarp, crate dressing, four countable fuel cans. |

## Sockets

| Name | Type | Role |
| --- | --- | --- |
| `socket_pilot` | Empty | Pilot attach. Empty in the file. Sit/stand at the helm. Child of `veh_boat_camp`. |

No other sockets in P0. Later engine/plating upgrades reuse this hull (GDD §7.1).

## Fuel (a count, never a bar)

Four olive jerrycan meshes. Show N of them for the readable fuel load (GDD §4.2, UI §7). Same family, counted by number of cans.

| Mesh | Index |
| --- | --- |
| `fuel_can_01` | 1 |
| `fuel_can_02` | 2 |
| `fuel_can_03` | 3 |
| `fuel_can_04` | 4 |

Extras: `polder_fuel_unit`, `polder_fuel_index`. Root extra `polder_fuel_meshes` lists them.

## Taken / crewed-by-someone-else

Not a second hull.

| Default | Taken |
| --- | --- |
| `tarp_player` visible (`polder_default_visible` true) | hide `tarp_player` |
| `tarp_taken` hidden (`polder_default_visible` false) | show `tarp_taken` |
| Empty `state_taken` extra `polder_taken` = false | set true |

Root extras: `polder_taken`, `polder_taken_show`, `polder_taken_hide`, `polder_socket_pilot`, `polder_place`.

## Footprint

About 2.5 × 7.4 × 2.5 m (beam × length × height). Bow is +Y in the Blender authoring file; glTF Y-up export maps that to −Z forward in Godot.
