class_name Bands
extends Object
## The band rules (plan 10): who is authored, who is met, the cap per ring, who is warm. The one place a
## band's meeting, warmth, job or cause of cooling is assigned; a test reads every file and fails on any other.

const BowlOpenings := preload("res://rules/fixtures/bowl_openings.gd")


## The bands the basin's opening authors, unmet, standing at the start of their routes.
static func authored() -> Array[Band]:
	var out: Array[Band] = []
	for data in BowlOpenings.bands():
		var route: Array[String] = []
		for id in data["route"]:
			route.append(str(id))
		out.append(Band.new(str(data["id"]), data["job"] as Band.Job, route))
	return out


static func band(campaign: Campaign, id: String) -> Band:
	for b in campaign.bands:
		if b.id == id:
			return b
	return null


## Met bands standing in the same ring (grade) as `bowl_id`. A band counts toward the cap once met,
## warm or cold: a cold band is still a person in a place.
static func met_in_ring(campaign: Campaign, bowl_id: String) -> int:
	var grade: int = campaign.basin.bowl(bowl_id).grade
	var count := 0
	for b in campaign.bands:
		var band_bowl: BasinBowl = campaign.basin.bowl(b.bowl_id())
		if b.met() and band_bowl != null and int(band_bowl.grade) == grade:
			count += 1
	return count


## Why a band cannot be met now, or "" if it can: it is unmet, it stands in `bowl_id`, and its ring has room.
static func why_not_met(campaign: Campaign, b: Band, bowl_id: String) -> String:
	if b.met():
		return "already met"
	if b.bowl_id() != bowl_id:
		return "not there"
	if met_in_ring(campaign, bowl_id) >= BasinRules.BANDS_PER_RING:
		return "the ring holds no more bands"
	return ""


## Meet every unmet band standing in `bowl_id` that the cap allows, in authored order. They are warm
## and hold the job the opening authored. Returns the ids met.
static func meet_at(campaign: Campaign, bowl_id: String) -> Array[String]:
	var met: Array[String] = []
	for b in campaign.bands:
		if why_not_met(campaign, b, bowl_id) == "":
			b.met_day = campaign.day
			b.warm = true
			met.append(b.id)
	see(campaign)
	return met


static func warm_count(campaign: Campaign) -> int:
	var n := 0
	for b in campaign.bands:
		if b.met() and b.warm:
			n += 1
	return n


## Why a band cannot take `job` now, or "" if it can (plan 10 §10.2, decision 7.6): a job change is a
## table day, so it needs a day still to spend.
static func why_not_job(campaign: Campaign, id: String, job: Band.Job) -> String:
	var b := band(campaign, id)
	if b == null:
		return "no such band"
	if not b.met():
		return "you have not met them"
	if not b.warm:
		return "they have gone cold and take no work"
	if b.job == job:
		return "they already hold that job"
	if not campaign.deployment.is_empty():
		return "the fireteam is out"
	if campaign.dispatched_today:
		return "the day is spent"
	return ""


static func set_job(campaign: Campaign, id: String, job: Band.Job) -> void:
	var b := band(campaign, id)
	b.job = job
	b.name_given = false


## Warm, met bands holding `job`.
static func with_job(campaign: Campaign, job: Band.Job) -> Array[Band]:
	var out: Array[Band] = []
	for b in campaign.bands:
		if b.met() and b.warm and b.job == job:
			out.append(b)
	return out


## The NAME job: the first day a warm band holds it, one person comes to the roster, and the job is then
## spent. Returns the ids of the bands that gave one. The camp's people only change here, through labor.
static func call_names(campaign: Campaign) -> Array[String]:
	var given: Array[String] = []
	for b in with_job(campaign, Band.Job.NAME):
		if not b.name_given:
			b.name_given = true
			campaign.labor[Campaign.Bucket.ROSTER] = campaign.hands(Campaign.Bucket.ROSTER) + 1
			given.append(b.id)
	return given


## The bands move one bowl along their routes every `BAND_MOVE_DAYS` days (decision 7.5): a fixed, authored
## step, no dice. `new_day` is the morning that is opening.
static func move_on(campaign: Campaign, new_day: int) -> void:
	if new_day % BasinRules.BAND_MOVE_DAYS != 0:
		return
	for b in campaign.bands:
		if b.route.size() > 1:
			b.at = (b.at + 1) % b.route.size()


## A band goes cold, for a cause the table could have read beforehand (decision 7.4). Permanent: a map
## fact, not a bar.
static func cool(campaign: Campaign, b: Band, cause: String) -> Dictionary:
	b.warm = false
	b.cold_cause = cause
	b.cold_at = b.bowl_id()
	return {"band": b.id, "bowl": b.cold_at, "cause": cause}


## The flood: a met, warm band standing in a bowl a redirection still holds wetter than before goes cold.
## Run after the day's water is known, on the bands where they stand that day.
static func cool_flooded(campaign: Campaign) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in campaign.bands:
		if not (b.met() and b.warm):
			continue
		for r in campaign.redirections:
			if r.bowl_id == b.bowl_id() and r.hangs(campaign.basin):
				out.append(cool(campaign, b, "flood"))
				break
	return out


## The cache: taking what a bowl holds turns cold a band that stands there and was met before this
## fireteam arrived (a band met on this very trip has not yet been wronged). Call before `meet_at`.
static func cool_for_cache(campaign: Campaign, bowl_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in campaign.bands:
		if b.met() and b.warm and b.bowl_id() == bowl_id:
			out.append(cool(campaign, b, "cache"))
	return out


## Whom taking the cache at `bowl_id` would turn cold: the same rule, read without changing anything.
static func would_cool_for_cache(campaign: Campaign, bowl_id: String) -> Array[String]:
	var out: Array[String] = []
	if BowlOpenings.salvage(bowl_id).is_empty() or campaign.salvaged.has(bowl_id):
		return out
	for b in campaign.bands:
		if b.met() and b.warm and b.bowl_id() == bowl_id:
			out.append(b.id)
	return out


## The table sees a warm, met band wherever it stands on a bowl the player has walked: the dome reads it now
## (plan 4 §7.9). A band elsewhere is where it was last seen, and a cold band is not seen again, so its
## mark ages like any stale tile (plan 10 §10.5).
static func see(campaign: Campaign) -> void:
	for b in campaign.bands:
		if not (b.met() and b.warm):
			continue
		var bowl: BasinBowl = campaign.basin.bowl(b.bowl_id())
		if bowl != null and bowl.known:
			campaign.sightings[b.id] = {"bowl": b.bowl_id(), "day": campaign.day}
