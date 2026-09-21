class_name WatchCommand
extends Command

var unit_id: int
var facing: Vector3i


func _init(p_unit_id: int = -1, p_facing: Vector3i = Vector3i(1, 0, 0)) -> void:
	unit_id = p_unit_id
	facing = p_facing


func validate(state: CombatState) -> CommandResult:
	var ready := _actor_ready(state, unit_id)
	if not ready.ok:
		return ready
	var unit: Unit = state.get_unit(unit_id)
	if unit.ap < RulesConstants.WATCH_COST:
		return CommandResult.failure("not enough AP")
	if state.live_watch_for(unit_id) != null:
		return CommandResult.failure("already watching")
	return CommandResult.success()


func _is_act() -> bool:
	return true


func _act_unit_id() -> int:
	return unit_id


func _apply(state: CombatState, _reveal: RevealResult) -> CombatState:
	var next := state.duplicate_state()
	var unit: Unit = next.get_unit(unit_id)
	unit.ap -= RulesConstants.WATCH_COST
	unit.facing = facing
	next.add_watch(LiveWatch.new(unit_id, facing, false))
	return next
