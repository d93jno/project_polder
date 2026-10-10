extends Object
## Which bowls of the basin have an authored tactical map, and how to open a fight on one (plan 07
## §7.3). Only the terrace does today. Preload (no class_name).

const FloodedTerrace := preload("res://rules/fixtures/flooded_terrace.gd")


static func has_map(bowl_id: String) -> bool:
	return bowl_id == "terrace"


## Whether this bowl's map has a sluice a squad can open (plan 08): the redirection card is only offered
## where there is one.
static func carries_sluice(bowl_id: String) -> bool:
	return bowl_id == "terrace"


## Whether this bowl's opening carries the authored first-contact sluice (GDD §6.5): the map offers it
## because the street will not be won as it is. The first redirection recorded here is that card.
static func carries_first_contact_card(bowl_id: String) -> bool:
	return bowl_id == "terrace"


## The authored opening for `bowl_id` with its squad seated. Null for a bowl with no map.
static func opening(bowl_id: String, step: Taxonomy.WaterStep) -> CombatState:
	if bowl_id == "terrace":
		return FloodedTerrace.opening(step)
	return null
