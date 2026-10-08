extends Object
## Which bowls of the basin have an authored tactical map, and how to open a fight on one (plan 07
## §7.3). Only the terrace does today. Preload (no class_name).

const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")


static func has_map(bowl_id: String) -> bool:
	return bowl_id == "terrace"


## The authored opening for `bowl_id` with its squad seated. Null for a bowl with no map.
static func opening(bowl_id: String, step: Taxonomy.WaterStep) -> CombatState:
	if bowl_id == "terrace":
		return FloodedTerrace.opening(step)
	return null
