class_name TableDispatch
extends Object
## Where the basin meets the tactical layer (plan 07 §7.3). A dispatch builds an ordinary `CombatState`
## from the bowl's authored opening: the basin's water reaches the fight through `BowlMap.with_water`
## and nowhere else, and nothing in the tactical rules ever reads the basin or the campaign.

const BowlOpenings := preload("res://rules/fixtures/bowl_openings.gd")


## The fight for `bowl_id` at the basin's current water, with only `unit_ids` of the squad seated.
static func build_fight(campaign: Campaign, bowl_id: String, unit_ids: Array[int]) -> CombatState:
	var bowl: BasinBowl = campaign.basin.bowl(bowl_id)
	var state := BowlOpenings.opening(bowl_id, bowl.step)
	state.map = state.map.with_water(bowl.step, state.map.water_z)
	for unit in state.units_of_faction(Taxonomy.Faction.PLAYER):
		if unit.id not in unit_ids:
			state.units.erase(unit.id)
	return state
