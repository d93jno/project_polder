class_name ShootCommand
extends Command

var attacker_id: int
var target_id: int


func _init(p_attacker_id: int = -1, p_target_id: int = -1) -> void:
	attacker_id = p_attacker_id
	target_id = p_target_id


func validate(state: CombatState) -> CommandResult:
	var ready := _actor_ready(state, attacker_id)
	if not ready.ok:
		return ready
	var attacker: Unit = state.get_unit(attacker_id)
	var target: Unit = state.get_unit(target_id)
	if target == null:
		return CommandResult.failure("unknown target")
	if target.dead:
		return CommandResult.failure("target is dead")
	if not CombatState.is_hostile(attacker.faction, target.faction):
		return CommandResult.failure("not hostile")
	if attacker.ap < RulesConstants.shot_cost(attacker.weapon):
		return CommandResult.failure("not enough AP")
	if not RulesConstants.can_fire_in_deep_water(attacker.weapon):
		var cell: Cell = state.map.get_cell(attacker.cell)
		if cell != null and cell.material == Taxonomy.CoverMaterial.WATER_DEEP:
			return CommandResult.failure("cannot fire long gun in deep water")
	var los := Los.line_of_sight(state.map, attacker.cell, target.cell, attacker.weapon)
	if not los.clean:
		return CommandResult.failure("no clean line")
	return CommandResult.success()


## The player fires (GDD §3.1). The squad's own line starting fights is deliberate: contact is one-sided
## when it is a hostile's line, and the player's own action is the other way in.
func _starts_contact(state: CombatState) -> bool:
	var attacker: Unit = state.get_unit(attacker_id)
	return attacker != null and attacker.faction == Taxonomy.Faction.PLAYER


func _apply(state: CombatState) -> CombatState:
	var next := state.duplicate_state()
	var attacker: Unit = next.get_unit(attacker_id)
	var target: Unit = next.get_unit(target_id)
	attacker.ap -= RulesConstants.shot_cost(attacker.weapon)
	next.apply_damage(target, RulesConstants.shot_damage(attacker.weapon))
	return next
