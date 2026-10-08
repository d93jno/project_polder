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
	copy.morning = morning
	return copy
