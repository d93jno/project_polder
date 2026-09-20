class_name BreakRule
extends Object
## Break: deterministic morale (GDD §5.5 as of 1.9, all *working default*). Pure over `map` and
## `state`, except `resolve`, which is the one place a break lands.
##
## Clauses 1 and 3 are facts about the map and are known before the click. Clause 2 also needs the
## unit to be Pinned, which needs an enemy to choose to shoot: intent, which UI §4.6 will not draw.
## So it returns WOULD_BREAK_IF_PINNED until the unit actually is.

enum Result {
	SAFE,
	WOULD_BREAK_IF_PINNED, ## Outnumbered and in the open, not yet Pinned: "if hit here, breaks"
	BREAKS,
}


static func check(map: BowlMap, state: CombatState, unit: Unit) -> Result:
	if not unit.is_active():
		return Result.SAFE
	if in_the_call(state, unit):
		return Result.SAFE ## Overrides every clause, Agoraphobia included (GDD §5.5, §8.4)
	if last_friend_dropped(state, unit):
		return Result.BREAKS
	## Clause 3 and its player-side twin are separate routes to the same break, so an Agoraphobic
	## unit that is not in the open is still checked against the plain clause.
	if unit.has_scar(Taxonomy.Scar.AGORAPHOBIA):
		if under_long_cone(map, state, unit) and in_the_open(map, state, unit):
			return Result.BREAKS ## Kit, training and terrain waived (GDD §8.5)
	if (
		not unit.adapted
		and map.water_step == Taxonomy.WaterStep.DRY
		and has_cqb_kit(unit)
		and under_long_cone(map, state, unit)
	):
		return Result.BREAKS
	if outnumbered(map, state, unit) and in_the_open(map, state, unit):
		return Result.BREAKS if unit.is_pinned() else Result.WOULD_BREAK_IF_PINNED
	return Result.SAFE


## --- The four terms (GDD §5.5, "Break, defined") ---


## Every weapon the unit carries is short. `Unit` carries one weapon today.
static func has_cqb_kit(unit: Unit) -> bool:
	return not Taxonomy.is_long(unit.weapon)


## A hostile, unspent Watch of a long class whose cone contains the unit's tile. `Cones.cone` already
## requires a clean line. A long weapon with no Watch breaks no one.
static func under_long_cone(map: BowlMap, state: CombatState, unit: Unit) -> bool:
	var stack := Cones.cone_stack(map, state, unit.cell, unit.faction)
	for weapon in stack.classes:
		if Taxonomy.is_long(weapon):
			return true
	return false


## More standing hostiles have a clean line on the unit than there are standing friends within
## RulesConstants.OUTNUMBERED_FRIEND_RADIUS tiles of it, itself included. Downed units count for
## neither side.
static func outnumbered(map: BowlMap, state: CombatState, unit: Unit) -> bool:
	return state.attackers_of(map, unit).size() > friends_near(state, unit)


## Standing friends within the radius, counting the unit itself.
static func friends_near(state: CombatState, unit: Unit) -> int:
	var n := 0
	for other in state.units.values():
		if not other.is_active():
			continue
		if other.id != unit.id and not CombatState.is_friend(unit.faction, other.faction):
			continue
		if chebyshev(unit.cell, other.cell) <= RulesConstants.OUTNUMBERED_FRIEND_RADIUS:
			n += 1
	return n


## At least one standing hostile has a clean line on the unit, and no tile it can reach is free of a
## clean line from every one of them. This is GDD §6.3's "without AP to reach hard cover" made exact.
## Pinned does not zero the AP for this test (GDD §5.5): apply_pin forfeits it in the state, so a
## pinned unit is given a full phase's AP here (plan §7.4).
static func in_the_open(map: BowlMap, state: CombatState, unit: Unit) -> bool:
	var attackers := state.attackers_of(map, unit)
	if attackers.is_empty():
		return false
	var budget: int = RulesConstants.AP_POOL if unit.is_pinned() else unit.ap
	for tile in Movement.reachable(map, state, unit, budget):
		if not _seen_by_any(map, tile, attackers):
			return false
	return true


## An allied founder stands within the Call's radius. The founder is inside their own radius.
static func in_the_call(state: CombatState, unit: Unit) -> bool:
	for other in state.units.values():
		if not other.is_founder or not other.is_active():
			continue
		if other.id != unit.id and not CombatState.is_friend(unit.faction, other.faction):
			continue
		if chebyshev(unit.cell, other.cell) <= RulesConstants.CALL_RADIUS:
			return true
	return false


## Nobody else in its squad is standing, and at least one of them has dropped. A lone unit that never
## had a squad has not lost one.
static func last_friend_dropped(state: CombatState, unit: Unit) -> bool:
	var a_friend_dropped := false
	for other in state.units.values():
		if other.id == unit.id or not CombatState.is_friend(unit.faction, other.faction):
			continue
		if other.is_active():
			return false
		if other.bleeding or other.dead:
			a_friend_dropped = true
	return a_friend_dropped


## --- Landing ---


## Check every standing unit that is not already broken and land the breaks. Break is a state and it
## lands the moment it is true (GDD §5.5). Returns the ids that broke. Mutates `state`, which callers
## must own: commands pass the copy they are about to return.
static func resolve(state: CombatState) -> Array[int]:
	var broke: Array[int] = []
	if not state.in_contact or state.map == null:
		return broke
	var ids: Array = state.units.keys()
	ids.sort()
	for id in ids:
		var unit: Unit = state.units[id]
		if unit.broken or not unit.is_active():
			continue
		if check(state.map, state, unit) == Result.BREAKS:
			_land(state, unit)
			broke.append(id)
	return broke


static func _land(state: CombatState, unit: Unit) -> void:
	unit.broken = true
	## Broken wins over Pinned: the duck is dropped so the unit can take its broken move.
	unit.pin = Unit.PinState.NONE
	## A fleeing unit is not holding a Watch (working default; GDD is silent).
	state.cancel_watches_for(unit.id)
	if state.side_of(unit) == state.active_side:
		unit.ap = 0 ## Loses the rest of the current phase (GDD §5.5)
		unit.break_phases_left = 2
	else:
		unit.break_phases_left = 1


## --- The broken move ---


## A broken unit's move must end closer to cover or to the extraction point (GDD §5.5). Cover is a
## tile no standing hostile has a clean line on. "Closer" is walking cost. A unit already in cover
## may only move to more cover. With nowhere safe to go, nothing is forbidden.
static func broken_move_ok(
	map: BowlMap,
	state: CombatState,
	unit: Unit,
	dest: Vector3i,
) -> bool:
	var safe: Array[Vector3i] = []
	for cell in map.cells.keys():
		if not Movement.is_free(map, state, cell, unit):
			continue
		if cell in state.extract_cells or ExposureQuery.exposure(map, state, unit.duplicate_at(cell)).count == 0:
			safe.append(cell)
	var dist := Movement.cost_to_nearest(map, state, unit, safe)
	if not dist.has(unit.cell):
		return true
	if not dist.has(dest):
		return false
	var there: int = dist[dest]
	return there == 0 or there < (dist[unit.cell] as int)


static func chebyshev(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), maxi(absi(a.y - b.y), absi(a.z - b.z)))


static func _seen_by_any(map: BowlMap, tile: Vector3i, attackers: Array[Unit]) -> bool:
	for a in attackers:
		if Los.line_of_sight(map, a.cell, tile, a.weapon).clean:
			return true
	return false
