class_name Economy
extends Object
## The day economy (plan 09): the one place the camp's food, fuel, scrap and people change by the
## day's arithmetic. Pure and deterministic. Slice 9.0 is the meal; the harvest, the leg, scrap and
## growth arrive in the slices after it.


## The camp eats once the basin has ticked. Food never goes below zero; what could not be fed is
## recorded as a shortfall, which is a fact for the morning, not a number that carries.
static func eat(campaign: Campaign, result: DayResult) -> void:
	var need := BasinRules.food_for(campaign.people())
	var ate := mini(campaign.food, need)
	campaign.food -= ate
	result.meal = {"ate": ate, "short": need - ate}
