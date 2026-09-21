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


## How far the drawn surface rides above the slab tops at `water_z`, per water step
## (Taxonomy.WaterStep order). Not a depth: it only keeps the plane off the tiles. At 0 the plane
## is coplanar with the slab tops and the two fight for every pixel. Flooded must clear the
## shader's ±4 cm wave with margin, or the crests cut through and the slabs poke out.
const WATER_CLEARANCE_M := {
	Taxonomy.WaterStep.FLOODED: 0.12,
	Taxonomy.WaterStep.FALLING: 0.08,
	Taxonomy.WaterStep.MUD: 0.03,
	Taxonomy.WaterStep.DRY: 0.0,
}


## Y of the water plane as drawn: the authored level plus the step's clearance.
static func water_surface_m(step: Taxonomy.WaterStep, water_z: int) -> float:
	return water_height_m(water_z) + float(WATER_CLEARANCE_M.get(step, 0.0))


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
