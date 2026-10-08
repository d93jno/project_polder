extends Node
## The flow between the two modes (plan 07 §7.5, GDD §3.1): dispatch leaves the table for the fight, the
## fight's end brings the squad home to the table. There is no button that swaps modes mid-mission.
## It owns the campaign between scenes and the save; the fight and the table own nothing of each other.
##
## The save is written when a day ends and when the fireteam is home, never at dispatch or mid-fight:
## quit a fight halfway and the next start finds the table as it was before the dispatch.

const _Table := preload("res://presentation/table_view.gd")
const _Fight := preload("res://presentation/fight_view.gd")

var campaign: Campaign
var save_path: String = KnowledgeStore.DEFAULT_PATH
var _current: Node = null


func _ready() -> void:
	if campaign == null:
		campaign = CampaignSave.load_campaign(save_path)
	if campaign == null:
		campaign = preload("res://rules/fixtures/table_opening.gd").opening()
	_show_table()


func _show_table() -> void:
	_swap(null)
	var table = _Table.new()
	table.campaign = campaign
	table.wired = true
	table.campaign_committed.connect(_on_committed)
	_swap(table)


func _on_committed(c: Campaign, what: String) -> void:
	campaign = c
	if what == "day_end":
		CampaignSave.save_campaign(campaign, save_path)
	elif what == "dispatch":
		call_deferred("_go_to_fight")


func _go_to_fight() -> void:
	var bowl_id: String = campaign.deployment["bowl"]
	var ids: Array[int] = []
	for id in campaign.deployment["ids"]:
		ids.append(int(id))
	var fight = _Fight.new()
	fight.fight_state = TableDispatch.build_fight(campaign, bowl_id, ids)
	fight.fight_state.bowl_id = bowl_id
	fight.store_path = save_path
	fight.fight_ended.connect(_on_fight_ended)
	_swap(fight)


func _on_fight_ended(state: CombatState) -> void:
	call_deferred("_come_home", state)


func _come_home(state: CombatState) -> void:
	var home := HomeCommand.new(state)
	var check := home.validate(campaign)
	if not check.ok:
		push_error("Game: cannot come home: %s" % check.reason)
		return
	campaign = home.apply(campaign)
	CampaignSave.save_campaign(campaign, save_path)
	_show_table()


func _swap(next: Node) -> void:
	if _current != null:
		remove_child(_current)
		_current.queue_free()
		_current = null
	if next != null:
		add_child(next)
		_current = next
