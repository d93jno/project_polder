class_name Pressure
extends RefCounted
## The highland's pressure (plan 11 §11.0, GDD §3.2): a stage, advanced one at a time by a rule from how loud
## the town is. The loudness is never stored and never shown: it is a pure function of the people and the Dry
## fields (plan 9), so no query a table reads can expose it. Only `tick` changes the stage, and the stage
## never goes backwards ("a loud town cannot make itself unseen again by waiting", GDD §3.2).

enum Stage { NONE, WATCHING, SURVEYING, BUILDING }

var stage: Stage = Stage.NONE
## The morning the stage last changed; 0 before the first change.
var last_change_day: int = 0


func duplicate_pressure() -> Pressure:
	var copy := Pressure.new()
	copy.stage = stage
	copy.last_change_day = last_change_day
	return copy


## How loud the town is: its people, and what it has made of the dry ground. Hidden (GDD §3.2).
static func loudness_of(campaign: Campaign) -> int:
	var fields := 0
	for id in campaign.basin.order:
		var bowl: BasinBowl = campaign.basin.bowl(id)
		if bowl.step == Taxonomy.WaterStep.DRY:
			fields += bowl.fields
	return campaign.people() + fields * BasinRules.LOUDNESS_PER_FIELD


## The inner ring: the terrace and the floor ring around the ridge (GDD §3.2, Phase 3). Building waits on it.
static func inner_ring_dry(campaign: Campaign) -> bool:
	var any := false
	for id in campaign.basin.order:
		var bowl: BasinBowl = campaign.basin.bowl(id)
		if bowl.grade == BasinBowl.Grade.FLOOR:
			any = true
			if bowl.step != Taxonomy.WaterStep.DRY:
				return false
	return any


## Whether the town is loud enough, and the ground right, for the stage after `from`. Watching asks only for
## noise; surveying also asks for at least one field ("population plus at least one field"); building asks
## for the inner ring Dry as well.
static func ready_for(campaign: Campaign, next: Stage) -> bool:
	var loud := loudness_of(campaign)
	var has_field := false
	for id in campaign.basin.order:
		var bowl: BasinBowl = campaign.basin.bowl(id)
		if bowl.step == Taxonomy.WaterStep.DRY and bowl.fields > 0:
			has_field = true
	match next:
		Stage.WATCHING:
			return loud >= BasinRules.WATCH_AT
		Stage.SURVEYING:
			return loud >= BasinRules.SURVEY_AT and has_field
		Stage.BUILDING:
			return loud >= BasinRules.BUILD_AT and has_field and inner_ring_dry(campaign)
	return false


## Called once a morning, after the day is counted. One stage at most, and no sooner than
## `PRESSURE_STAGE_DAYS` after the last. Returns true if the stage changed.
func tick(campaign: Campaign) -> bool:
	if stage == Stage.BUILDING:
		return false
	if last_change_day > 0 and campaign.day - last_change_day < BasinRules.PRESSURE_STAGE_DAYS:
		return false
	var next := (int(stage) + 1) as Stage
	if not ready_for(campaign, next):
		return false
	stage = next
	last_change_day = campaign.day
	return true
