class_name Mail
extends Object
## Mail (plan 10 §10.3, GDD §5.12): what a warm band on the EYES job saw where it stood, reaching the table
## late. Pure and deterministic. A report is made on the morning the event shows, arrives
## `BasinRules.MAIL_LAG_DAYS` later, and radio (a flag nothing sets yet) removes the lag.


static func lag(campaign: Campaign) -> int:
	return 0 if campaign.radio else BasinRules.MAIL_LAG_DAYS


## The reports the day just closed produced, from the bands standing where they stood that day. Called
## after the day's result is known and before the new day is counted; `new_day` is the morning it opens.
static func read(campaign: Campaign, result: DayResult, new_day: int) -> Array[MailEntry]:
	var out: Array[MailEntry] = []
	for b in Bands.with_job(campaign, Band.Job.EYES):
		var bowl: String = b.bowl_id()
		var arrives := new_day + lag(campaign)
		for move in result.moved:
			if move["id"] == bowl:
				out.append(MailEntry.new(b.id, bowl, MailEntry.Event.STEP_LANDED, new_day, arrives, int(move["from"]), int(move["to"])))
		for walk in result.walks_started:
			if walk["id"] == bowl:
				out.append(MailEntry.new(b.id, bowl, MailEntry.Event.WALK_BEGAN, new_day, arrives, 0, int(walk["dir"])))
		if bowl in result.pumps_broke:
			out.append(MailEntry.new(b.id, bowl, MailEntry.Event.PUMP_BROKE, new_day, arrives))
	return out


## Moves entries that are due on `day` out of the inbox, oldest first, and returns them.
static func deliver(campaign: Campaign, day: int) -> Array[MailEntry]:
	var due: Array[MailEntry] = []
	var waiting: Array[MailEntry] = []
	for e in campaign.inbox:
		if e.arrives_day <= day:
			due.append(e)
		else:
			waiting.append(e)
	campaign.inbox = waiting
	return due
