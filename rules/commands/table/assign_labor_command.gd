class_name AssignLaborCommand
extends TableCommand
## Move hands from one bucket to another (plan 07 §7.2). Conserves people, and a table day only has so
## many of these (GDD §4.2: "a handful of assignments").

var from_bucket: Campaign.Bucket
var to_bucket: Campaign.Bucket
var hands: int


func _init(
	p_from: Campaign.Bucket = Campaign.Bucket.IDLE,
	p_to: Campaign.Bucket = Campaign.Bucket.IDLE,
	p_hands: int = 1,
) -> void:
	from_bucket = p_from
	to_bucket = p_to
	hands = p_hands


func validate(campaign: Campaign) -> CommandResult:
	if hands < 1:
		return CommandResult.failure("move at least one hand")
	if from_bucket == to_bucket:
		return CommandResult.failure("they are already there")
	if campaign.hands(from_bucket) < hands:
		return CommandResult.failure("not enough hands in %s" % _name(from_bucket))
	if campaign.assignments_today >= Campaign.ASSIGNMENTS_PER_DAY:
		return CommandResult.failure("a day has only %d assignments" % Campaign.ASSIGNMENTS_PER_DAY)
	return CommandResult.success()


func _apply(next: Campaign) -> Campaign:
	next.labor[from_bucket] = next.hands(from_bucket) - hands
	next.labor[to_bucket] = next.hands(to_bucket) + hands
	next.assignments_today += 1
	return next


static func _name(bucket: Campaign.Bucket) -> String:
	return str(Campaign.Bucket.keys()[bucket]).to_lower()
