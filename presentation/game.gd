extends Node
## The flow between the two modes (plan 07 §7.5, GDD §3.1): dispatch leaves the table for the fight, the
## fight's end brings the squad home to the table. There is no button that swaps modes mid-mission.
## It owns the campaign between scenes and the save; the fight and the table own nothing of each other.
##
## The save is written when a day ends and when the fireteam is home, never at dispatch or mid-fight:
## quit a fight halfway and the next start finds the table as it was before the dispatch.

const _Table := preload("res://presentation/table_view.gd")
const _Fight := preload("res://presentation/fight_view.gd")
const _Start := preload("res://presentation/start_view.gd")

## True when the game opens on the start screen (the game scene sets it); false opens straight on the table.
@export var start_screen: bool = false
var campaign: Campaign
var save_path: String = KnowledgeStore.DEFAULT_PATH
var _current: Node = null


func _ready() -> void:
	if start_screen and campaign == null:
		_show_start()
		return
	_open_table()


func _open_table() -> void:
	if campaign == null:
		campaign = CampaignSave.load_campaign(save_path)
	if campaign == null:
		campaign = preload("res://rules/fixtures/table_opening.gd").opening()
	_show_table()


func _show_start() -> void:
	var start = _Start.new()
	start.has_save = CampaignSave.has_save(save_path)
	start.continue_pressed.connect(_on_continue)
	start.new_game_pressed.connect(_on_new_game)
	start.quit_pressed.connect(func() -> void: get_tree().quit())
	_swap(start)


func _on_continue() -> void:
	campaign = CampaignSave.load_campaign(save_path)
	_open_table()


func _on_new_game() -> void:
	CampaignSave.erase(save_path)
	campaign = null
	_open_table()


## Back to the start screen from the table. Nothing is saved here: the save is written at day end and when the
## fireteam is home, so the screen offers exactly the last of those.
func _on_menu() -> void:
	campaign = null
	_show_start()


func _show_table() -> void:
	_swap(null)
	var table = _Table.new()
	table.campaign = campaign
	table.wired = true
	table.campaign_committed.connect(_on_committed)
	table.menu_requested.connect(_on_menu)
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
	fight.fight_state = TableDispatch.build_fight(campaign, bowl_id, ids, bool(campaign.deployment.get("hold_sluice", false)))
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
