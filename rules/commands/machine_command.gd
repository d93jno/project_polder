class_name MachineCommand
extends Command
## Start, stop, open or close a machine (plan 06 §6.0). One command, validated and priced like any
## interact: it spends INTERACT_COST, it is an act, and a Live hostile standing on the machine is contact.

## How near the unit must stand: the machine's own tile or one tile around it.
const REACH := 1

var unit_id: int
var machine_cell: Vector3i
var turn_on: bool


func _init(p_unit_id: int = -1, p_machine_cell: Vector3i = Vector3i.ZERO, p_turn_on: bool = true) -> void:
	unit_id = p_unit_id
	machine_cell = p_machine_cell
	turn_on = p_turn_on


func validate(state: CombatState) -> CommandResult:
	var ready := _actor_ready(state, unit_id)
	if not ready.ok:
		return ready
	var unit: Unit = state.get_unit(unit_id)
	if unit.ap < RulesConstants.INTERACT_COST:
		return CommandResult.failure("not enough AP")
	var machine: Machine = state.machine_at(machine_cell)
	if machine == null:
		return CommandResult.failure("no machine there")
	if _chebyshev(unit.cell, machine_cell) > REACH:
		return CommandResult.failure("too far from the machine")
	if machine.on == turn_on:
		return CommandResult.failure("already %s" % _state_word(machine, turn_on))
	if machine.kind == Machine.Kind.SLUICE and not turn_on:
		return CommandResult.failure("a sluice cannot be closed again")
	return CommandResult.success()


func _is_act() -> bool:
	return true


func _triggers_in_cone_watch() -> bool:
	return true


func _act_unit_id() -> int:
	return unit_id


func _starts_contact(state: CombatState) -> bool:
	var unit: Unit = state.get_unit(unit_id)
	if unit == null or unit.faction != Taxonomy.Faction.PLAYER:
		return false
	return Contact.machine_starts_contact(state.map, state, unit, machine_cell)


func _apply(state: CombatState, _reveal: RevealResult) -> CombatState:
	var next := state.duplicate_state()
	next.get_unit(unit_id).ap -= RulesConstants.INTERACT_COST
	next.machine_at(machine_cell).on = turn_on
	return next


static func _chebyshev(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), maxi(absi(a.y - b.y), absi(a.z - b.z)))


static func _state_word(machine: Machine, on: bool) -> String:
	match machine.kind:
		Machine.Kind.PUMP:
			return "running" if on else "stopped"
		_:
			return "open" if on else "closed"
