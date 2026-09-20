class_name Contact
extends Object
## Free movement until contact, phases after (GDD §3.1, UI §7). Pure over `map` and `state`.
##
## Contact is one-sided on purpose: it is a hostile getting a line on the squad, or the player
## acting. If the squad's own line started fights, contact range would depend on loadout, and
## spotting a camp and turning the boat around would stop being a choice.


## A hostile has a clean line on a squad body. Run after every free-move step (UI §17).
## Neutrals never count, so a friendly roof meeting is never contact, and a hostile inside a
## shelter sees nothing until the knock.
static func check(map: BowlMap, state: CombatState) -> ContactResult:
	var result := ContactResult.new()
	if state.in_contact:
		result.contact = true
		result.reason = ContactResult.Reason.ALREADY
		return result
	for unit in state.units_of_faction(Taxonomy.Faction.PLAYER):
		if not unit.is_active():
			continue
		for hostile in state.attackers_of(map, unit):
			if not sees_out(map, hostile):
				continue
			result.contact = true
			result.reason = ContactResult.Reason.HOSTILE_LINE
			result.seer_id = hostile.id
			result.target_id = unit.id
			return result
	return result


## Deck occupants see the approaches, so walking into their line is contact before any knock. People
## inside see nothing until the knock (GDD §3.1). Deck versus interior is a flag on the cell, not a
## window mesh (UI §17).
static func sees_out(map: BowlMap, hostile: Unit) -> bool:
	var cell: Cell = map.get_cell(hostile.cell)
	return cell == null or not cell.has_flag(Taxonomy.CellFlags.INTERIOR)


## Knocking a shelter is contact only if someone hostile is in it. A friendly roof is a meeting and an
## empty one is a quiet night (GDD §3.1).
static func knock_starts_contact(state: CombatState, knocker: Unit, shelter_cell: Vector3i) -> bool:
	for other in state.units.values():
		if other.is_active() and other.cell == shelter_cell:
			if CombatState.is_hostile(knocker.faction, other.faction):
				return true
	return false


## Starting a machine on a tile with a Live hostile (a contested machine). Live means some standing
## squad body can see it.
static func machine_starts_contact(
	map: BowlMap,
	state: CombatState,
	actor: Unit,
	machine_cell: Vector3i,
) -> bool:
	for other in state.units.values():
		if not other.is_active() or other.cell != machine_cell:
			continue
		if CombatState.is_hostile(actor.faction, other.faction) and is_live(map, state, other):
			return true
	return false


## Visible to the squad right now.
static func is_live(map: BowlMap, state: CombatState, hostile: Unit) -> bool:
	for unit in state.units_of_faction(Taxonomy.Faction.PLAYER):
		if unit.is_active() and Los.line_of_sight(map, unit.cell, hostile.cell, unit.weapon).clean:
			return true
	return false


## Phases start. The player moves first.
static func begin(state: CombatState) -> void:
	state.in_contact = true
	state.active_side = CombatState.PhaseSide.PLAYER
