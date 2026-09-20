class_name Movement
extends Object
## Move costs, pathfinding, and reserve marks (GDD §5.3, UI §4.1).


static func move_cost(
	map: BowlMap,
	cell: Vector3i,
	unit: Unit,
	from_cell: Vector3i = Vector3i(0, 0, -999999),
) -> int:
	## Cost to *enter* cell. Pass from_cell to apply climb/dive surcharge.
	var cost := RulesConstants.step_move_cost(map.water_step)
	if from_cell.z != -999999 and from_cell.z != cell.z:
		cost += RulesConstants.MOVE_COST_VERTICAL_SURCHARGE
	return cost


static func is_walkable(map: BowlMap, cell: Vector3i) -> bool:
	## Sparse authorship: only placed cells are walkable. Solid walls are not.
	if not map.has_cell(cell):
		return false
	var material := map.get_cell(cell).material
	match material:
		Taxonomy.CoverMaterial.MASONRY, Taxonomy.CoverMaterial.METAL:
			return false
		_:
			return true


static func path(map: BowlMap, state: CombatState, unit: Unit, to: Vector3i) -> MovePath:
	var result := MovePath.new()
	if not is_walkable(map, unit.cell) or not is_walkable(map, to):
		return result

	var came_from: Dictionary = {} ## Vector3i -> Vector3i
	var cost_so_far: Dictionary = {} ## Vector3i -> int
	var frontier: Array[Vector3i] = [unit.cell]
	cost_so_far[unit.cell] = 0

	while not frontier.is_empty():
		var current: Vector3i = _pop_min(frontier, cost_so_far)
		if current == to:
			break
		for next_cell in _neighbors(current):
			if not is_walkable(map, next_cell):
				continue
			var step := move_cost(map, next_cell, unit, current)
			var new_cost: int = (cost_so_far[current] as int) + step
			if not cost_so_far.has(next_cell) or new_cost < (cost_so_far[next_cell] as int):
				cost_so_far[next_cell] = new_cost
				came_from[next_cell] = current
				if next_cell not in frontier:
					frontier.append(next_cell)

	if not cost_so_far.has(to):
		return result

	## Reconstruct start → to.
	var rev: Array[Vector3i] = []
	var walk := to
	rev.append(walk)
	while walk != unit.cell:
		walk = came_from[walk]
		rev.append(walk)
	rev.reverse()

	result.reachable = true
	result.cells = rev
	for i in range(result.cells.size()):
		if i == 0:
			result.cost_per_cell.append(0)
		else:
			result.cost_per_cell.append(move_cost(map, result.cells[i], unit, result.cells[i - 1]))
		var probe := unit.duplicate_at(result.cells[i])
		result.exposure_per_cell.append(ExposureQuery.exposure(map, state, probe))

	result.total_cost = 0
	for c in result.cost_per_cell:
		result.total_cost += c

	result.watches_crossed = _watches_crossed(map, state, unit, result.cells)
	result.shot_reserve_at = _reserve_at(
		result.cost_per_cell, unit.ap, RulesConstants.shot_cost(unit.weapon)
	)
	result.watch_reserve_at = _reserve_at(
		result.cost_per_cell, unit.ap, RulesConstants.WATCH_COST
	)
	return result


## Last index where remaining AP after arrival still covers action_cost; -1 if none.
static func _reserve_at(cost_per_cell: Array[int], unit_ap: int, action_cost: int) -> int:
	var spent := 0
	var last := -1
	for i in range(cost_per_cell.size()):
		spent += cost_per_cell[i]
		if unit_ap - spent >= action_cost:
			last = i
		else:
			break
	return last


static func _watches_crossed(
	map: BowlMap,
	state: CombatState,
	unit: Unit,
	cells: Array[Vector3i],
) -> Array:
	var crossings: Array = []
	if cells.size() < 2:
		return crossings

	var enemy_volumes: Array = [] ## {id, weapon, cells}
	for watch in state.watches:
		var live: LiveWatch = watch
		if live.spent:
			continue
		var watcher: Unit = state.get_unit(live.unit_id)
		if watcher == null:
			continue
		if not CombatState.is_hostile(unit.faction, watcher.faction):
			continue
		enemy_volumes.append({
			"id": watcher.id,
			"weapon": watcher.weapon,
			"cells": Cones.cone(map, watcher.cell, live.facing, watcher.weapon),
		})

	for i in range(1, cells.size()):
		var prev: Vector3i = cells[i - 1]
		var here: Vector3i = cells[i]
		for vol in enemy_volumes:
			var volume: Array = vol["cells"]
			if here in volume and prev not in volume:
				crossings.append(
					WatchCrossing.new(here, i, vol["id"], vol["weapon"])
				)
	return crossings


static func _neighbors(cell: Vector3i) -> Array[Vector3i]:
	return [
		cell + Vector3i(1, 0, 0),
		cell + Vector3i(-1, 0, 0),
		cell + Vector3i(0, 1, 0),
		cell + Vector3i(0, -1, 0),
		cell + Vector3i(0, 0, 1),
		cell + Vector3i(0, 0, -1),
	]


static func _pop_min(frontier: Array[Vector3i], cost_so_far: Dictionary) -> Vector3i:
	var best_i := 0
	var best_cost: int = cost_so_far[frontier[0]]
	for i in range(1, frontier.size()):
		var c: int = cost_so_far[frontier[i]]
		if c < best_cost:
			best_cost = c
			best_i = i
	var cell: Vector3i = frontier[best_i]
	frontier.remove_at(best_i)
	return cell
