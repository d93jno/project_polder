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


## Whether the unit stands close enough. Public so a click can tell "walk there" from "use it".
func in_reach(state: CombatState) -> bool:
	var unit: Unit = state.get_unit(unit_id)
	return unit != null and _chebyshev(unit.cell, machine_cell) <= REACH


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
	if not in_reach(state):
		return CommandResult.failure("too far from the machine")
	if machine.on == turn_on:
		return CommandResult.failure("already %s" % _state_word(machine, turn_on))
	if machine.kind == Machine.Kind.SLUICE:
		if not turn_on:
			return CommandResult.failure("a sluice cannot be closed again")
		if state.map.water_step == Taxonomy.WaterStep.FLOODED:
			return CommandResult.failure("the water is already as deep as it goes")
	return CommandResult.success()


## Opening the sluice is irreversible and ugly: it asks once, stating the cost (UI §5, plan 06 §6.2).
func needs_confirm(state: CombatState) -> bool:
	var machine: Machine = state.machine_at(machine_cell)
	return machine != null and machine.kind == Machine.Kind.SLUICE and turn_on


## The step the bowl's water will stand at after this command: one wetter for a sluice being opened
## (GDD 6.4, plan 06 §7.2), unchanged for everything else. The preview reads this too.
func water_step_after(state: CombatState) -> Taxonomy.WaterStep:
	var step := state.map.water_step
	if needs_confirm(state) and step != Taxonomy.WaterStep.FLOODED:
		return (int(step) - 1) as Taxonomy.WaterStep
	return step


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
	if needs_confirm(state):
		## The whole bowl steps wetter. A new map, so the states sharing the old one are untouched.
		next.redirect_water(water_step_after(state), state.map.water_z)
	return next


static func _chebyshev(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), maxi(absi(a.y - b.y), absi(a.z - b.z)))


static func _state_word(machine: Machine, on: bool) -> String:
	match machine.kind:
		Machine.Kind.PUMP:
			return "running" if on else "stopped"
		_:
			return "open" if on else "closed"
