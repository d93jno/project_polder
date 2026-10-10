class_name CampaignCodec
extends Object
## The campaign as plain data and back (plan 07 §7.5). JSON turns every number into a float, so every
## integer and enum is read back through `int()`. A damaged record gives null, never a crash.


static func to_dict(campaign: Campaign) -> Dictionary:
	var labor := {}
	for bucket in campaign.labor:
		labor[str(int(bucket))] = int(campaign.labor[bucket])
	var bowls: Array = []
	for id in campaign.basin.ids():
		var b: BasinBowl = campaign.basin.bowl(id)
		bowls.append({
			"id": b.id, "grade": int(b.grade), "step": int(b.step), "pump": int(b.pump),
			"neglect": b.neglect, "feeders": b.feeders.duplicate(), "leak_days": b.leak_days,
			"walk": int(b.walk), "walk_days_left": b.walk_days_left, "hang_days": b.hang_days,
			"known": b.known, "instrumented": b.instrumented,
			"fields": b.fields, "camps": b.camps, "posts": b.posts, "ruined": b.ruined, "road": b.road,
		})
	return {
		"day": campaign.day, "food": campaign.food, "fuel": campaign.fuel, "scrap": campaign.scrap,
		"labor": labor, "bench": campaign.bench.duplicate(),
		"assignments_today": campaign.assignments_today, "dispatched_today": campaign.dispatched_today,
		"deployment": campaign.deployment.duplicate(true),
		"basin": bowls,
		"morning": _morning_to_dict(campaign.morning),
		"redirections": _redirections_to_array(campaign),
		"cards_spent": campaign.cards_spent.keys(),
		"salvaged": campaign.salvaged.keys(),
	}


static func from_dict(data: Dictionary) -> Campaign:
	for key in ["day", "food", "fuel", "scrap", "labor", "bench", "basin"]:
		if not data.has(key):
			return null
	if typeof(data["labor"]) != TYPE_DICTIONARY or typeof(data["bench"]) != TYPE_ARRAY \
			or typeof(data["basin"]) != TYPE_ARRAY:
		return null
	var campaign := Campaign.new()
	campaign.day = int(data["day"])
	campaign.food = int(data["food"])
	campaign.fuel = int(data["fuel"])
	campaign.scrap = int(data["scrap"])
	for key in data["labor"]:
		var bucket := int(key)
		if bucket < 0 or bucket >= Campaign.Bucket.size():
			return null
		campaign.labor[bucket] = int(data["labor"][key])
	for id in data["bench"]:
		campaign.bench.append(int(id))
	campaign.assignments_today = int(data.get("assignments_today", 0))
	campaign.dispatched_today = bool(data.get("dispatched_today", false))
	if typeof(data.get("deployment")) == TYPE_DICTIONARY and not (data["deployment"] as Dictionary).is_empty():
		var out: Dictionary = data["deployment"]
		var ids: Array[int] = []
		for id in out.get("ids", []):
			ids.append(int(id))
		campaign.deployment = {"bowl": str(out.get("bowl", "")), "ids": ids, "hold_sluice": bool(out.get("hold_sluice", false))}
	var basin := Basin.new()
	for raw in data["basin"]:
		if typeof(raw) != TYPE_DICTIONARY or not (raw as Dictionary).has("id"):
			return null
		var bowl := BasinBowl.new(str(raw["id"]))
		bowl.grade = int(raw.get("grade", 1)) as BasinBowl.Grade
		bowl.step = int(raw.get("step", 0)) as Taxonomy.WaterStep
		bowl.pump = int(raw.get("pump", 0)) as BasinBowl.Pump
		bowl.neglect = int(raw.get("neglect", 0))
		for feeder in raw.get("feeders", []):
			bowl.feeders.append(str(feeder))
		bowl.leak_days = int(raw.get("leak_days", 2))
		bowl.walk = int(raw.get("walk", 0)) as BasinBowl.Walk
		bowl.walk_days_left = int(raw.get("walk_days_left", 0))
		bowl.hang_days = int(raw.get("hang_days", 0))
		bowl.known = bool(raw.get("known", false))
		bowl.instrumented = bool(raw.get("instrumented", false))
		bowl.fields = int(raw.get("fields", 0))
		bowl.camps = int(raw.get("camps", 0))
		bowl.posts = int(raw.get("posts", 0))
		bowl.ruined = int(raw.get("ruined", 0))
		bowl.road = bool(raw.get("road", false))
		basin.add_bowl(bowl)
	campaign.basin = basin
	for raw in data.get("redirections", []):
		if typeof(raw) == TYPE_DICTIONARY and (raw as Dictionary).has("bowl"):
			campaign.redirections.append(Redirection.new(
				str(raw["bowl"]), int(raw.get("day", 0)),
				int(raw.get("from", 0)) as Taxonomy.WaterStep, int(raw.get("to", 0)) as Taxonomy.WaterStep,
				bool(raw.get("first_contact", false)),
			))
	for id in data.get("cards_spent", []):
		campaign.cards_spent[str(id)] = true
	for id in data.get("salvaged", []):
		campaign.salvaged[str(id)] = true
	campaign.morning = _morning_from_dict(data.get("morning"), basin)
	return campaign


