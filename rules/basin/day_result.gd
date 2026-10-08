class_name DayResult
extends RefCounted
## What a day did, as data (plan 07 §7.1). The morning read is drawn from this; nothing here is text.

var basin: Basin = null
## {id, from, to}: a step that landed overnight.
var moved: Array[Dictionary] = []
## {id, dir, in_days}: a step that began walking, readable from this morning.
var walks_started: Array[Dictionary] = []
## Pump ids that broke from neglect.
var pumps_broke: Array[String] = []
## {id, from, to}: upkeep states that changed.
var upkeep_changed: Array[Dictionary] = []


func anything_moved() -> bool:
	return not (moved.is_empty() and walks_started.is_empty() and pumps_broke.is_empty() and upkeep_changed.is_empty())
