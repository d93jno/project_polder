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


## The bands the basin opens with (plan 10, GDD §5.12), unmet and standing at the start of their route: a
## Wake-Rider boat that works the terrace and the first polder, and a roof-clan on the west ridge. Data,
## not a guess about the player's history. `job` is a `Band.Job`.
static func bands() -> Array:
	return [
		{"id": "wake_riders", "job": Band.Job.EYES, "route": ["terrace", "polder_a"]},
		{"id": "roof_clan", "job": Band.Job.FOOD, "route": ["ridge_w"]},
	]


## The cache a fireteam brings home from this bowl the first time someone gets out with it (plan 09
## §9.3, GDD §4.2: diesel salvaged in Flooded and Mud). Authored data on the bowl, so it is knowable.
static func salvage(bowl_id: String) -> Dictionary:
	if bowl_id == "terrace":
		return {"scrap": 2, "fuel": 2}
	return {}


## The authored opening for `bowl_id` with its squad seated. Null for a bowl with no map.
static func opening(bowl_id: String, step: Taxonomy.WaterStep) -> CombatState:
	if bowl_id == "terrace":
		return FloodedTerrace.opening(step)
	return null
