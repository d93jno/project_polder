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
	return met


static func warm_count(campaign: Campaign) -> int:
	var n := 0
	for b in campaign.bands:
		if b.met() and b.warm:
			n += 1
	return n
