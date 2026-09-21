class_name CombatState
extends RefCounted
## Fight state. Commands return a new state; validate never mutates.

enum PhaseSide {
	PLAYER,
	ENEMY,
}

var map: BowlMap
var units: Dictionary = {} ## int id -> Unit
var watches: Array = [] ## LiveWatch
var active_side: PhaseSide = PhaseSide.PLAYER
## Increments each time a full round (player + enemy) completes.
var round_index: int = 0
## Free movement until contact, phases after (GDD §3.1). Break is a combat state: it is only
## evaluated once phases have started.
var in_contact: bool = false
## Tiles where a standing unit can leave the map (the boat, a marked roof). Authored per fight.
var extract_cells: Array[Vector3i] = []
## Per-unit fog. Copied like units, never shared like the map (plan 04 §4.2).
var knowledge: Knowledge = Knowledge.new()


func add_unit(unit: Unit) -> void:
	units[unit.id] = unit


func get_unit(id: int) -> Unit:
	return units.get(id) as Unit


func all_units() -> Array:
	return units.values()


func add_watch(watch: LiveWatch) -> void:
	watches.append(watch)


## Standing hostiles only. A bleeder cannot fire, so it is neither a gun on anyone nor a foe to
## count against (GDD §5.5 outnumbered). One definition, shared by exposure and break (plan §1.5.1).
func hostiles_of(unit: Unit) -> Array:
	var out: Array = []
	for other in units.values():
		if other.id == unit.id:
			continue
		if not other.is_active():
			continue
		if is_hostile(unit.faction, other.faction):
			out.append(other)
	return out


## The standing hostiles with a clean line on `unit` — the bodies, not just the count.
## Exposure's count and break's "guns on you" both fall out of this (UI §4.6).
func attackers_of(map: BowlMap, unit: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for hostile in hostiles_of(unit):
		if Los.line_of_sight(map, hostile.cell, unit.cell, hostile.weapon).clean:
			out.append(hostile)
	return out


func units_of_faction(faction: Taxonomy.Faction) -> Array:
	var out: Array = []
	for unit in units.values():
		if unit.faction == faction:
			out.append(unit)
	return out


func units_on_side(side: PhaseSide) -> Array:
	var out: Array = []
	for unit in units.values():
		if side_of(unit) == side:
			out.append(unit)
	return out


func side_of(unit: Unit) -> PhaseSide:
	return PhaseSide.PLAYER if unit.faction == Taxonomy.Faction.PLAYER else PhaseSide.ENEMY


func duplicate_state() -> CombatState:
	var copy := CombatState.new()
	## The BowlMap is shared, read-only input to the fight: a fight never writes to it. Where a unit
	## stands lives in `units`, which every copy owns. `Cell.occupant` is the *authored* occupant of a
	## roof or deck (UI §17), a different thing (plan §7.5).
	copy.map = map
	copy.active_side = active_side
	copy.round_index = round_index
	copy.in_contact = in_contact
	copy.extract_cells = extract_cells.duplicate()
	copy.knowledge = knowledge.duplicate_knowledge() if knowledge != null else Knowledge.new()
	for unit in units.values():
		copy.units[unit.id] = unit.duplicate_unit()
	for watch in watches:
		var w: LiveWatch = watch
		copy.watches.append(LiveWatch.new(w.unit_id, w.facing, w.spent))
	return copy


func spend_watch(unit_id: int) -> void:
	for watch in watches:
		var w: LiveWatch = watch
		if w.unit_id == unit_id and not w.spent:
			w.spent = true


func cancel_watches_for(unit_id: int) -> void:
	spend_watch(unit_id)


func live_watch_for(unit_id: int) -> LiveWatch:
	for watch in watches:
		var w: LiveWatch = watch
		if w.unit_id == unit_id and not w.spent:
			return w
	return null


## Apply a non-drop hit's pin (GDD §5.4). No-ops if already paying a pinned phase.
## Pinned and broken: broken wins — the unit takes its broken move, not a duck (GDD §5.5, 1.7).
func apply_pin(target: Unit) -> void:
	cancel_watches_for(target.id)
	if target.broken:
		return
	if target.pin != Unit.PinState.NONE:
		return ## No stunlock — one hit costs one phase at most
	if side_of(target) == active_side:
		target.pin = Unit.PinState.DUCKED
		target.ap = 0
	else:
		target.pin = Unit.PinState.DUCKING_NEXT


func apply_damage(target: Unit, damage: int) -> void:
	if target.dead:
		return
	if target.bleeding:
		## Executing a bleeder
		target.dead = true
		target.bleed_rounds_left = 0
		cancel_watches_for(target.id)
		return
	target.hp = maxi(0, target.hp - damage)
	if target.hp <= 0:
		target.bleeding = true
		target.bleed_rounds_left = RulesConstants.BLEED_ROUNDS
		target.pin = Unit.PinState.NONE
		target.ap = 0
		cancel_watches_for(target.id)
	else:
		apply_pin(target)


func end_phase() -> CombatState:
	var next := duplicate_state()
	var ending := next.active_side
	for unit in next.units_on_side(ending):
		if unit.pin == Unit.PinState.DUCKED:
			unit.pin = Unit.PinState.NONE
		## A break is served over the unit's own phases and clears at the end of the last (plan §7.3).
		if unit.broken:
			unit.break_phases_left -= 1
			if unit.break_phases_left <= 0:
				unit.broken = false
				unit.break_phases_left = 0

	next.active_side = PhaseSide.ENEMY if ending == PhaseSide.PLAYER else PhaseSide.PLAYER
	for unit in next.units_on_side(next.active_side):
		if not unit.is_active():
			unit.ap = 0
			continue
		if unit.pin == Unit.PinState.DUCKING_NEXT:
			unit.pin = Unit.PinState.DUCKED
			unit.ap = 0
		elif unit.pin == Unit.PinState.DUCKED:
			unit.ap = 0
		else:
			unit.ap = RulesConstants.AP_POOL

	## Full round completes when the enemy phase ends.
	if ending == PhaseSide.ENEMY:
		next.round_index += 1
		next._tick_bleed()

	## Break is checked again at each phase start, so a unit still outnumbered in the open simply
	## breaks again (GDD §5.5, plan §7.3).
	if next.in_contact and next.map != null:
		BreakRule.resolve(next)
	return next


func _tick_bleed() -> void:
	for unit in units.values():
		if not unit.bleeding or unit.bleed_stabilized or unit.dead:
			continue
		unit.bleed_rounds_left -= 1
		if unit.bleed_rounds_left <= 0:
			unit.dead = true


## Friends: the same faction, or any two non-player, non-neutral factions. P0's sides are the player
## against everyone else, so the enemy factions fight as one; neutrals (roof people) are nobody's.
static func is_friend(a: Taxonomy.Faction, b: Taxonomy.Faction) -> bool:
	if a == b:
		return a != Taxonomy.Faction.NEUTRAL
	if a == Taxonomy.Faction.PLAYER or b == Taxonomy.Faction.PLAYER:
		return false
	return a != Taxonomy.Faction.NEUTRAL and b != Taxonomy.Faction.NEUTRAL


## P0: player vs everyone else (except neutral); non-player only hostile to player.
static func is_hostile(a: Taxonomy.Faction, b: Taxonomy.Faction) -> bool:
	if a == b:
		return false
	if a == Taxonomy.Faction.NEUTRAL or b == Taxonomy.Faction.NEUTRAL:
		return false
	if a == Taxonomy.Faction.PLAYER or b == Taxonomy.Faction.PLAYER:
		return true
	return false
