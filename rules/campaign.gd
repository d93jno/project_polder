class_name Campaign
extends RefCounted
## The table's state (plan 07 §7.2): the day, four plain counts, the people and where they work, the
## bench, and the basin. A value, like `CombatState`: commands return a new one and never edit the old.
## Labor is a short board of buckets, never individuals (GDD §4.3 anti-goals).

enum Bucket {
	IDLE, ## Hands not posted to anything. Not a job, and never a bar.
	PUMPS, ## Pumps and ring watch: keeps a held bowl from walking back
	POSTS, ## Overwatch posts: dry sightlines on roofs and rims
	RESEARCH, ## Hands in the old instrument halls
	WORKSHOP, ## Workshop and dredge
	FIELDS, ## The food engine
	ROSTER, ## More names, not automatically better soldiers
}

## A table day is a handful of assignments plus one dispatch or none (GDD §4.2). Working default.
const ASSIGNMENTS_PER_DAY := 3
## Keeping one pump takes one hand and one scrap a day (GDD §6.2: "posted hands + scrap").
const HANDS_PER_POST := 1
const SCRAP_PER_POST := 1

var day: int = 1
var food: int = 0
var fuel: int = 0
var scrap: int = 0
## Hands in each bucket. The sum is always the people in the camp: assigning moves hands, it never
## makes or loses one (a death is a recorded event of its own, not an assignment).
var labor: Dictionary = {}
## Unit ids of the people who can be sent out. Dispatch takes up to four (plan 07 §7.3).
var bench: Array[int] = []
var basin: Basin = null
var assignments_today: int = 0
var dispatched_today: bool = false
## The fireteam that is out: {"bowl": String, "ids": Array[int]}. Empty while everyone is home.
var deployment: Dictionary = {}
## Every redirection the player has chosen, and the bowls whose first-contact card is spent (plan 08 §8.2).
var redirections: Array[Redirection] = []
var cards_spent: Dictionary = {} ## bowl id -> true
## Bowls whose cache the fireteam has already brought home (plan 09 §9.3): there is no infinite well.
var salvaged: Dictionary = {} ## bowl id -> true
## Every band in the basin, met or not (plan 10): truth lives here; what the player last saw of each is the
## store's `facts` layer.
var bands: Array[Band] = []
## What the last Day end did, as data: the morning read draws from this.
var morning: DayResult = null


func _init() -> void:
	for bucket in Bucket.values():
		labor[bucket] = 0


func people() -> int:
	var total := 0
	for bucket in labor:
		total += int(labor[bucket])
	return total


func hands(bucket: Bucket) -> int:
	return int(labor.get(bucket, 0))


## Which pumps the hands and scrap reach today, as bowl id -> true. Hands are not clicked onto pumps
## one by one (GDD §4.3): they go where the wear is, the most neglected first, and only to a bowl that
## has been walked and whose pump still runs. Scrap short means fewer posts.
func posted_pumps() -> Dictionary:
	var candidates: Array[BasinBowl] = []
	for id in basin.order:
		var bowl: BasinBowl = basin.bowl(id)
		if bowl.known and bowl.pump != BasinBowl.Pump.DEAD:
			candidates.append(bowl)
	var order := basin.order
	candidates.sort_custom(func(a: BasinBowl, b: BasinBowl) -> bool:
		if a.neglect != b.neglect:
			return a.neglect > b.neglect
		return order.find(a.id) < order.find(b.id)
	)
	var by_hands := hands(Bucket.PUMPS) / HANDS_PER_POST
	var by_scrap := scrap / SCRAP_PER_POST
	var count := mini(mini(by_hands, by_scrap), candidates.size())
	var posted := {}
	for i in count:
		posted[candidates[i].id] = true
	return posted


## How many pumps the hands could reach tonight that the scrap cannot (plan 09 §9.3): readable before the
## day is ended, so a pump going unkept for want of scrap is never a surprise.
func pumps_scrap_cannot_keep() -> int:
	var live := 0
	for id in basin.order:
		var bowl: BasinBowl = basin.bowl(id)
		if bowl.known and bowl.pump != BasinBowl.Pump.DEAD:
			live += 1
	var wanted := mini(hands(Bucket.PUMPS) / HANDS_PER_POST, live)
	return wanted - posted_pumps().size()


## Someone leaves the camp (plan 09 §9.4). Idle hands go first, then the least-posted buckets in a
## fixed order; the roster never walks away, because the bench is named people. False if there is no one
## who can go.
func lose_leaver() -> bool:
	for bucket in [Bucket.IDLE, Bucket.WORKSHOP, Bucket.RESEARCH, Bucket.POSTS, Bucket.FIELDS, Bucket.PUMPS]:
		if hands(bucket) > 0:
			labor[bucket] = hands(bucket) - 1
			return true
	return false


## One person is gone: a roster death shrinks the pool (GDD §4.2). Taken from the roster first, then
## wherever hands are idle, then from the rest in a fixed order, so it is always the same person.
func lose_person() -> void:
	for bucket in [
		Bucket.ROSTER, Bucket.IDLE, Bucket.POSTS, Bucket.WORKSHOP, Bucket.RESEARCH, Bucket.FIELDS, Bucket.PUMPS,
	]:
		if hands(bucket) > 0:
			labor[bucket] = hands(bucket) - 1
			return


## The day closes: pumps are posted, scrap is spent, the basin ticks and the next morning opens with
## what moved. Call it on a campaign you own. Day end and the way home both end a day through here.
func close_day() -> void:
	var posted := posted_pumps()
	Economy.post_pumps(self, posted)
	var result := BasinDay.end(basin, posted)
	basin = result.basin
	Economy.work(self, result)
	Economy.harvest(self, result)
	Economy.eat(self, result)
	Economy.follow_the_water(self, result)
	morning = result
	day += 1
	assignments_today = 0
	dispatched_today = false


func duplicate_campaign() -> Campaign:
	var copy := Campaign.new()
	copy.day = day
	copy.food = food
	copy.fuel = fuel
	copy.scrap = scrap
	copy.labor = labor.duplicate()
	copy.bench = bench.duplicate()
	copy.basin = basin.duplicate_basin() if basin != null else null
	copy.assignments_today = assignments_today
	copy.dispatched_today = dispatched_today
	copy.deployment = deployment.duplicate(true)
	for r in redirections:
		copy.redirections.append(r.duplicate_redirection())
	copy.cards_spent = cards_spent.duplicate()
	copy.salvaged = salvaged.duplicate()
	for b in bands:
		copy.bands.append(b.duplicate_band())
	copy.morning = morning
	return copy
