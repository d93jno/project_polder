class_name ThrowCommand
extends Command
## Throw a smoke grenade onto a cell (GDD §5.4 — smoke breaks line).

enum Kind {
	SMOKE,
}

var unit_id: int
var target_cell: Vector3i
var kind: Kind = Kind.SMOKE


func _init(
	p_unit_id: int = -1,
	p_target_cell: Vector3i = Vector3i.ZERO,
	p_kind: Kind = Kind.SMOKE,
) -> void:
	unit_id = p_unit_id
	target_cell = p_target_cell
	kind = p_kind


func validate(state: CombatState) -> CommandResult:
	var ready := _actor_ready(state, unit_id)
	if not ready.ok:
		return ready
	var unit: Unit = state.get_unit(unit_id)
	if unit.ap < RulesConstants.THROW_COST:
		return CommandResult.failure("not enough AP")
	if not state.map.has_cell(target_cell):
		return CommandResult.failure("no target cell")
	if _chebyshev(unit.cell, target_cell) > RulesConstants.cone_length(Taxonomy.WeaponClass.PISTOL):
		return CommandResult.failure("out of throw range")
	return CommandResult.success()


func _is_act() -> bool:
	return true


func _triggers_in_cone_watch() -> bool:
	return true


func _act_unit_id() -> int:
	return unit_id


func _apply(state: CombatState, _reveal: RevealResult) -> CombatState:
	var next := state.duplicate_state()
	var unit: Unit = next.get_unit(unit_id)
	unit.ap -= RulesConstants.THROW_COST
	if kind == Kind.SMOKE:
		var cell: Cell = next.map.get_cell(target_cell)
		if cell == null:
			cell = Cell.new(Taxonomy.CoverMaterial.SMOKE)
			next.map.set_cell(target_cell, cell)
		else:
			cell.material = Taxonomy.CoverMaterial.SMOKE
	return next


static func _chebyshev(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), maxi(absi(a.y - b.y), absi(a.z - b.z)))
