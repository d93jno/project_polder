class_name Command
extends RefCounted
## validate() never mutates; apply() returns a new CombatState.
##
## apply() also starts phases when the player's action is what starts them (GDD §3.1), then lets any
## break that action caused land in the same command (GDD §5.5).


func validate(_state: CombatState) -> CommandResult:
	return CommandResult.failure("not implemented")


func apply(state: CombatState) -> CombatState:
	var check := validate(state)
	if not check.ok:
		push_error("Command.apply on invalid command: %s" % check.reason)
		return state.duplicate_state()
	var next := _apply(state)
	if not state.in_contact and _starts_contact(state):
		Contact.begin(next)
	BreakRule.resolve(next) ## no-op until phases have started
	return next


func _apply(state: CombatState) -> CombatState:
	return state.duplicate_state()


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