static func _redirections_to_array(campaign: Campaign) -> Array:
	var out: Array = []
	for r in campaign.redirections:
		out.append({
			"bowl": r.bowl_id, "day": r.day, "from": int(r.from_step), "to": int(r.to_step),
			"first_contact": r.first_contact,
		})
	return out


static func _morning_to_dict(result: DayResult) -> Dictionary:
	if result == null:
		return {}
	var moved: Array = []
	for m in result.moved:
		moved.append({"id": m["id"], "from": int(m["from"]), "to": int(m["to"])})
	var started: Array = []
	for w in result.walks_started:
		started.append({"id": w["id"], "dir": int(w["dir"]), "in_days": int(w["in_days"])})
	var upkeep: Array = []
	for u in result.upkeep_changed:
		upkeep.append({"id": u["id"], "from": int(u["from"]), "to": int(u["to"])})
	var ruined: Array = []
	for r in result.fields_ruined:
		ruined.append({"id": r["id"], "count": int(r["count"])})
	return {"moved": moved, "walks_started": started, "pumps_broke": result.pumps_broke.duplicate(), "upkeep_changed": upkeep, "fields_ruined": ruined,
		"meal": result.meal.duplicate(), "harvest": result.harvest.duplicate(),
		"scrap_made": result.scrap_made, "salvage": result.salvage.duplicate(),
	}


static func _morning_from_dict(raw: Variant, basin: Basin) -> DayResult:
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
		return null
	var result := DayResult.new()
	result.basin = basin
	for m in raw.get("moved", []):
		result.moved.append({"id": str(m["id"]), "from": int(m["from"]) as Taxonomy.WaterStep, "to": int(m["to"]) as Taxonomy.WaterStep})
	for w in raw.get("walks_started", []):
		result.walks_started.append({"id": str(w["id"]), "dir": int(w["dir"]) as BasinBowl.Walk, "in_days": int(w["in_days"])})
	for id in raw.get("pumps_broke", []):
		result.pumps_broke.append(str(id))
	for r in raw.get("fields_ruined", []):
		result.fields_ruined.append({"id": str(r["id"]), "count": int(r["count"])})
	for u in raw.get("upkeep_changed", []):
		result.upkeep_changed.append({"id": str(u["id"]), "from": int(u["from"]) as BasinBowl.Upkeep, "to": int(u["to"]) as BasinBowl.Upkeep})
	for key in ["meal", "harvest", "salvage"]:
		var kept = raw.get(key)
		if typeof(kept) == TYPE_DICTIONARY:
			var fresh: Dictionary = {}
			for k in kept:
				fresh[str(k)] = int(kept[k])
			result.set(key, fresh)
	result.scrap_made = int(raw.get("scrap_made", 0))
	return result
