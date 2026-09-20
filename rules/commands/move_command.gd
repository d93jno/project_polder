class_name MoveCommand
extends Command

var unit_id: int
var to: Vector3i


func _init(p_unit_id: int = -1, p_to: Vector3i = Vector3i.ZERO) -> void:
	unit_id = p_unit_id
	to = p_to


func validate(state: CombatState) -> CommandResult:
	var ready := _actor_ready(state, unit_id)
	if not ready.ok:
		return ready
	var unit: Unit = state.get_unit(unit_id)
	var path := Movement.path(state.map, state, unit, to)
	if not path.reachable:
		return CommandResult.failure("unreachable")
	if path.total_cost > unit.ap:
		return CommandResult.failure("not enough AP")
	if to == unit.cell:
		return CommandResult.failure("already there")
	return CommandResult.success()


func _apply(state: CombatState) -> CombatState:
	var next := state.duplicate_state()
	var unit: Unit = next.get_unit(unit_id)
	var path := Movement.path(next.map, next, unit, to)
	var from := unit.cell
	## Step cell-by-cell so Watch crossings resolve in order (GDD §5.2).
	for i in range(1, path.cells.size()):
		if unit.pin == Unit.PinState.DUCKED or not unit.is_active():
			break
		var step_to: Vector3i = path.cells[i]
		var step_cost: int = path.cost_per_cell[i]
		var step_from := unit.cell
		unit.ap -= step_cost
		unit.cell = step_to
		_resolve_watch_reactions(next, unit, step_from, step_to)
	return next


func _resolve_watch_reactions(
	state: CombatState,
	mover: Unit,
	from_cell: Vector3i,
	to_cell: Vector3i,
) -> void:
	for watch in state.watches:
		var live: LiveWatch = watch
		if live.spent:
			continue
		var watcher: Unit = state.get_unit(live.unit_id)
		if watcher == null or not watcher.is_active():
			continue
		if not CombatState.is_hostile(mover.faction, watcher.faction):
			continue
		var volume := Cones.cone(state.map, watcher.cell, live.facing, watcher.weapon)
		if to_cell in volume and from_cell not in volume:
			live.spent = true
			var los := Los.line_of_sight(
				state.map, watcher.cell, mover.cell, watcher.weapon, true
			)
			if los.clean:
				state.apply_damage(mover, RulesConstants.shot_damage(watcher.weapon))
			## One watch, one shot — stop after the first reaction on this step.
			return
