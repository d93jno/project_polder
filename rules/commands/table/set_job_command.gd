class_name SetJobCommand
extends TableCommand
## A met, warm band takes a job: eyes, food, a name for the roster, or a warning (plan 10 §10.2, GDD §5.12).
## A change costs the table day (decision 7.6): the day's dispatch is spent, so no fireteam goes out. A
## Confirmed action, because the day cannot be taken back.

var band_id: String
var new_job: Band.Job


func _init(p_band_id: String = "", p_job: Band.Job = Band.Job.EYES) -> void:
	band_id = p_band_id
	new_job = p_job


func validate(campaign: Campaign) -> CommandResult:
	var why := Bands.why_not_job(campaign, band_id, new_job)
	if why != "":
		return CommandResult.failure(why)
	return CommandResult.success()


func needs_confirm(_campaign: Campaign) -> bool:
	return true


func _apply(next: Campaign) -> Campaign:
	Bands.set_job(next, band_id, new_job)
	next.dispatched_today = true
	return next
