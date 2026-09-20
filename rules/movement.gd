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
	## INTERIOR on masonry/metal is a room volume: standable, still stops shots through it.
	if not map.has_cell(cell):
		return false
	var c: Cell = map.get_cell(cell)
	match c.material:
		Taxonomy.CoverMaterial.MASONRY, Taxonomy.CoverMaterial.METAL:
			return c.has_flag(Taxonomy.CellFlags.INTERIOR)
		_:
			return true


## Can `mover` stand here? Walkable material and no *standing* body of anyone else on it.
## Occupancy comes from `state.units`, not `Cell.occupant`: the map is shared between a state and
## its copies, so the per-cell field cannot be the truth for one state (plan §1.5.1). Downed
## bodies leave the tile clear, as `apply_damage` already does (GDD §5.9 working default).
static func is_free(map: BowlMap, state: CombatState, cell: Vector3i, mover: Unit) -> bool:
	if not is_walkable(map, cell):
		return false
	for other in state.units.values():
		if other.id != mover.id and other.is_active() and other.cell == cell:
			return false
	return true


## Every tile `unit` can stand on with `budget` AP, its own tile included (staying put is a move
## of cost 0). The same flood `path` runs, bounded instead of aimed. `budget` defaults to the AP
## the unit holds; it is a parameter because a Pinned unit's AP is zeroed by `apply_pin`, while
## GDD §5.5 says Pinned must not zero the AP for the "in the open" test — the caller decides
## what a pinned unit's budget is (plan §1.6).
static func reachable(
	map: BowlMap,
	state: CombatState,
	unit: Unit,
	budget: int = -1,
) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if not is_walkable(map, unit.cell):
		return out
	var limit: int = unit.ap if budget < 0 else budget
	var flood := _flood(map, state, unit, limit)
	for cell in (flood["cost"] as Dictionary).keys():
		out.append(cell)
	return out


## Cost, from every tile, of the cheapest walk into any of `targets` (the targets cost 0). The flood
## `path` runs, run backwards: relaxing tile `t` from settled neighbour `n` costs entering `n` from
## `t`. Tiles that cannot reach a target are absent. Used for "closer to cover" (GDD §5.5).
static func cost_to_nearest(
	map: BowlMap,
	state: CombatState,
	unit: Unit,
	targets: Array[Vector3i],
) -> Dictionary:
	var dist: Dictionary = {} ## Vector3i -> int
	var frontier: Array[Vector3i] = []
	for t in targets:
		dist[t] = 0
		frontier.append(t)
	while not frontier.is_empty():
		var settled: Vector3i = _pop_min(frontier, dist)
		for t in _neighbors(settled):
			if not is_free(map, state, t, unit) and t != unit.cell:
				continue
			var cost: int = (dist[settled] as int) + move_cost(map, settled, unit, t)
			if not dist.has(t) or cost < (dist[t] as int):
				dist[t] = cost
				if t not in frontier:
					frontier.append(t)
	return dist


## One traversal for `path` and `reachable`, so they cannot disagree. `max_cost < 0` is unbounded;
## `stop_at` (when given) ends the search as soon as that tile is settled.
static func _flood(
	map: BowlMap,
	state: CombatState,
	unit: Unit,
	max_cost: int = -1,
	stop_at: Variant = null,
) -> Dictionary:
	var came_from: Dictionary = {} ## Vector3i -> Vector3i
	var cost_so_far: Dictionary = {} ## Vector3i -> int
	var frontier: Array[Vector3i] = [unit.cell]
	cost_so_far[unit.cell] = 0

	while not frontier.is_empty():
		var current: Vector3i = _pop_min(frontier, cost_so_far)
		if stop_at != null and current == stop_at:
			break
		for next_cell in _neighbors(current):
			if not is_free(map, state, next_cell, unit):
				continue
			var step := move_cost(map, next_cell, unit, current)
			var new_cost: int = (cost_so_far[current] as int) + step
			if max_cost >= 0 and new_cost > max_cost:
				continue
			if not cost_so_far.has(next_cell) or new_cost < (cost_so_far[next_cell] as int):
				cost_so_far[next_cell] = new_cost
				came_from[next_cell] = current
				if next_cell not in frontier:
					frontier.append(next_cell)
	return {"from": came_from, "cost": cost_so_far}


static func path(map: BowlMap, state: CombatState, unit: Unit, to: Vector3i) -> MovePath:
	var result := MovePath.new()
	if not is_walkable(map, unit.cell) or not is_free(map, state, to, unit):
		return result

	var flood := _flood(map, state, unit, -1, to)
	var came_from: Dictionary = flood["from"]
	var cost_so_far: Dictionary = flood["cost"]

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
