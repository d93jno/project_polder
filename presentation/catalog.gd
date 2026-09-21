class_name PresentationCatalog
extends Object
## Art paths and cover tags. The stopping table lives in Taxonomy — this only names
## which mesh a player should see for a piece / material.
## Cell size is 2 m (assets terrace MANIFEST). Do not read BowlMap from here except
## piece_for_cell, which picks a mesh for one authored cell.

const CELL_M := 2.0

const TERRACE := "res://assets/env/kits/terrace/"
const HERO := "res://assets/env/hero/"
const PROPS := "res://assets/props/"
const VEHICLES := "res://assets/vehicles/"
const CHARS := "res://assets/chars/humanoid/"
const SHADERS := "res://assets/shaders/"
const UI_ICONS := "res://assets/ui/icons/"
const UI_THEME := "res://assets/ui/theme/"
const UI_HUD := "res://assets/ui/hud/"

const HUMANOID := CHARS + "char_humanoid.glb"
const HUMANOID_DRIFTER_A := CHARS + "char_humanoid_drifter_a.glb"
const HUMANOID_DRIFTER_B := CHARS + "char_humanoid_drifter_b.glb"
const MACHETE := CHARS + "char_kit_machete.glb"
const PISTOL := CHARS + "char_kit_pistol.glb"
const BOAT := VEHICLES + "veh_boat_camp.glb"


## Salvage kit for Drifters (A/B by id). Everyone else uses the unclassed basin body.
static func humanoid_for(faction: Taxonomy.Faction, unit_id: int) -> String:
	if faction == Taxonomy.Faction.DRIFTER:
		return HUMANOID_DRIFTER_A if (unit_id % 2) == 0 else HUMANOID_DRIFTER_B
	return HUMANOID

const WATER_MAT := SHADERS + "water.tres"
const CONE_MAT := SHADERS + "watch_cone.tres"
const SELECT_MAT := SHADERS + "selection.tres"
const FOG_MAT := SHADERS + "fog_ageing.tres"
const GHOST_MAT := SHADERS + "water_ghost.tres"

const FLOODED_BOWL := "res://scenes/p0/flooded_roof.tscn"
const DRY_BOWL := "res://scenes/p0/dry_street.tscn"

const SLAB_IDS := [
	"env_street_slab_a",
	"env_street_slab_b",
	"env_street_slab_c",
]
const ROOF_DECK_ID := "env_roof_deck_a"

## Tall quay for masonry runs (2.4 m). Isolated cells keep the corner prop.
const MASONRY_RUN_ID := "env_canal_wall_tall"
const MASONRY_CORNER_ID := "prop_cover_masonry_corner"
const PLANK_ID := "prop_plank_wood"
const CRATE_ID := "prop_crate_wood"
const METAL_ID := "env_shanty_water_tank"

## Cell footprint of multi-cell kit pieces: Vector3i(cells_x, cells_y, levels).
## Missing ids default to 1×1×1 (single-cell props / slabs). Yaw 90/270 swaps x/y.
const FOOTPRINTS := {
	"env_house_2storey_a": Vector3i(2, 2, 1),
	"env_house_2storey_b": Vector3i(2, 2, 1),
	"env_house_2storey_c": Vector3i(2, 2, 1),
	"env_house_2storey_d": Vector3i(2, 2, 1),
	"env_roof_deck_a": Vector3i(2, 2, 1),
	"env_roof_deck_b": Vector3i(2, 2, 1),
	"env_floor_interior_1": Vector3i(2, 2, 1),
	"env_floor_interior_2": Vector3i(2, 2, 1),
	"env_pump_house": Vector3i(2, 2, 1),
	"env_sluice_gauge": Vector3i(2, 2, 1),
	"env_stair": Vector3i(1, 1, 1),
	"env_ladder": Vector3i(1, 1, 1),
	"env_hatch": Vector3i(1, 1, 1),
	"env_pier": Vector3i(1, 3, 1),
}


## Kit pieces that ride the water on guide piles (see PresentationCoords.DOCK_*).
const RIDES_WATER := ["env_pier"]


## Cells under a piece that rides the water, as a set. Bodies on them stand on the deck.
static func dock_cells(stamps: Array) -> Dictionary:
	var out: Dictionary = {}
	for s in stamps:
		var stamp: Stamp = s
		if stamp.piece_id in RIDES_WATER:
			for cell in stamp_cells(stamp):
				out[cell] = true
	return out


## Cover class of a kit/prop id, or -1 if the piece is not cover (rail, lamp, slab).
## Values are Taxonomy.CoverMaterial. Keep in lockstep with assets/*/MANIFEST.md.
static func cover_of(piece_id: String) -> int:
	match piece_id:
		"prop_crate_wood", "prop_dropped_crate", "env_shanty_pallet_wall", "env_shanty_plot_box", "env_pier":
			return Taxonomy.CoverMaterial.CRATE
		"prop_plank_wood":
			return Taxonomy.CoverMaterial.PLANK
		"prop_cover_masonry_corner", "env_canal_wall", "env_canal_wall_tall", \
		"env_levee_straight", "env_levee_inner_corner", "env_levee_outer_corner", "env_levee_slope", \
		"env_house_2storey_a", "env_house_2storey_b", "env_house_2storey_c", "env_house_2storey_d", \
		"env_stair", "env_pump_house", "env_sluice_gauge":
			return Taxonomy.CoverMaterial.MASONRY
		"env_shanty_water_tank":
			return Taxonomy.CoverMaterial.METAL
		_:
			return -1


