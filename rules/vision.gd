class_name Vision
extends Object
## What a faction can see. One query, one walk — sight_line, not a weapon (plan 04 §4.1).
## Pure over map and state; holds no knowledge of its own.


## Any active unit of `faction` has a clean sight line to `cell`.
static func sees(
	map: BowlMap,
	state: CombatState,
	faction: Taxonomy.Faction,
	cell: Vector3i,
) -> bool:
	return not seers_of(map, state, faction, cell).is_empty()


## Active units of `faction` with a clean sight line to `cell`.
static func seers_of(
	map: BowlMap,
	state: CombatState,
	faction: Taxonomy.Faction,
	cell: Vector3i,
) -> Array[Unit]:
	var out: Array[Unit] = []
	for unit in state.units_of_faction(faction):
		if not unit.is_active():
			continue
		if Los.sight_line(map, unit.cell, cell).clean:
			out.append(unit)
	return out


## Cells one unit can currently see. Keys are Vector3i; value is always true.
## Peel input in 4.2. Empty when the unit is not active.
static func live_cells(map: BowlMap, state: CombatState, unit: Unit) -> Dictionary:
	var out: Dictionary = {}
	if unit == null:
		return out
	var body: Unit = state.get_unit(unit.id)
	if body == null or not body.is_active():
		return out
	for coord in map.cells.keys():
		var cell: Vector3i = coord
		if Los.sight_line(map, body.cell, cell).clean:
			out[cell] = true
	return out
