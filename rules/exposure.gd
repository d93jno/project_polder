class_name ExposureQuery
extends Object
## Exposure is LOS run backwards (UI §17 / plan §1.3).
## Count is every gun with a clean weapon line. Sources are what this unit can
## locate: Live in its merged knowledge (own sight + earshot), not a second
## weapon LOS — a plank does not hide a shooter you can see over (plan 04 §4.3).


static func exposure(map: BowlMap, state: CombatState, unit: Unit) -> Exposure:
	var result := Exposure.new()
	var attackers := state.attackers_of(map, unit)
	result.count = attackers.size()

	for hostile in attackers:
		if (
			state.knowledge != null
			and state.knowledge.merged_sight(state, unit, hostile.cell) == Knowledge.CellSight.LIVE
		):
			result.sources.append(hostile.cell)

	if result.count > 0:
		result.state = Exposure.State.EXPOSED
	elif _no_hide_at(map, unit.cell):
		result.state = Exposure.State.NO_HIDE
	else:
		result.state = Exposure.State.HIDDEN

	return result


## Falling, or open Dry (no shelter / interior). Dry ground above the water reads as Dry: there is
## no dive up there (GDD §5.8). UI §4.2.
static func _no_hide_at(map: BowlMap, cell: Vector3i) -> bool:
	match map.step_at(cell):
		Taxonomy.WaterStep.FALLING:
			return true
		Taxonomy.WaterStep.DRY:
			var c: Cell = map.get_cell(cell)
			if c == null:
				return true
			if c.has_flag(Taxonomy.CellFlags.SHELTER) or c.has_flag(Taxonomy.CellFlags.INTERIOR):
				return false
			return true
		_:
			return false