## Piece id + yaw for one BowlMap cell. Empty id means no art — draw a magenta marker.
static func piece_for_cell(map: BowlMap, coord: Vector3i) -> Dictionary:
	if not map.has_cell(coord):
		return {"id": "", "yaw": 0.0}
	var material: Taxonomy.CoverMaterial = map.get_cell(coord).material
	match material:
		Taxonomy.CoverMaterial.AIR:
			var cell: Cell = map.get_cell(coord)
			if cell != null and cell.has_flag(Taxonomy.CellFlags.DECK):
				return {"id": ROOF_DECK_ID, "yaw": 0.0}
			var slab: String = SLAB_IDS[absi(coord.x + coord.y * 3) % SLAB_IDS.size()]
			return {"id": slab, "yaw": 0.0}
		Taxonomy.CoverMaterial.PLANK:
			return {"id": PLANK_ID, "yaw": 0.0}
		Taxonomy.CoverMaterial.CRATE:
			return {"id": CRATE_ID, "yaw": 0.0}
		Taxonomy.CoverMaterial.METAL:
			return {"id": METAL_ID, "yaw": 0.0}
		Taxonomy.CoverMaterial.MASONRY:
			if _masonry_has_neighbor(map, coord):
				return {"id": MASONRY_RUN_ID, "yaw": _masonry_run_yaw(map, coord)}
			return {"id": MASONRY_CORNER_ID, "yaw": 0.0}
		_:
			return {"id": "", "yaw": 0.0}


static func scene_for_piece(piece_id: String) -> PackedScene:
	if piece_id.is_empty():
		return null
	var path := path_for_piece(piece_id)
	if path.is_empty():
		return null
	return load(path) as PackedScene


static func path_for_piece(piece_id: String) -> String:
	if piece_id.begins_with("prop_"):
		return PROPS + piece_id + ".glb"
	if piece_id.begins_with("env_ridge"):
		return HERO + piece_id + ".glb"
	if piece_id.begins_with("env_"):
		return TERRACE + piece_id + ".glb"
	if piece_id.begins_with("veh_"):
		return VEHICLES + piece_id + ".glb"
	return ""


## CoverMaterial → default prop/kit scene (isolated cell, no run context).
static func prop_scene_for_cover(material: Taxonomy.CoverMaterial) -> PackedScene:
	var id := ""
	match material:
		Taxonomy.CoverMaterial.CRATE:
			id = CRATE_ID
		Taxonomy.CoverMaterial.PLANK:
			id = PLANK_ID
		Taxonomy.CoverMaterial.MASONRY:
			id = MASONRY_CORNER_ID
		Taxonomy.CoverMaterial.METAL:
			id = METAL_ID
		_:
			return null
	return scene_for_piece(id)


static func kit_scene(piece_id: String) -> PackedScene:
	return scene_for_piece(piece_id)


## Footprint in cells (x, y) and levels (z), with yaw applied (90° swaps ground axes).
static func footprint_size(piece_id: String, yaw_deg: float = 0.0) -> Vector3i:
	var base: Vector3i = FOOTPRINTS.get(piece_id, Vector3i(1, 1, 1))
	var quarter: int = posmod(int(round(yaw_deg / 90.0)), 4)
	if quarter == 1 or quarter == 3:
		return Vector3i(base.y, base.x, base.z)
	return base


static func is_single_cell_piece(piece_id: String) -> bool:
	var fp: Vector3i = footprint_size(piece_id)
	return fp.x * fp.y * fp.z <= 1


## Every cell a stamp claims (data coords), inclusive of origin.
static func stamp_cells(stamp: Stamp) -> Array[Vector3i]:
	var fp: Vector3i = footprint_size(stamp.piece_id, stamp.yaw)
	var cells: Array[Vector3i] = []
	for dx in fp.x:
		for dy in fp.y:
			for dz in fp.z:
				cells.append(stamp.origin + Vector3i(dx, dy, dz))
	return cells


## World position for a stamp mesh. Kit origins sit at the footprint centre (MANIFEST).
static func stamp_world_origin(stamp: Stamp) -> Vector3:
	var fp: Vector3i = footprint_size(stamp.piece_id, stamp.yaw)
	var corner := PresentationCoords.world(stamp.origin)
	var mid := Vector3(
		float(fp.x - 1) * PresentationCoords.CELL_M * 0.5,
		float(fp.z - 1) * PresentationCoords.LEVEL_M * 0.5,
		float(fp.y - 1) * PresentationCoords.CELL_M * 0.5
	)
	return corner + mid


## Shader `step` uniform. Enum order matches Taxonomy.WaterStep.
static func water_step_uniform(step: Taxonomy.WaterStep) -> int:
	return int(step)


## Show N of 4 jerrycans on the camp boat (fuel is a count, not a bar).
static func set_boat_fuel(boat: Node, cans: int) -> void:
	var n := clampi(cans, 0, 4)
	for i in 4:
		var node := boat.find_child("fuel_can_%02d" % (i + 1), true, false)
		if node:
			node.visible = i < n


static func _masonry_has_neighbor(map: BowlMap, coord: Vector3i) -> bool:
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
		if _is_masonry(map, coord + d):
			return true
	return false


## Canal wall mesh runs along local X. A data-y run (Godot Z) needs 90° yaw.
static func _masonry_run_yaw(map: BowlMap, coord: Vector3i) -> float:
	var along_y := _is_masonry(map, coord + Vector3i(0, 1, 0)) or _is_masonry(map, coord + Vector3i(0, -1, 0))
	var along_x := _is_masonry(map, coord + Vector3i(1, 0, 0)) or _is_masonry(map, coord + Vector3i(-1, 0, 0))
	if along_y and not along_x:
		return 90.0
	return 0.0


static func _is_masonry(map: BowlMap, coord: Vector3i) -> bool:
	return map.has_cell(coord) and map.get_cell(coord).material == Taxonomy.CoverMaterial.MASONRY
