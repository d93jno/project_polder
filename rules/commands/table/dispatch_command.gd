class_name DispatchCommand
extends TableCommand
## Send up to four from the bench to one bowl (plan 07 §7.3, GDD §4.2). Only marks them out: the fight
## itself is the tactical layer's, built by `TableDispatch.build_fight`, and `HomeCommand` brings them back.

const BowlOpenings := preload("res://rules/fixtures/bowl_openings.gd")
const MAX_BODIES := 4

var bowl_id: String
var unit_ids: Array[int]
## "Refuse the sluice" (plan 08 §8.5, GDD §4.2): an active no. The fight is built with its sluice held shut.
var hold_sluice: bool


func _init(p_bowl_id: String = "", p_unit_ids: Array[int] = [], p_hold_sluice: bool = false) -> void:
	bowl_id = p_bowl_id
	unit_ids = p_unit_ids
	hold_sluice = p_hold_sluice


func validate(campaign: Campaign) -> CommandResult:
	if not campaign.deployment.is_empty():
		return CommandResult.failure("the fireteam is already out")
	if campaign.dispatched_today:
		return CommandResult.failure("one dispatch a day")
	var bowl: BasinBowl = campaign.basin.bowl(bowl_id) if campaign.basin != null else null
	if bowl == null or not bowl.known:
		return CommandResult.failure("that bowl is unknown")
	if not BowlOpenings.has_map(bowl_id):
		return CommandResult.failure("no known map")
	if unit_ids.is_empty():
		return CommandResult.failure("send at least one")
	if unit_ids.size() > MAX_BODIES:
		return CommandResult.failure("no more than %d go" % MAX_BODIES)
	var seen: Dictionary = {}
	for id in unit_ids:
		if seen.has(id):
			return CommandResult.failure("the same person twice")
		seen[id] = true
		if id not in campaign.bench:
			return CommandResult.failure("%d is not on the bench" % id)
	if not Economy.leg_reaches_home(campaign, bowl_id):
		return CommandResult.failure("not enough fuel to get there and back: needs %d, have %d" % [
			Economy.leg_cost(campaign, bowl_id), campaign.fuel
		])
	return CommandResult.success()


func _apply(next: Campaign) -> Campaign:
	next.deployment = {"bowl": bowl_id, "ids": unit_ids.duplicate(), "hold_sluice": hold_sluice}
	Economy.pay_leg(next, bowl_id)
	next.dispatched_today = true
	return next
