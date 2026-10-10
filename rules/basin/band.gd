class_name Band
extends RefCounted
## A band: a group of nomads, a person in a place with one job (plan 10, GDD §5.12). Never a meter: it is
## met or not, warm or cold, and holds one job. `Bands` is the one place any of that changes.

enum Job { EYES, FOOD, NAME, WARN }

var id: String = ""
var job: Job = Job.EYES
## The bowls it moves along, in order, and where on the route it stands now (decision 7.5: a fixed
## authored route, no dice). A band of one bowl never moves.
var route: Array[String] = []
var at: int = 0
## 0 while unmet; the day it was met otherwise.
var met_day: int = 0
var warm: bool = true
## Why it went cold, empty while it has not: "flood" or "cache" (decision 7.4).
var cold_cause: String = ""
## True once its NAME job has put a person on the bench: that job is spent (plan 10 §10.2).
var name_given: bool = false


func _init(p_id: String = "", p_job: Job = Job.EYES, p_route: Array[String] = []) -> void:
	id = p_id
	job = p_job
	route = p_route


func bowl_id() -> String:
	return route[at] if not route.is_empty() else ""


func met() -> bool:
	return met_day > 0


func duplicate_band() -> Band:
	var copy := Band.new(id, job, route.duplicate())
	copy.at = at
	copy.met_day = met_day
	copy.warm = warm
	copy.cold_cause = cold_cause
	copy.name_given = name_given
	return copy
