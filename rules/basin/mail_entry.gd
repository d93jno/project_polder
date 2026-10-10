class_name MailEntry
extends RefCounted
## One report from a band's eyes (plan 10 §10.3, GDD §5.12): the bowl, what happened there, the morning
## it happened and the morning it reaches the table. It never says what stands in the bowl, and hearing
## it never makes the bowl known (decision 7.3).

enum Event { STEP_LANDED, WALK_BEGAN, PUMP_BROKE }

var band_id: String = ""
var bowl_id: String = ""
var event: Event = Event.STEP_LANDED
## STEP_LANDED: the step it left and the step it landed on (`WaterStep`); WALK_BEGAN: the `BasinBowl.Walk`
## direction in `to`. Unused otherwise.
var from: int = 0
var to: int = 0
var happened_day: int = 0
var arrives_day: int = 0


func _init(
	p_band: String = "", p_bowl: String = "", p_event: Event = Event.STEP_LANDED,
	p_happened: int = 0, p_arrives: int = 0, p_from: int = 0, p_to: int = 0,
) -> void:
	band_id = p_band
	bowl_id = p_bowl
	event = p_event
	happened_day = p_happened
	arrives_day = p_arrives
	from = p_from
	to = p_to


func duplicate_entry() -> MailEntry:
	return MailEntry.new(band_id, bowl_id, event, happened_day, arrives_day, from, to)
