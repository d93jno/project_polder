class_name InteractCommand
extends Command
## Interact — trauma kit on an adjacent bleeding ally (GDD §5.5), or a generic spend.

enum Kind {
	GENERIC,
	TRAUMA_KIT,
	KNOCK, ## Knock a shelter: contact if a hostile is in it, a meeting or a quiet night if not
	MACHINE, ## Start a machine: contact if a Live hostile stands on its tile
}

var unit_id: int
var target_cell: Vector3i
var kind: Kind = Kind.GENERIC


func _init(
	p_unit_id: int = -1,
	p_target_cell: Vector3i = Vector3i.ZERO,
	p_kind: Kind = Kind.GENERIC,
) -> void:
	unit_id = p_unit_id
	target_cell = p_target_cell
	kind = p_kind


func validate(state: CombatState) -> CommandResult:
	var ready := _actor_ready(state, unit_id)
	if not ready.ok:
		return ready
	var unit: Unit = state.get_unit(unit_id)
	if unit.ap < RulesConstants.INTERACT_COST:
		return CommandResult.failure("not enough AP")
	if kind == Kind.TRAUMA_KIT:
		if not unit.has_trauma_kit:
			return CommandResult.failure("no trauma kit")
		var patient := _patient_at(state, unit)
		if patient == null:
			return CommandResult.failure("no bleeding ally at target")
	elif not state.map.has_cell(target_cell):
		return CommandResult.failure("no cell to interact with")
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
	match kind:
		Kind.KNOCK:
			return Contact.knock_starts_contact(state, unit, target_cell)
		Kind.MACHINE:
			return Contact.machine_starts_contact(state.map, state, unit, target_cell)
		_:
			return false


func _apply(state: CombatState, _reveal: RevealResult) -> CombatState:
	var next := state.duplicate_state()
	var unit: Unit = next.get_unit(unit_id)
	unit.ap -= RulesConstants.INTERACT_COST
	if kind == Kind.TRAUMA_KIT:
		var patient := _patient_at(next, unit)
		patient.bleed_stabilized = true
		unit.has_trauma_kit = false
	return next


func _patient_at(state: CombatState, medic: Unit) -> Unit:
	for other in state.units.values():
		var ally: Unit = other
		if ally.id == medic.id:
			continue
		if ally.faction != medic.faction:
			continue
		if not ally.bleeding or ally.dead or ally.bleed_stabilized:
			continue
		if ally.cell != target_cell:
			continue
		if _chebyshev(medic.cell, ally.cell) > 1:
			continue
		return ally
	return null


static func _chebyshev(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), maxi(absi(a.y - b.y), absi(a.z - b.z)))
