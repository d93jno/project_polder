class_name Occupants
extends Object
## Authored Cell.occupant ids become Units at bowl load (plan 04 §7.6 / UI §17).
## Fog alone decides whether they are drawn. Nothing spawns at the knock.


## Seat every authored occupant id as a Unit on its cell. `roster` maps id →
## { "faction": Taxonomy.Faction, "weapon": Taxonomy.WeaponClass }.
## Skips ids that already have a body (opening may place some units directly).
static func seat(state: CombatState, roster: Dictionary) -> void:
	if state == null or state.map == null:
		return
	for coord in state.map.cells.keys():
		var cell: Cell = state.map.get_cell(coord)
		if cell == null or cell.occupant < 0:
			continue
		var id: int = cell.occupant
		if state.get_unit(id) != null:
			continue
		if not roster.has(id):
			push_error("Occupants.seat: no roster entry for authored occupant %d at %s" % [id, coord])
			continue
		var spec: Dictionary = roster[id]
		var faction: Taxonomy.Faction = spec.get("faction", Taxonomy.Faction.NEUTRAL) as Taxonomy.Faction
		var weapon: Taxonomy.WeaponClass = spec.get(
			"weapon", Taxonomy.WeaponClass.PISTOL
		) as Taxonomy.WeaponClass
		state.add_unit(Unit.new(id, coord, faction, weapon))


## Every authored occupant id has a body on its cell. Empty array = ok.
static func assert_seated(state: CombatState) -> Array[String]:
	var errors: Array[String] = []
	if state == null or state.map == null:
		return errors
	for coord in state.map.cells.keys():
		var cell: Cell = state.map.get_cell(coord)
		if cell == null or cell.occupant < 0:
			continue
		var body: Unit = state.get_unit(cell.occupant)
		if body == null:
			errors.append("occupant %d at %s has no body" % [cell.occupant, coord])
		elif body.cell != coord:
			errors.append(
				"occupant %d authored at %s but body stands at %s" % [cell.occupant, coord, body.cell]
			)
	return errors
