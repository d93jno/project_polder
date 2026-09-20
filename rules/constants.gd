class_name RulesConstants
extends Object
## Working defaults — tune here, nowhere else (plan §4 / §5).


## --- AP pool and action prices (*working default*, GDD §5.3) ---
const AP_POOL := 6
const SHOT_COST := 2
const SHOT_COST_LONG := 3 ## Rifle / LMG / sniper — heavier commit
const WATCH_COST := 3
const INTERACT_COST := 2
const THROW_COST := 2

## --- Health (*working default*, GDD §5.4) ---
const HP_PIPS := 2 ## Two pistol hits drop; one rifle hit drops
const BLEED_ROUNDS := 3 ## *Working default* (GDD §5.5); round = player + enemy phase

## --- Move costs (*working default*) ---
const MOVE_COST_DRY := 1
const MOVE_COST_MUD := 2 ## Mud doubles (GDD §5.3)
const MOVE_COST_SWIM := 2 ## Flooded swim
const MOVE_COST_FALLING := 2 ## Chest-deep ugly footing
const MOVE_COST_VERTICAL_SURCHARGE := 1 ## Added when z changes (climb / dive)

## --- The Call (*working default*, GDD §8.4) ---
## GDD gives no number: "small" early, "full weight" late. One constant now; scaling is later.
const CALL_RADIUS := 2 ## Chebyshev tiles around the founder within which allies cannot break


## Watch cone length in chebyshev cells, by weapon class. *Working default.*
static func cone_length(weapon: Taxonomy.WeaponClass) -> int:
	match weapon:
		Taxonomy.WeaponClass.PISTOL:
			return 4
		Taxonomy.WeaponClass.MELEE:
			return 1
		Taxonomy.WeaponClass.SPEAR:
			return 2
		Taxonomy.WeaponClass.SHOTGUN:
			return 3
		Taxonomy.WeaponClass.RIFLE:
			return 8
		Taxonomy.WeaponClass.LMG:
			return 7
		Taxonomy.WeaponClass.SNIPER:
			return 12
		_:
			return 4


static func shot_cost(weapon: Taxonomy.WeaponClass) -> int:
	return SHOT_COST_LONG if Taxonomy.is_long(weapon) else SHOT_COST


## Damage in HP pips. Rifle-class drops in one hit (GDD §5.4).
static func shot_damage(weapon: Taxonomy.WeaponClass) -> int:
	return HP_PIPS if Taxonomy.is_long(weapon) else 1


static func can_fire_in_deep_water(weapon: Taxonomy.WeaponClass) -> bool:
	return not Taxonomy.is_long(weapon)


static func step_move_cost(water_step: Taxonomy.WaterStep) -> int:
	match water_step:
		Taxonomy.WaterStep.FLOODED:
			return MOVE_COST_SWIM
		Taxonomy.WaterStep.FALLING:
			return MOVE_COST_FALLING
		Taxonomy.WaterStep.MUD:
			return MOVE_COST_MUD
		Taxonomy.WaterStep.DRY:
			return MOVE_COST_DRY
		_:
			return MOVE_COST_DRY
