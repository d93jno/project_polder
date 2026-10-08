class_name BasinDay
extends Object
## The day tick (plan 07 §7.1, GDD §6.1, §6.2). Pure and deterministic: no randomness, a new basin out,
## the old one untouched. Every bowl is computed from the *previous* day's snapshot, so the order the
## bowls are visited in cannot matter.
##
## A step never lands the day it starts. It begins walking (readable that morning, with its days), and
## lands on a later tick; that is how "a bowl that changes with no way to have seen it coming is a
## design bug" becomes something a test can hold.


## `posted` maps a pump's bowl id to whether hands and scrap were posted to it today.
static func end(basin: Basin, posted: Dictionary = {}) -> DayResult:
	var result := DayResult.new()
	var next := basin.duplicate_basin()
	result.basin = next
	for id in basin.order:
		var prev: BasinBowl = basin.bowl(id)
		var now: BasinBowl = next.bowl(id)
		_wear(prev, now, bool(posted.get(id, false)), result)
		_water(basin, prev, now, result)
	return result


static func _wear(prev: BasinBowl, now: BasinBowl, posted_today: bool, result: DayResult) -> void:
	if prev.pump == BasinBowl.Pump.DEAD:
		return
	var upkeep_before := prev.upkeep()
	now.neglect = 0 if posted_today else prev.neglect + 1
	if now.neglect >= BasinRules.BREAKS_AFTER_DAYS:
		now.pump = BasinBowl.Pump.DEAD
		result.pumps_broke.append(prev.id)
	if now.upkeep() != upkeep_before:
		result.upkeep_changed.append({"id": prev.id, "from": upkeep_before, "to": now.upkeep()})


static func _water(basin: Basin, prev: BasinBowl, now: BasinBowl, result: DayResult) -> void:
	now.hang_days = maxi(prev.hang_days - 1, 0)
	var want := _want(basin, prev, now.pump)
	if want == BasinBowl.Walk.NONE:
		now.walk = BasinBowl.Walk.NONE
		now.walk_days_left = 0
		return
	if prev.walk == want:
		now.walk_days_left = prev.walk_days_left - 1
		if now.walk_days_left <= 0:
			now.step = (
				BasinRules.wetter(prev.step) if want == BasinBowl.Walk.WETTER else BasinRules.drier(prev.step)
			)
			now.walk = BasinBowl.Walk.NONE
			now.walk_days_left = 0
			result.moved.append({"id": prev.id, "from": prev.step, "to": now.step})
		return
	now.walk = want
	now.walk_days_left = prev.leak_days if want == BasinBowl.Walk.WETTER else BasinRules.DRY_DAYS
	result.walks_started.append({"id": prev.id, "dir": want, "in_days": now.walk_days_left})


## Which way this bowl is walking, if any, given the previous day's neighbours and its pump today.
static func _want(basin: Basin, prev: BasinBowl, pump_now: BasinBowl.Pump) -> BasinBowl.Walk:
	if pump_now == BasinBowl.Pump.DEAD:
		if prev.step == Taxonomy.WaterStep.FLOODED:
			return BasinBowl.Walk.NONE
		## The late leak cap: one ignored pump walks Dry to Mud and stops while the ring holds.
		if _ring_holds(basin, prev) and int(prev.step) <= int(BasinRules.LEAK_CAP_STEP):
			return BasinBowl.Walk.NONE
		return BasinBowl.Walk.WETTER
	if pump_now == BasinBowl.Pump.ON and prev.step != Taxonomy.WaterStep.DRY and prev.hang_days <= 0 \
			and _feeders_dry_enough(basin, prev):
		return BasinBowl.Walk.DRIER
	return BasinBowl.Walk.NONE


## At least half the ring still has a working pump. A bowl with no feeders holds by itself.
static func _ring_holds(basin: Basin, bowl: BasinBowl) -> bool:
	if bowl.feeders.is_empty():
		return true
	var alive := 0
	for feeder_id in bowl.feeders:
		var feeder: BasinBowl = basin.bowl(feeder_id)
		if feeder != null and feeder.pump != BasinBowl.Pump.DEAD:
			alive += 1
	return alive * 2 >= bowl.feeders.size()


## Enough feeders already stand as dry as this bowl is about to: a bowl cannot be drier than the water
## pouring into it. One hero pump in a hole in the ring makes a whirlpool, not a dry street (GDD §6.1).
static func _feeders_dry_enough(basin: Basin, bowl: BasinBowl) -> bool:
	var needed := mini(BasinRules.FEEDERS_NEEDED_TO_DRY, bowl.feeders.size())
	var target := int(BasinRules.drier(bowl.step))
	var dry := 0
	for feeder_id in bowl.feeders:
		var feeder: BasinBowl = basin.bowl(feeder_id)
		if feeder != null and int(feeder.step) >= target:
			dry += 1
	return dry >= needed
