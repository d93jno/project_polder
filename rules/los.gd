class_name Los
extends Object
## Grid line-of-sight. No physics raycasts — ever (UI §17).
##
## Corner tie-break (§7.1): **strict**. A cell is on the line if the
## center-to-center segment intersects its closed unit cube. A line through a
## shared corner therefore visits every neighbour that touches that corner —
## blocked if any of them stops the weapon.

const _AXIS_EPS := 1e-12


static func line3d(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	## Supercover from a to b (inclusive), ordered by distance from a.
	if a == b:
		var single: Array[Vector3i] = [a]
		return single

	var start := Vector3(a) + Vector3(0.5, 0.5, 0.5)
	var end := Vector3(b) + Vector3(0.5, 0.5, 0.5)
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var hi := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))

	var hit: Array[Vector3i] = []
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var cell := Vector3i(x, y, z)
				if _segment_intersects_cell(start, end, cell):
					hit.append(cell)

	hit.sort_custom(func(p: Vector3i, q: Vector3i) -> bool:
		var dp := start.distance_squared_to(Vector3(p) + Vector3(0.5, 0.5, 0.5))
		var dq := start.distance_squared_to(Vector3(q) + Vector3(0.5, 0.5, 0.5))
		if dp == dq:
			## Stable tie-break so blocker naming is deterministic.
			if p.x != q.x:
				return p.x < q.x
			if p.y != q.y:
				return p.y < q.y
			return p.z < q.z
		return dp < dq
	)
	return hit


static func line_of_sight(
	map: BowlMap,
	from: Vector3i,
	to: Vector3i,
	weapon: Taxonomy.WeaponClass,
) -> LosResult:
	if from == to:
		return LosResult.ok()

	var hide_from := _body_hide_material(map, from)
	if hide_from != -1:
		return LosResult.blocked(hide_from as Taxonomy.CoverMaterial, from)

	var hide_to := _body_hide_material(map, to)
	if hide_to != -1:
		return LosResult.blocked(hide_to as Taxonomy.CoverMaterial, to)

	var path := line3d(from, to)
	for cell in path:
		if cell == from or cell == to:
			continue
		var material := _material_at(map, cell)
		if Taxonomy.stops(material, weapon):
			return LosResult.blocked(material, cell)

	return LosResult.ok()


## Deep water and smoke hide a body — no line to or from (GDD §5.4).
## Chest-deep water does not, including under Falling (GDD §5.8).
## Returns CoverMaterial as int, or -1 if the body is not hidden.
static func _body_hide_material(map: BowlMap, coord: Vector3i) -> int:
	var material := _material_at(map, coord)
	match material:
		Taxonomy.CoverMaterial.WATER_DEEP, Taxonomy.CoverMaterial.SMOKE:
			return material
		_:
			return -1


static func _material_at(map: BowlMap, coord: Vector3i) -> Taxonomy.CoverMaterial:
	var cell: Cell = map.get_cell(coord)
	if cell == null:
		return Taxonomy.CoverMaterial.AIR
	return cell.material


## Closed unit-cube intersection (slab). Point contact counts — that is strict.
static func _segment_intersects_cell(p0: Vector3, p1: Vector3, cell: Vector3i) -> bool:
	var mn := Vector3(cell)
	var mx := Vector3(cell) + Vector3.ONE
	var d := p1 - p0
	var t0 := 0.0
	var t1 := 1.0
	for axis in range(3):
		var origin: float = p0[axis]
		var delta: float = d[axis]
		var near_b: float = mn[axis]
		var far_b: float = mx[axis]
		if absf(delta) <= _AXIS_EPS:
			if origin < near_b or origin > far_b:
				return false
			continue
		var inv := 1.0 / delta
		var t_near := (near_b - origin) * inv
		var t_far := (far_b - origin) * inv
		if t_near > t_far:
			var tmp := t_near
			t_near = t_far
			t_far = tmp
		t0 = maxf(t0, t_near)
		t1 = minf(t1, t_far)
		if t0 > t1:
			return false
	return true
