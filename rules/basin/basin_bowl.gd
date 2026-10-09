class_name BasinBowl
extends RefCounted
## One bowl in the basin graph (plan 07 §7.0, GDD §6.1). Support, not litres: a step, a grade, a pump,
## a wear counter and the neighbours that feed it. A value: `duplicate_bowl` copies it.

enum Grade { RIM, FLOOR, SUMP }
enum Pump { ON, DAMAGED, DEAD }
enum Upkeep { KEPT, THIN, FAILING }
enum Walk { NONE, WETTER, DRIER }

var id: String
var grade: Grade = Grade.FLOOR
var step: Taxonomy.WaterStep = Taxonomy.WaterStep.FLOODED
var pump: Pump = Pump.ON
## Days in a row the pump went unposted. Upkeep is derived from it, so the two cannot drift.
var neglect: int = 0
## Ids of the neighbours that pour into this bowl.
var feeders: Array[String] = []
## Days per step this bowl walks wetter when its pump is dead (GDD §6.2: outer fast, inner slow).
var leak_days: int = 2
## A step in progress, so it can be read the day before it lands (GDD §6.1 knowability).
var walk: Walk = Walk.NONE
var walk_days_left: int = 0
## Days left that this bowl is held wet by a chosen redirection (GDD §6.4). Nothing dries it meanwhile.
var hang_days: int = 0
## What the player has on this bowl's dry tiles: a summary of GDD §4.3's tile states, not a tile map
## (plan 08 §7.2). Only the ones a redirection can drown. A ruined field stays ruined.
var fields: int = 0
var camps: int = 0
var posts: int = 0
var ruined: int = 0
var road: bool = false
## Walked before. An unvisited bowl reads as unknown, never as dry.
var known: bool = false
## Instruments are awake here, so the ring around it can be read. A plate reads only its own bowl.
var instrumented: bool = false


func _init(p_id: String = "") -> void:
	id = p_id


func upkeep() -> Upkeep:
	if pump == Pump.DEAD:
		return Upkeep.FAILING
	if neglect >= BasinRules.FAILING_AFTER_DAYS:
		return Upkeep.FAILING
	if neglect >= BasinRules.THIN_AFTER_DAYS:
		return Upkeep.THIN
	return Upkeep.KEPT


func duplicate_bowl() -> BasinBowl:
	var copy := BasinBowl.new(id)
	copy.grade = grade
	copy.step = step
	copy.pump = pump
	copy.neglect = neglect
	copy.feeders = feeders.duplicate()
	copy.leak_days = leak_days
	copy.walk = walk
	copy.walk_days_left = walk_days_left
	copy.hang_days = hang_days
	copy.fields = fields
	copy.camps = camps
	copy.posts = posts
	copy.ruined = ruined
	copy.road = road
	copy.known = known
	copy.instrumented = instrumented
	return copy
