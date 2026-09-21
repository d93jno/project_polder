class_name FreeMoveCommand
extends Command
## Squad-mode walking (GDD §3.1): no AP, no Watch, no End Turn. Steps tile by tile and stops the
## moment a step starts contact, so phases begin on the tile where the squad was caught.

var unit_id: int
var to: Vector3i


func _init(p_unit_id: int = -1, p_to: Vector3i = Vector3i.ZERO) -> void:
	unit_id = p_unit_id
	to = p_to


func validate(state: CombatState) -> CommandResult:
	if state.in_contact:
		return CommandResult.failure("phases have started; movement costs AP")
	var unit: Unit = state.get_unit(unit_id)
	if unit == null:
		return CommandResult.failure("unknown unit")
	if unit.faction != Taxonomy.Faction.PLAYER:
		return CommandResult.failure("only the squad walks freely")
	if not unit.is_active():
		return CommandResult.failure("unit is down")
	if to == unit.cell:
		return CommandResult.failure("already there")
	if not Movement.path(state.map, state, unit, to).reachable:
		return CommandResult.failure("unreachable")
	return CommandResult.success()


func _apply(state: CombatState) -> CombatState:
	var next := state.duplicate_state()
	var unit: Unit = next.get_unit(unit_id)
	var path := Movement.path(next.map, next, unit, to)
	for i in range(1, path.cells.size()):
		unit.cell = path.cells[i]
		next.knowledge.peel(next.map, next)
		if Contact.check(next.map, next).contact:
			Contact.begin(next)
			break
	return next
