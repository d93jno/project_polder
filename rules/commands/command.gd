class_name Command
extends RefCounted
## validate() never mutates; apply() returns a new CombatState.
## apply_outcome() also returns what the command revealed (plan 04 §4.5).
##
## apply() also starts phases when the player's action is what starts them (GDD §3.1), then lets any
## break that action caused land in the same command (GDD §5.5).


func validate(_state: CombatState) -> CommandResult:
	return CommandResult.failure("not implemented")


func apply(state: CombatState) -> CombatState:
	return apply_outcome(state).state


func apply_outcome(state: CombatState) -> CommandOutcome:
	var check := validate(state)
	if not check.ok:
		push_error("Command.apply on invalid command: %s" % check.reason)
		return CommandOutcome.of(state.duplicate_state(), RevealResult.empty())

	var before_known := _known_snapshot(state)
	var reveal := RevealResult.new()
	reveal.was_act = _is_act()

	var next := _apply(state, reveal)
	if not state.in_contact and _starts_contact(state):
		Contact.begin(next)
	BreakRule.resolve(next) ## no-op until phases have started
	## Fog peels after every command; move commands also peel per step (plan 04 §4.2).
	next.knowledge.peel(next.map, next)

	_record_peel_delta(before_known, next, reveal)
	if reveal.was_act and _triggers_in_cone_watch():
		var actor_id := _act_unit_id()
		var actor: Unit = state.get_unit(actor_id)
		if actor != null:
			for wid in hostile_watches_covering(state.map, state, actor.cell, actor.faction):
				reveal.record_watch(wid)

	return CommandOutcome.of(next, reveal)


func _apply(state: CombatState, _reveal: RevealResult) -> CombatState:
	return state.duplicate_state()


## Shoot, interact, throw, watch, extract — not a free/move step (UI §5).
func _is_act() -> bool:
	return false


## GDD 1.13 qualifying acts that trigger Watch while already inside a cone.
## Setting Watch / extract / turn do not (plan 04 §4.5).
func _triggers_in_cone_watch() -> bool:
	return false


## Actor for in-cone Watch reporting when `_triggers_in_cone_watch()`; −1 if none.
func _act_unit_id() -> int:
	return -1


## Whether taking this action, from `state`, is the player acting in a way that starts contact.
func _starts_contact(_state: CombatState) -> bool:
	return false


func _actor_ready(state: CombatState, unit_id: int) -> CommandResult:
	var unit: Unit = state.get_unit(unit_id)
	if unit == null:
		return CommandResult.failure("unknown unit")
	if not unit.is_active():
		return CommandResult.failure("unit is down")
	if state.side_of(unit) != state.active_side:
		return CommandResult.failure("not this unit's phase")
	if unit.pin == Unit.PinState.DUCKED:
		return CommandResult.failure("unit is ducked")
	return CommandResult.success()


static func _known_snapshot(state: CombatState) -> Dictionary:
	if state == null or state.knowledge == null:
		return {}
	return state.knowledge.known_cells(state).duplicate()


static func _record_peel_delta(before_known: Dictionary, after: CombatState, reveal: RevealResult) -> void:
	if after == null or after.knowledge == null:
		return
	for cell in after.knowledge.known_cells(after).keys():
		if not before_known.has(cell):
			reveal.record_peeled(cell)


## Shared: hostile unspent watches whose cone contains `cell`.
static func hostile_watches_covering(
	map: BowlMap,
	state: CombatState,
	cell: Vector3i,
	mover_faction: Taxonomy.Faction,
) -> Array[int]:
	var out: Array[int] = []
	for watch in state.watches:
		var live: LiveWatch = watch
		if live.spent:
			continue
		var watcher: Unit = state.get_unit(live.unit_id)
		if watcher == null or not watcher.is_active():
			continue
		if not CombatState.is_hostile(mover_faction, watcher.faction):
			continue
		var volume := Cones.cone(map, watcher.cell, live.facing, watcher.weapon)
		if cell in volume:
			out.append(watcher.id)
	return out


## Standing hostiles with a clean line on `unit` who can see out (deck, not interior).
static func enemy_line_seers(map: BowlMap, state: CombatState, unit: Unit) -> Array[int]:
	var out: Array[int] = []
	for hostile in state.attackers_of(map, unit):
		if Contact.sees_out(map, hostile):
			out.append(hostile.id)
	return out
