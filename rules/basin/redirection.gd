class_name Redirection
extends RefCounted
## One chosen redirection (plan 08 §7.4, §7.6, GDD §6.4): the bowl, the day, the step it left and the step it
## was left at, and whether it was the authored first-contact card. The campaign keeps these, and
## `Ending.is_bitter` reads them. `record` is the one place a bowl is redirected: nothing else sets
## a redirected bowl's step or hold.

const BowlOpenings := preload("res://rules/fixtures/bowl_openings.gd")

var bowl_id: String = ""
var day: int = 0
var from_step: Taxonomy.WaterStep = Taxonomy.WaterStep.DRY
var to_step: Taxonomy.WaterStep = Taxonomy.WaterStep.FLOODED
## The first-contact sluice is authored panic and never makes a campaign Bitter (GDD §6.5, §6.6).
var first_contact: bool = false


func _init(
	p_bowl_id: String = "",
	p_day: int = 0,
	p_from: Taxonomy.WaterStep = Taxonomy.WaterStep.DRY,
	p_to: Taxonomy.WaterStep = Taxonomy.WaterStep.FLOODED,
	p_first_contact: bool = false,
) -> void:
	bowl_id = p_bowl_id
	day = p_day
	from_step = p_from
	to_step = p_to
	first_contact = p_first_contact


## Still hanging: the bowl stands wetter than it did before the redirection. When it has walked back
## to that step or past it the neighbours have their land back and it stops counting (decision 7.6).
func hangs(basin: Basin) -> bool:
	var bowl: BasinBowl = basin.bowl(bowl_id)
	return bowl != null and int(bowl.step) < int(from_step)


func duplicate_redirection() -> Redirection:
	return Redirection.new(bowl_id, day, from_step, to_step, first_contact)


## Redirect `bowl_id` to `to_step` on a campaign the caller owns. The bowl stops walking and is held
## wet. If an earlier redirection of the same bowl is still hanging, the two count once, judged
## against the step the first one left. The first redirection at a bowl that carries the authored
## first-contact card is that card.
static func record(campaign: Campaign, bowl_id: String, to_step: Taxonomy.WaterStep) -> Redirection:
	var bowl: BasinBowl = campaign.basin.bowl(bowl_id)
	var from_step := bowl.step
	var first: bool = BowlOpenings.carries_first_contact_card(bowl_id) and not campaign.cards_spent.has(bowl_id)
	for i in range(campaign.redirections.size() - 1, -1, -1):
		var earlier: Redirection = campaign.redirections[i]
		if earlier.bowl_id == bowl_id and earlier.hangs(campaign.basin):
			from_step = earlier.from_step
			campaign.redirections.remove_at(i)
			break
	bowl.step = to_step
	bowl.walk = BasinBowl.Walk.NONE
	bowl.walk_days_left = 0
	bowl.hang_days = BasinRules.REDIRECTION_HANG_DAYS
	campaign.cards_spent[bowl_id] = true
	var entry := Redirection.new(bowl_id, campaign.day, from_step, to_step, first)
	campaign.redirections.append(entry)
	return entry
