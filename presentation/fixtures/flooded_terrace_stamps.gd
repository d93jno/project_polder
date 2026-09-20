extends Object
## Draw-table for the flooded terrace (plan 3.3). Presentation-side — rules fixture
## owns cells; this owns stamps only. Preload (no class_name).

const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")


static func stamps() -> Array:
	var a: Vector3i = FloodedTerrace.HOUSE_A
	var b: Vector3i = FloodedTerrace.HOUSE_B
	return [
		Stamp.new("env_house_2storey_a", a, 0.0),
		Stamp.new("env_house_2storey_b", b, 0.0),
		Stamp.new("env_floor_interior_1", a, 0.0),
		Stamp.new("env_floor_interior_1", b, 0.0),
		Stamp.new("env_floor_interior_2", Vector3i(a.x, a.y, 1), 0.0),
		Stamp.new("env_floor_interior_2", Vector3i(b.x, b.y, 1), 0.0),
		Stamp.new("env_roof_deck_a", FloodedTerrace.ROOF_A, 0.0),
		Stamp.new("env_roof_deck_b", Vector3i(6, 5, 2), 0.0),
		Stamp.new("env_shanty_tarp", FloodedTerrace.ROOF_B, 0.0),
		Stamp.new("env_stair", FloodedTerrace.STAIR, 0.0),
		Stamp.new("env_ladder", FloodedTerrace.LADDER, 0.0),
		## Pier along +X on the near bank (yaw 90 swaps the 1×3 footprint).
		Stamp.new("env_pier", FloodedTerrace.PIER_ORIGIN, 90.0),
	]


## Canal street columns — no stacked walkable levels today; reserved if water columns appear.
static func swim_columns() -> Array:
	return []
