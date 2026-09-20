class_name Command
extends RefCounted
## validate() never mutates; apply() returns a new CombatState.


func validate(_state: CombatState) -> CommandResult:
	return CommandResult.failure("not implemented")


func apply(state: CombatState) -> CombatState:
	var check := validate(state)
	if not check.ok:
		push_error("Command.apply on invalid command: %s" % check.reason)
		return state.duplicate_state()
	return _apply(state)


func _apply(state: CombatState) -> CombatState:
	return state.duplicate_state()


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
