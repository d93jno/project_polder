class_name PresentationCatalog
extends Object
## Art paths and cover tags. The stopping table lives in Taxonomy — this only names
## which mesh a player should see for a piece / material.
## Cell size is 2 m (assets terrace MANIFEST). Do not read BowlMap from here.

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
const MACHETE := CHARS + "char_kit_machete.glb"
const PISTOL := CHARS + "char_kit_pistol.glb"
const BOAT := VEHICLES + "veh_boat_camp.glb"

const WATER_MAT := SHADERS + "water.tres"
const CONE_MAT := SHADERS + "watch_cone.tres"
const SELECT_MAT := SHADERS + "selection.tres"
const FOG_MAT := SHADERS + "fog_ageing.tres"
const GHOST_MAT := SHADERS + "water_ghost.tres"

const FLOODED_BOWL := "res://scenes/p0/flooded_roof.tscn"
const DRY_BOWL := "res://scenes/p0/dry_street.tscn"


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


static func prop_scene_for_cover(material: Taxonomy.CoverMaterial) -> PackedScene:
	var path := ""
	match material:
		Taxonomy.CoverMaterial.CRATE:
			path = PROPS + "prop_crate_wood.glb"
		Taxonomy.CoverMaterial.PLANK:
			path = PROPS + "prop_plank_wood.glb"
		Taxonomy.CoverMaterial.MASONRY:
			path = PROPS + "prop_cover_masonry_corner.glb"
		_:
			return null
	return load(path) as PackedScene


static func kit_scene(piece_id: String) -> PackedScene:
	return load(TERRACE + piece_id + ".glb") as PackedScene


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
