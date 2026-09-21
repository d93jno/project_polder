class_name Cones
extends Object
## Watch volumes over LOS (GDD §5.2, UI §4.4).


static func cone(
	map: BowlMap,
	watcher_cell: Vector3i,
	facing: Vector3i,
	weapon: Taxonomy.WeaponClass,
) -> Array[Vector3i]:
	var face := _normalize_facing(facing)
	var length := RulesConstants.cone_length(weapon)
	var out: Array[Vector3i] = []
	for dx in range(-length, length + 1):
		for dy in range(-length, length + 1):
			for dz in range(-length, length + 1):
				if dx == 0 and dy == 0 and dz == 0:
					continue
				var offset := Vector3i(dx, dy, dz)
				if maxi(absi(dx), maxi(absi(dy), absi(dz))) > length:
					continue
				if not _in_wedge(offset, face):
					continue
				var cell := watcher_cell + offset
				if Los.line_of_sight(map, watcher_cell, cell, weapon, true).clean:
					out.append(cell)
	return out


## Full volume plus whether viewers of viewer_faction can see the watcher's tile.
static func watch_cone(
	map: BowlMap,
	state: CombatState,
	watcher: Unit,
	facing: Vector3i,
	viewer_faction: Taxonomy.Faction,
) -> ConeResult:
	var result := ConeResult.new()
	result.cells = cone(map, watcher.cell, facing, watcher.weapon)
	result.apex_known = apex_known(map, state, watcher.cell, viewer_faction)
	return result


static func apex_known(
	map: BowlMap,
	state: CombatState,
	watcher_cell: Vector3i,
	viewer_faction: Taxonomy.Faction,
) -> bool:
	return Vision.sees(map, state, viewer_faction, watcher_cell)


## Live Watches covering `cell`. With `hostile_to` set (a Taxonomy.Faction), only Watches held by
## factions hostile to it count — break clause 3 needs hostile long cones only (plan §1.5.1).
## Left unset it counts every live Watch, which is the UI §4.4 overlay read.
static func cone_stack(
	map: BowlMap,
	state: CombatState,
	cell: Vector3i,
	hostile_to: Variant = null,
) -> ConeStack:
	var stack := ConeStack.new()
	for watch in state.watches:
		var live: LiveWatch = watch
		if live.spent:
			continue
		var watcher: Unit = state.get_unit(live.unit_id)
		if watcher == null:
			continue
		if hostile_to != null and not CombatState.is_hostile(hostile_to, watcher.faction):
			continue
		var volume := cone(map, watcher.cell, live.facing, watcher.weapon)
		if cell in volume:
			stack.count += 1
			stack.classes.append(watcher.weapon)
	return stack


static func _normalize_facing(facing: Vector3i) -> Vector3i:
	## Ground-plane cardinal only.
	if absi(facing.x) >= absi(facing.y):
		if facing.x == 0:
			return Vector3i(1, 0, 0)
		return Vector3i(signi(facing.x), 0, 0)
	return Vector3i(0, signi(facing.y), 0)


## 90° forward wedge on the ground plane; vertical is allowed within range.
static func _in_wedge(offset: Vector3i, facing: Vector3i) -> bool:
	var forward := offset.x * facing.x + offset.y * facing.y
	if forward <= 0:
		return false
	var lateral := absi(offset.x * facing.y - offset.y * facing.x)
	return lateral <= forward
