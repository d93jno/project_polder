class_name RedirectionPreview
extends Object
## What a redirection would do, read before it is spent (plan 08 §8.3, GDD §6.4, UI §8). It is the rule
## run, not a second rule: the campaign is copied, the redirection is recorded through
## `Redirection.record`, the days are ticked through `Campaign.close_day` under the current labor plan,
## and the result is diffed against the same days with no redirection. It changes nothing.
##
## It names only bowls the player has walked. Creep into a bowl they have not is a count and a line,
## never a name. Precision follows the instruments (decision 7.3): exact where every bowl it affects
## has them, otherwise a range one day wider for each affected bowl that does not, and `is_range`.

const DEFAULT_HORIZON_DAYS := 14


static func read(campaign: Campaign, bowl_id: String, horizon_days: int = DEFAULT_HORIZON_DAYS) -> Dictionary:
	var bowl: BasinBowl = campaign.basin.bowl(bowl_id)
	if bowl == null:
		return {"ok": false, "reason": "no such bowl"}
	if bowl.step == Taxonomy.WaterStep.FLOODED:
		return {"ok": false, "reason": "the water is already as deep as it goes"}
	var to_step := BasinRules.wetter(bowl.step)
	var with := campaign.duplicate_campaign()
	var without := campaign.duplicate_campaign()
	Redirection.record(with, bowl_id, to_step)
	var track := {}
	var food_lost := 0
	_observe(0, with, without, track)
	for day in range(1, horizon_days + 1):
		with.close_day()
		without.close_day()
		_observe(day, with, without, track)
		## Food the walked fields would have brought in and did not (plan 09 §9.1); counts, not a rate.
		food_lost += int(without.morning.harvest["food"]) - int(with.morning.harvest["food"])
	var result := _result(campaign, bowl_id, to_step, horizon_days, with, without, track)
	result["food_lost"] = food_lost
	return result


## Per bowl: the days it stood wetter than it would have, how much wetter at worst, and where.
static func _observe(day: int, with: Campaign, without: Campaign, track: Dictionary) -> void:
	for id in with.basin.ids():
		var a: BasinBowl = with.basin.bowl(id)
		var b: BasinBowl = without.basin.bowl(id)
		var extra := int(b.step) - int(a.step)
		if extra <= 0:
			continue
		if not track.has(id):
			track[id] = {"last_day": 0, "extra": 0, "peak": a.step}
		var t: Dictionary = track[id]
		t["last_day"] = day
		if extra > int(t["extra"]):
			t["extra"] = extra
		if int(a.step) < int(t["peak"]):
			t["peak"] = a.step


static func _result(
	campaign: Campaign, bowl_id: String, to_step: Taxonomy.WaterStep, horizon: int,
	with: Campaign, without: Campaign, track: Dictionary
) -> Dictionary:
	var distance := _distances(campaign.basin, bowl_id)
	var named: Array[Dictionary] = []
	var unknown := 0
	var beyond_first := false
	var creeps := false
	for id in campaign.basin.ids():
		if not track.has(id):
			continue
		var d: int = distance.get(id, 99)
		if d >= 1:
			creeps = true
		if d >= 2:
			beyond_first = true
		var bowl: BasinBowl = campaign.basin.bowl(id)
		if not bowl.known:
			unknown += 1
			continue
		var t: Dictionary = track[id]
		named.append({
			"id": id,
			"distance": d,
			"now": bowl.step,
			"peak": t["peak"],
			"steps_wetter": maxi(int(bowl.step) - int(t["peak"]), 0),
			"set_back": t["extra"],
			"hang_days": t["last_day"],
			"beyond_horizon": t["last_day"] >= horizon,
			"instrumented": bowl.instrumented,
			"stands": {
				"fields": bowl.fields, "camps": bowl.camps, "posts": bowl.posts, "road": bowl.road,
				"fields_lost": with.basin.bowl(id).ruined - without.basin.bowl(id).ruined,
			},
		})
	var order := campaign.basin.order
	named.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["distance"] != b["distance"]:
			return int(a["distance"]) < int(b["distance"])
		return order.find(a["id"]) < order.find(b["id"])
	)
	var lacking := 0
	for entry in named:
		if not entry["instrumented"]:
			lacking += 1
	## Exact where every affected bowl has instruments; otherwise one day wider for each that does not.
	for entry in named:
		entry["hang_days_min"] = entry["hang_days"]
		var wider: int = lacking if entry["id"] == bowl_id else (0 if entry["instrumented"] else 1)
		entry["hang_days_max"] = entry["hang_days"] + wider
	return {
		"ok": true,
		"bowl": bowl_id,
		"from": campaign.basin.bowl(bowl_id).step,
		"to": to_step,
		"horizon_days": horizon,
		"bowls": named,
		"creeps": creeps,
		"beyond_first": beyond_first,
		"unknown_reached": unknown,
		"is_range": lacking > 0,
	}


## How many bowls downstream each bowl is from `start`, following who feeds whom: the bowls `start`
## feeds are 1, the bowls those feed are 2.
static func _distances(basin: Basin, start: String) -> Dictionary:
	var distance := {start: 0}
	var frontier: Array[String] = [start]
	while not frontier.is_empty():
		var next: Array[String] = []
		for source in frontier:
			for id in basin.ids():
				if distance.has(id):
					continue
				if source in basin.bowl(id).feeders:
					distance[id] = int(distance[source]) + 1
					next.append(id)
		frontier = next
	return distance
