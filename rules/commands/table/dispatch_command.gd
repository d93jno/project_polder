class_name DispatchCommand
extends TableCommand
## Send up to four from the bench to one bowl (plan 07 §7.3, GDD §4.2). Only marks them out: the fight
## itself is the tactical layer's, built by `TableDispatch.build_fight`, and `HomeCommand` brings them back.

const BowlOpenings := preload("res://rules/fixtures/bowl_openings.gd")
const MAX_BODIES := 4

var bowl_id: String
var unit_ids: Array[int]


func _init(p_bowl_id: String = "", p_unit_ids: Array[int] = []) -> void:
	bowl_id = p_bowl_id
	unit_ids = p_unit_ids


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
	return CommandResult.success()


func _apply(next: Campaign) -> Campaign:
	next.deployment = {"bowl": bowl_id, "ids": unit_ids.duplicate()}
	next.dispatched_today = true
	return next
