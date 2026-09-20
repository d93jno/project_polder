class_name Unit
extends RefCounted
## One body on the bowl. Phase 1.5 adds pin / health / bleed-out.

var id: int = -1
var cell: Vector3i = Vector3i.ZERO
var faction: Taxonomy.Faction = Taxonomy.Faction.NEUTRAL
var weapon: Taxonomy.WeaponClass = Taxonomy.WeaponClass.PISTOL
## Cardinal facing on the ground plane: (±1,0,0) or (0,±1,0).
var facing: Vector3i = Vector3i(1, 0, 0)
## Remaining AP this phase. *Working default* pool is RulesConstants.AP_POOL.
var ap: int = RulesConstants.AP_POOL


func _init(
	p_id: int = -1,
	p_cell: Vector3i = Vector3i.ZERO,
	p_faction: Taxonomy.Faction = Taxonomy.Faction.NEUTRAL,
	p_weapon: Taxonomy.WeaponClass = Taxonomy.WeaponClass.PISTOL,
	p_facing: Vector3i = Vector3i(1, 0, 0),
	p_ap: int = RulesConstants.AP_POOL,
) -> void:
	id = p_id
	cell = p_cell
	faction = p_faction
	weapon = p_weapon
	facing = p_facing
	ap = p_ap


func duplicate_at(new_cell: Vector3i) -> Unit:
	return Unit.new(id, new_cell, faction, weapon, facing, ap)
