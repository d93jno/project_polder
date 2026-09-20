class_name ExtractCommand
extends Command
## A standing unit on an extract tile leaves the map (GDD §5.6: get them to the boat).
## A downed unit is not extracted by walking: that is MEDEVAC, a table-scale matter (GDD §8.5).

var unit_id: int


func _init(p_unit_id: int = -1) -> void:
	unit_id = p_unit_id


func validate(state: CombatState) -> CommandResult:
	var ready := _actor_ready(state, unit_id)
	if not ready.ok:
		return ready
	var unit: Unit = state.get_unit(unit_id)
	if unit.cell not in state.extract_cells:
		return CommandResult.failure("not on an extract tile")
	return CommandResult.success()


func _apply(state: CombatState) -> CombatState:
	var next := state.duplicate_state()
	var unit: Unit = next.get_unit(unit_id)
	unit.extracted = true
	next.cancel_watches_for(unit_id)
	return next
