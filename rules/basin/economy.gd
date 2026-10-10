class_name Economy
extends Object

const BowlOpenings := preload("res://rules/fixtures/bowl_openings.gd")
## The day economy (plan 09): the one place the camp's food, fuel, scrap and people change by the
## day's arithmetic. Pure and deterministic. Slice 9.0 is the meal; the harvest, the leg, scrap and
## growth arrive in the slices after it.


## The harvest comes in after the basin ticks, so ground that went to Mud overnight yields nothing:
## each Dry, un-ruined field yields food, and each hand in FIELDS adds to it, one hand to a field, in the
## basin's fixed order so it is always the same fields that are worked. Falling and Mud are promises,
## not food (GDD §4.3). Split by whether the player has walked the bowl, so the table never states a
## number from ground it has not seen.
static func harvest(campaign: Campaign, result: DayResult) -> void:
	var hands := campaign.hands(Campaign.Bucket.FIELDS)
	var out := {"food": 0, "unwalked": 0, "fields": 0}
	for id in campaign.basin.order:
		var bowl: BasinBowl = campaign.basin.bowl(id)
		if bowl.step != Taxonomy.WaterStep.DRY or bowl.fields <= 0:
			continue
		var worked := mini(hands, bowl.fields)
		hands -= worked
		var food := bowl.fields * BasinRules.FIELD_YIELD + worked * BasinRules.HAND_YIELD
		out["fields"] += bowl.fields
		out["food" if bowl.known else "unwalked"] += food
		campaign.food += food
	result.harvest = out


## The camp eats once the basin has ticked. Food never goes below zero; what could not be fed is
## recorded as a shortfall, which is a fact for the morning, not a number that carries.
static func eat(campaign: Campaign, result: DayResult) -> void:
	var need := BasinRules.food_for(campaign.people())
	var ate := mini(campaign.food, need)
	campaign.food -= ate
	result.meal = {"ate": ate, "short": need - ate}


## Fuel for a dispatch to `bowl_id`, there and back, paid when the fireteam is sent. A bowl the table has
## never seen has no known cost; ask only about bowls the player can name.
static func leg_cost(campaign: Campaign, bowl_id: String) -> int:
	var bowl: BasinBowl = campaign.basin.bowl(bowl_id)
	return 2 * int(BasinRules.FUEL_PER_WAY[bowl.step])


## Whether the fuel on hand reaches home from `bowl_id` (GDD §4.2: running dry is a decision that was
## available to read). The dispatch command refuses on exactly this.
static func leg_reaches_home(campaign: Campaign, bowl_id: String) -> bool:
	return campaign.fuel >= leg_cost(campaign, bowl_id)


## Fuel for the leg is paid when the fireteam is sent (plan 09 §9.2).
static func pay_leg(campaign: Campaign, bowl_id: String) -> void:
	campaign.fuel -= leg_cost(campaign, bowl_id)


## Pumps the hands reach are kept with scrap (GDD §6.2: posted hands + scrap).
static func post_pumps(campaign: Campaign, posted: Dictionary) -> void:
	campaign.scrap -= posted.size() * Campaign.SCRAP_PER_POST


## The workshop turns hands and time into scrap (plan 09 §9.3, decision 7.4).
static func work(campaign: Campaign, result: DayResult) -> void:
	result.scrap_made = campaign.hands(Campaign.Bucket.WORKSHOP) * BasinRules.SCRAP_PER_WORKSHOP_HAND
	campaign.scrap += result.scrap_made


## What a fireteam brings home from a bowl's cache, once, when at least one of them got out. Returns
## {"scrap", "fuel"} for the morning, empty when nothing came.
static func salvage(campaign: Campaign, bowl_id: String, survivors: int) -> Dictionary:
	var cache := BowlOpenings.salvage(bowl_id)
	if survivors <= 0 or cache.is_empty() or campaign.salvaged.has(bowl_id):
		return {}
	campaign.salvaged[bowl_id] = true
	campaign.scrap += int(cache.get("scrap", 0))
	campaign.fuel += int(cache.get("fuel", 0))
	return cache.duplicate()
