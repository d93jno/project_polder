extends Object
## Mouse picking against drawn unit bodies. Input-only, like the ground-plane pick in
## fight_view: `rules/` never sees it and LOS never consults it.
## Preload this script (no class_name) so headless tests do not need a global-class refresh.
##
## Why it exists: the camera looks down at ~40°, so a ray through an enemy's torso meets the
## ground plane 1-2 m *behind* their feet. Picking only the ground made the body itself
## click the tile behind it (a move instead of a shot). A body is a standing volume.

## Slightly generous next to the ~0.35 m mesh so a click near the silhouette still lands.
const BODY_RADIUS_M := 0.6
const BODY_HEIGHT_M := 1.9
## A bleeding unit is lying down (`downed` clip): low and wide.
const DOWNED_RADIUS_M := 0.9
const DOWNED_HEIGHT_M := 0.7


## Distance along the ray to a vertical cylinder standing on `foot`, or -1.0 on a miss.
## Side wall and top cap; the camera is always above, so no bottom cap.
static func ray_vs_cylinder(
	origin: Vector3, dir: Vector3, foot: Vector3, radius: float, height: float
) -> float:
	var ox := origin.x - foot.x
	var oz := origin.z - foot.z
	var top := foot.y + height
	var best := -1.0
	var a := dir.x * dir.x + dir.z * dir.z
	if a > 1e-9:
		var b := ox * dir.x + oz * dir.z
		var c := ox * ox + oz * oz - radius * radius
		var disc := b * b - a * c
		if disc >= 0.0:
			var root: float = sqrt(disc)
			for t: float in [(-b - root) / a, (-b + root) / a]:
				if t < 0.0:
					continue
				var y: float = origin.y + dir.y * t
				if y >= foot.y and y <= top:
					best = t
					break
	if absf(dir.y) > 1e-9:
		var t_top := (top - origin.y) / dir.y
		if t_top >= 0.0 and (best < 0.0 or t_top < best):
			var hx := ox + dir.x * t_top
			var hz := oz + dir.z * t_top
			if hx * hx + hz * hz <= radius * radius:
				best = t_top
	return best


## The floor cell under a ray, cast against each open level's play plane from the top down.
## `plane_y` maps a level to the Y its cells are drawn at (the water surface where a body floats).
## The first level with an authored cell at that plane's hit wins. Returns {"cell", "t"} or {}.
## Each level is tested at its own hit: reusing the top plane's x/y for the lower floors shifts a
## street click by the height of the cutaway.
static func cell_under_ray(
	map: BowlMap, cutaway_z: int, origin: Vector3, dir: Vector3, plane_y: Callable
) -> Dictionary:
	if absf(dir.y) < 0.0001:
		return {}
	for z in range(cutaway_z, -1, -1):
		var t := (float(plane_y.call(z)) - origin.y) / dir.y
		if t < 0.0:
			continue
		var hit := origin + dir * t
		var cell := Vector3i(
			roundi(hit.x / PresentationCoords.CELL_M), roundi(hit.z / PresentationCoords.CELL_M), z
		)
		if map.has_cell(cell):
			return {"cell": cell, "t": t}
	return {}


## Nearest drawn body under the ray: {"unit": Unit, "t": float}, or {} if none.
## Same "is there a body here" test as fight_view._unit_at, plus the cutaway: a unit on a
## floor above the cutaway level is hidden and must not be clickable.
static func body_under_ray(
	state: CombatState, cutaway_z: int, origin: Vector3, dir: Vector3, feet_of: Callable = Callable()
) -> Dictionary:
	var best: Dictionary = {}
	var best_t := INF
	for u in state.all_units():
		if u.extracted or u.dead or u.cell.z > cutaway_z:
			continue
		var downed: bool = u.bleeding
		var t := ray_vs_cylinder(
			origin,
			dir,
			feet_of.call(u) if feet_of.is_valid() else PresentationCoords.world_ground(u.cell),
			DOWNED_RADIUS_M if downed else BODY_RADIUS_M,
			DOWNED_HEIGHT_M if downed else BODY_HEIGHT_M
		)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = {"unit": u, "t": t}
	return best
