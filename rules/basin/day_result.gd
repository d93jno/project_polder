class_name DayResult
extends RefCounted
## What a day did, as data (plan 07 §7.1). The morning read is drawn from this; nothing here is text.

var basin: Basin = null
## {id, from, to}: a step that landed overnight.
var moved: Array[Dictionary] = []
## {id, dir, in_days}: a step that began walking, readable from this morning.
var walks_started: Array[Dictionary] = []
## {id, count}: fields that went under and are ruined (GDD §4.3: "Mud kills fields").
var fields_ruined: Array[Dictionary] = []
## Pump ids that broke from neglect.
var pumps_broke: Array[String] = []
## {id, from, to}: upkeep states that changed.
var upkeep_changed: Array[Dictionary] = []

## The day's meal: {"ate": food eaten, "short": food the camp needed and did not have} (plan 09 §9.0).
var meal: Dictionary = {"ate": 0, "short": 0}

## The day's harvest: {"food": from bowls the player has walked, "unwalked": from bowls they have not,
## "fields": the Dry fields it came from} (plan 09 §9.1).
var harvest: Dictionary = {"food": 0, "unwalked": 0, "fields": 0}

## Scrap the workshop made, and what the fireteam brought home: {"scrap", "fuel"} (plan 09 §9.3).
var scrap_made: int = 0
var salvage: Dictionary = {}

## People who came to the camp and people who left it overnight (plan 09 §9.4).
var arrived: int = 0
var left: int = 0


func anything_moved() -> bool:
	return not (moved.is_empty() and walks_started.is_empty() and pumps_broke.is_empty() and upkeep_changed.is_empty() and fields_ruined.is_empty())
