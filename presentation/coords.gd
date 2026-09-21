class_name PresentationCoords
extends Object
## BowlMap Vector3i (x, y on the ground, z = level) to Godot metres (Y-up).
## Cell size is the terrace kit's 2 m. Level height is one storey (3 m).

const CELL_M := 2.0
const LEVEL_M := 3.0


static func world(cell: Vector3i) -> Vector3:
	return Vector3(cell.x * CELL_M, cell.z * LEVEL_M, cell.y * CELL_M)


static func world_ground(cell: Vector3i) -> Vector3:
	var p := world(cell)
	p.y += 0.02
	return p


static func cell_on_ground(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / CELL_M), roundi(point.z / CELL_M), roundi(point.y / LEVEL_M))


## Water plane Y from authored `water_z` (UI §3 / plan 2.2). No magic 2.4.
static func water_height_m(water_z: int) -> float:
	return float(water_z) * LEVEL_M


## Depth of the drawn surface over the floor at `water_z`, per water step (Taxonomy.WaterStep
## order). It follows the rules' own two classes (GDD 5.4): deep water hides a body, so Flooded
## stands above a 1.7 m head; chest-deep does not, so Falling stops short of the shoulders. Mud is
## a film, not a depth. Nothing on screen prints these numbers: depth is told by how the water
## meets a body and by whether the bottom shows (UI 3). A depth also keeps the plane off the slab
## tops; at 0 they are coplanar and fight per pixel.
const WATER_DEPTH_M := {
	Taxonomy.WaterStep.FLOODED: 2.0,
	Taxonomy.WaterStep.FALLING: 1.2,
	Taxonomy.WaterStep.MUD: 0.03,
	Taxonomy.WaterStep.DRY: 0.0,
}
## Body origin (feet) rides this far below the surface. Treading, a standing pose, shows head and
## shoulders. The swim clip is prone: its bones sit 0.57 to 1.06 m above the origin (measured), so a
## draft of 0.75 puts the spine at the surface with the back and head above it.
const TREAD_DRAFT_M := 1.3
const SWIM_DRAFT_M := 0.75


## Y of the water plane as drawn: the floor of level `water_z` plus the step's depth.
static func water_surface_m(step: Taxonomy.WaterStep, water_z: int) -> float:
	return water_height_m(water_z) + float(WATER_DEPTH_M.get(step, 0.0))


## Whether the drawn water covers this cell's floor. It must agree with `BowlMap.is_wet`, which is the
## rule (GDD 5.8); tests/invariants/test_water_agrees_with_drawing.gd checks. Decks are the exception: the
## picture puts a dock's deck on its own plane, so this geometry test does not consult the deck flag.
static func in_water(cell: Vector3i, step: Taxonomy.WaterStep, water_z: int) -> bool:
	if step != Taxonomy.WaterStep.FLOODED and step != Taxonomy.WaterStep.FALLING:
		return false
	return float(cell.z) * LEVEL_M < water_surface_m(step, water_z)


## Bodies float only in deep water. In chest-deep water they wade, feet on the bottom.
static func floats(cell: Vector3i, step: Taxonomy.WaterStep, water_z: int) -> bool:
	return step == Taxonomy.WaterStep.FLOODED and in_water(cell, step, water_z)


## Y of the plane bodies and overlays stand on for a level: the surface where a body would float,
## the floor otherwise. Picking casts against this, so what the player sees is what they click.
static func play_y(level_z: int, step: Taxonomy.WaterStep, water_z: int) -> float:
	var floor_y := float(level_z) * LEVEL_M
	if floats(Vector3i(0, 0, level_z), step, water_z):
		return water_surface_m(step, water_z)
	return floor_y


## The extract dock is a floating dock on guide piles, so it rides the water. `env_pier`'s deck top is
## 0.60 m above its origin, on oil-drum floats (a test measures the mesh against this). Its `pier_deck`
## node stands a freeboard clear of the water, and as built when there is none; its piles stay put.
const DOCK_DECK_TOP_M := 0.60
const DOCK_FREEBOARD_M := 0.30


## How far above its authored spot a dock is lifted to stay clear of the water at its level.
static func dock_lift_m(step: Taxonomy.WaterStep, water_z: int, level_z: int = 0) -> float:
	if not in_water(Vector3i(0, 0, level_z), step, water_z):
		return 0.0
	var native := float(level_z) * LEVEL_M + DOCK_DECK_TOP_M
	return maxf(0.0, water_surface_m(step, water_z) + DOCK_FREEBOARD_M - native)


## Y of the dock's walking surface for a level.
static func dock_deck_y(level_z: int, step: Taxonomy.WaterStep, water_z: int) -> float:
	return float(level_z) * LEVEL_M + DOCK_DECK_TOP_M + dock_lift_m(step, water_z, level_z)


## Where overlays for a cell sit: `world_ground`, lifted to the surface when the cell floats.
static func world_play(
	cell: Vector3i, step: Taxonomy.WaterStep, water_z: int, on_dock: bool = false
) -> Vector3:
	var p := world(cell)
	if on_dock:
		p.y = dock_deck_y(cell.z, step, water_z) + 0.02
	else:
		p.y = play_y(cell.z, step, water_z) + 0.02
	return p


## Where a unit's body origin goes: on the floor, or a draft below the surface if it floats.
## `prone` is the swim clip; any other pose treads water.
static func unit_origin(
	cell: Vector3i, step: Taxonomy.WaterStep, water_z: int, prone: bool = false, on_dock: bool = false
) -> Vector3:
	var p := world_play(cell, step, water_z, on_dock)
	if on_dock:
		return p ## feet on the boards
	if floats(cell, step, water_z):
		p.y -= SWIM_DRAFT_M if prone else TREAD_DRAFT_M
	return p


## Facing is (±1,0,0) or (0,±1,0) on the data plane. Model rest faces Godot −Z.
static func yaw_degrees(facing: Vector3i) -> float:
	if facing.x > 0:
		return -90.0
	if facing.x < 0:
		return 90.0
	if facing.y > 0:
		return 180.0
	return 0.0


static func cardinal_toward(from_cell: Vector3i, to_cell: Vector3i) -> Vector3i:
	var dx := to_cell.x - from_cell.x
	var dy := to_cell.y - from_cell.y
	if absi(dx) >= absi(dy):
		return Vector3i(signi(dx), 0, 0) if dx != 0 else Vector3i(1, 0, 0)
	return Vector3i(0, signi(dy), 0)
