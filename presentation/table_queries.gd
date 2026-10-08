extends RefCounted
## Pure reads for the table (plan 07 §7.4). The view draws these fields only: it computes no water,
## upkeep, posting or dispatch rule of its own, and every word comes from `rules/` through here.
## Preloaded, not class_named, like `overlay_queries.gd`.

const BowlOpenings := preload("res://rules/fixtures/bowl_openings.gd")

## One card per bowl, in the basin's authored order.
var cards: Array[Dictionary] = []
## {from, to, pouring}: only where instruments show the ring (a plate never reads past its own bowl).
var edges: Array[Dictionary] = []
var currencies: String = ""
var people: String = ""
## {bucket, name, hands}
var labor: Array[Dictionary] = []
var assignments_left: String = ""
var morning: Array[String] = []
var day_label: String = ""
## The dispatch slot: leads with the bowl, then the bodies (UI §8).
var dispatch: Dictionary = {}
var day_end_text: String = ""


static func compute(campaign: Campaign, selected_bowl: String, chosen: Array[int]):
	var q = load("res://presentation/table_queries.gd").new()
	q.day_label = "day %d" % campaign.day
	q.currencies = "food %d · fuel %d · scrap %d" % [campaign.food, campaign.fuel, campaign.scrap]
	q.people = "%d people" % campaign.people()
	for bucket in Campaign.Bucket.values():
		q.labor.append({"bucket": bucket, "name": bucket_name(bucket), "hands": campaign.hands(bucket)})
	var left := Campaign.ASSIGNMENTS_PER_DAY - campaign.assignments_today
	q.assignments_left = "%d assignment%s left today" % [left, "" if left == 1 else "s"]
	for id in campaign.basin.ids():
		var read := WaterGraph.read(campaign.basin, id)
		var bowl: BasinBowl = campaign.basin.bowl(id)
		q.cards.append(_card(read, bowl))
		if read.get("known", false) and read.has("feeders"):
			for feeder in read["feeders"]:
				q.edges.append({"from": feeder["id"], "to": id, "pouring": feeder["pouring"]})
	q.morning = _morning(campaign)
	q.dispatch = _dispatch(campaign, selected_bowl, chosen)
	q.day_end_text = "end day %d" % campaign.day
	return q


static func bucket_name(bucket: Campaign.Bucket) -> String:
	match bucket:
		Campaign.Bucket.IDLE:
			return "idle"
		Campaign.Bucket.PUMPS:
			return "pumps and ring watch"
		Campaign.Bucket.POSTS:
			return "overwatch posts"
		Campaign.Bucket.RESEARCH:
			return "research"
		Campaign.Bucket.WORKSHOP:
			return "workshop and dredge"
		Campaign.Bucket.FIELDS:
			return "fields"
		_:
			return "roster"


static func step_word(step: Taxonomy.WaterStep) -> String:
	return str(Taxonomy.WaterStep.keys()[step]).to_lower()


static func _card(read: Dictionary, bowl: BasinBowl) -> Dictionary:
	## A bowl nobody has walked is a black box with no data: unknown, never dry.
	if not read["known"]:
		return {"id": bowl.id, "known": false, "grade": bowl.grade, "lines": ["unknown"]}
	var lines: Array[String] = []
	lines.append("%s · %s" % [step_word(read["step"]), str(BasinBowl.Grade.keys()[read["grade"]]).to_lower()])
	lines.append(_pump_line(read))
	if read["walking"] != BasinBowl.Walk.NONE:
		var way := "wetter" if read["walking"] == BasinBowl.Walk.WETTER else "drier"
		var days: int = read["eta_days"]
		lines.append("walking %s in %d day%s" % [way, days, "" if days == 1 else "s"])
	if bowl.hang_days > 0:
		lines.append("held wet, %d day%s" % [bowl.hang_days, "" if bowl.hang_days == 1 else "s"])
	if read["instrumented"]:
		for feeder in read["feeders"]:
			lines.append("%s %s" % [feeder["id"], "pours in" if feeder["pouring"] else "is not pouring"])
	return {
		"id": bowl.id, "known": true, "grade": bowl.grade, "step": read["step"], "lines": lines,
		"instrumented": read["instrumented"],
	}


static func _pump_line(read: Dictionary) -> String:
	var pump: String = str(BasinBowl.Pump.keys()[read["pump"]]).to_lower()
	if read["pump"] == BasinBowl.Pump.DEAD:
		return "pump dead"
	return "pump %s, %s" % [pump, str(BasinBowl.Upkeep.keys()[read["upkeep"]]).to_lower()]


## What moved overnight, on bowls the player knows. A bowl they have not walked tells them nothing.
static func _morning(campaign: Campaign) -> Array[String]:
	var out: Array[String] = []
	var result := campaign.morning
	if result == null:
		return out
	for move in result.moved:
		if _known(campaign, move["id"]):
			out.append("%s: %s to %s" % [move["id"], step_word(move["from"]), step_word(move["to"])])
	for walk in result.walks_started:
		if _known(campaign, walk["id"]):
			var way := "wetter" if walk["dir"] == BasinBowl.Walk.WETTER else "drier"
			out.append("%s begins to walk %s, %d day%s" % [
				walk["id"], way, walk["in_days"], "" if walk["in_days"] == 1 else "s"
			])
	for id in result.pumps_broke:
		if _known(campaign, id):
			out.append("%s: the pump broke" % id)
	for change in result.upkeep_changed:
		if _known(campaign, change["id"]):
			out.append("%s: pump now %s" % [change["id"], str(BasinBowl.Upkeep.keys()[change["to"]]).to_lower()])
	return out


static func _known(campaign: Campaign, id: String) -> bool:
	var bowl: BasinBowl = campaign.basin.bowl(id)
	return bowl != null and bowl.known


static func _dispatch(campaign: Campaign, bowl_id: String, chosen: Array[int]) -> Dictionary:
	var out := {"bowl": bowl_id, "bench": campaign.bench.duplicate(), "chosen": chosen.duplicate()}
	if not campaign.deployment.is_empty():
		out["out"] = "the fireteam is out at %s" % campaign.deployment["bowl"]
		out["ok"] = false
		out["reason"] = "the fireteam is out"
		return out
	if bowl_id.is_empty():
		out["ok"] = false
		out["reason"] = "choose a bowl"
		return out
	var check := DispatchCommand.new(bowl_id, chosen).validate(campaign)
	out["ok"] = check.ok
	out["reason"] = check.reason
	var read := WaterGraph.read(campaign.basin, bowl_id)
	## The dispatch leads with the bowl: its water, its grade, the reach to it (plan 07 §7.4).
	if read.get("known", false):
		out["bowl_lines"] = _card(read, campaign.basin.bowl(bowl_id))["lines"]
	out["has_map"] = BowlOpenings.has_map(bowl_id)
	return out
