class_name WaterGraph
extends Object
## What the player may know of a bowl (plan 07 §7.0, GDD §6.1 "Knowability"). A bowl that changes with
## no way to have seen it coming is a design bug, so this is the one read the surface may draw from.
##
## A plate reports its own machine and its own bowl, never the ring. Feeders, and which of them still
## pour, appear only where the instruments are awake. A bowl nobody has visited is unknown.


static func read(basin: Basin, id: String) -> Dictionary:
	var bowl: BasinBowl = basin.bowl(id)
	if bowl == null or not bowl.known:
		return {"id": id, "known": false}
	var out := {
		"id": id,
		"known": true,
		"grade": bowl.grade,
		"step": bowl.step,
		"pump": bowl.pump,
		"upkeep": bowl.upkeep(),
		"walking": bowl.walk,
		"eta_days": bowl.walk_days_left if bowl.walk != BasinBowl.Walk.NONE else 0,
		"instrumented": bowl.instrumented,
	}
	if bowl.instrumented:
		var feeders: Array = []
		for feeder_id in bowl.feeders:
			var feeder: BasinBowl = basin.bowl(feeder_id)
			if feeder == null:
				continue
			## A feeder pours while it stands as wet as this bowl or wetter.
			feeders.append({"id": feeder_id, "pouring": int(feeder.step) <= int(bowl.step)})
		out["feeders"] = feeders
	return out
