class_name Unit
extends RefCounted
## One body on the bowl.

enum PinState {
	NONE,
	DUCKED, ## Hit in own phase — rest of phase gone; clears at end of it
	DUCKING_NEXT, ## Hit in opponent's phase — next phase spent ducked
}

var id: int = -1
var cell: Vector3i = Vector3i.ZERO
var faction: Taxonomy.Faction = Taxonomy.Faction.NEUTRAL
var weapon: Taxonomy.WeaponClass = Taxonomy.WeaponClass.PISTOL
## Cardinal facing on the ground plane: (±1,0,0) or (0,±1,0).
var facing: Vector3i = Vector3i(1, 0, 0)
## Remaining AP this phase. *Working default* pool is RulesConstants.AP_POOL.
var ap: int = RulesConstants.AP_POOL
var hp: int = RulesConstants.HP_PIPS
var pin: PinState = PinState.NONE
var bleeding: bool = false
var bleed_rounds_left: int = 0
var bleed_stabilized: bool = false
var dead: bool = false
var has_trauma_kit: bool = false
## Trained and kitted for the ground it stands on. Break clause 3 is about the *unadapted*:
## Drifters, untrained AI, raw unclassed recruits (GDD §5.5). P0's cast is all unadapted.
var adapted: bool = false
## Bitfield over Taxonomy.Scar.
var scars: int = 0
## GDD §5.5. Set by break resolution; the broken *move* rule is applied on top of it.
var broken: bool = false
## The Call is a radius around the founder (GDD §8.4) and founder-down changes the mission
## (GDD §8.5). Nothing else on the map says which body that is.
var is_founder: bool = false
## Own-side phases left before `broken` clears (plan §7.3 working default). A break that lands in the
## unit's own phase forfeits the rest of it and constrains the next, so it is 2; one that lands in
## the opponent's phase constrains only the next own phase, so it is 1. Cleared at that phase's end.
var break_phases_left: int = 0
## Off the map through an extract tile. Neither a target, a gun, a friend, nor a body in the way.
var extracted: bool = false


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
	hp = RulesConstants.HP_PIPS


func duplicate_unit() -> Unit:
	var u := Unit.new(id, cell, faction, weapon, facing, ap)
	u.hp = hp
	u.pin = pin
	u.bleeding = bleeding
	u.bleed_rounds_left = bleed_rounds_left
	u.bleed_stabilized = bleed_stabilized
	u.dead = dead
	u.has_trauma_kit = has_trauma_kit
	u.adapted = adapted
	u.scars = scars
	u.broken = broken
	u.is_founder = is_founder
	u.break_phases_left = break_phases_left
	u.extracted = extracted
	return u


func duplicate_at(new_cell: Vector3i) -> Unit:
	var u := duplicate_unit()
	u.cell = new_cell
	return u


func has_scar(scar: int) -> bool:
	return (scars & scar) != 0


func give_scar(scar: int) -> void:
	scars |= scar


func is_active() -> bool:
	return not dead and not bleeding and not extracted


func is_pinned() -> bool:
	return pin != PinState.NONE
