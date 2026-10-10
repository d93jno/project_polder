class_name EconomyForecast
extends Object
## What the economy will do, read by running the rule on copies (plan 09, GDD §4.2: never a surprise).
## It ends real days on duplicates of the campaign, so it cannot disagree with the tick.


## How many whole days the food lasts if the camp, its labor and its fields stay as they are: the days
## that will be fed in full. -1 means more than BasinRules.FORECAST_DAYS.
static func days_of_food(campaign: Campaign) -> int:
	var copy := campaign.duplicate_campaign()
	for day in BasinRules.FORECAST_DAYS:
		copy.close_day()
		if int(copy.morning.meal["short"]) > 0:
			return day
	return -1
