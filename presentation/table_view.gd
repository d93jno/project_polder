extends Control
## Table mode: the surface (plan 07 §7.4, UI §8). It draws a `Campaign` and applies commands that
## `rules/` has already validated. It decides nothing: every word comes from `table_queries.gd`, and
## nothing here computes water, upkeep, posting or dispatch.
##
## UI §8's "never shows": no bar, percentage, target or progress pip, and nothing about individuals
## beyond the bench's names. The currencies are plain counts, labor is a short board.

const _Queries := preload("res://presentation/table_queries.gd")
const _Board := preload("res://presentation/table_board.gd")
const _Confirm := preload("res://presentation/confirm_prompt.gd")
const _Opening := preload("res://rules/fixtures/table_opening.gd")

## `what` is "day_end" or "dispatch": the moments the game saves or leaves for a fight.
signal campaign_committed(campaign: Campaign, what: String)

var campaign: Campaign
## True when a game flow listens for dispatch. Standalone, a dispatch only marks the fireteam out.
var wired := false
var _selected_bowl: String = ""
var _chosen: Array[int] = []
var _hold_sluice := false
var _confirm = _Confirm.new()
var _queries
var _board
var _day: Label
var _currencies: Label
var _people: Label
var _food_lasts: Label
var _scrap_line: Label
var _assignments: Label
var _labor_box: VBoxContainer
var _morning: Label
var _dispatch_box: VBoxContainer
var _dispatch_button: Button
var _note: Label
var _card: Label
var _day_end: Button


func _ready() -> void:
	if campaign == null:
		campaign = _Opening.opening()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color(0.06, 0.07, 0.08)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_build()
	_refresh()


func _build() -> void:
	_board = _Board.new()
	_board.position = Vector2(8, 8)
	_board.size = Vector2(840, 660)
	_board.bowl_pressed.connect(_on_bowl)
	add_child(_board)

	var panel := VBoxContainer.new()
	panel.position = Vector2(864, 8)
	panel.size = Vector2(404, 660)
	panel.add_theme_constant_override("separation", 3)
	add_child(panel)

	_day = _label(panel, 22)
	_currencies = _label(panel, 16)
	_people = _label(panel, 16)
	_food_lasts = _label(panel, 16)
	_scrap_line = _label(panel, 16)
	_section(panel, "labor")
	_labor_box = VBoxContainer.new()
	panel.add_child(_labor_box)
	_assignments = _label(panel, 14)
	_section(panel, "this morning")
	_morning = _label(panel, 14)
	_morning.custom_minimum_size = Vector2(0, 64)
	_section(panel, "dispatch")
	_dispatch_box = VBoxContainer.new()
	panel.add_child(_dispatch_box)
	_dispatch_button = Button.new()
	_dispatch_button.text = "send the fireteam"
	_dispatch_button.pressed.connect(_on_dispatch)
	panel.add_child(_dispatch_button)
	_day_end = Button.new()
	_day_end.pressed.connect(_on_day_end)
	panel.add_child(_day_end)

	## The redirection card sits on the board, beside the sump, where the water it is about to change is.
	_card = Label.new()
	_card.position = Vector2(572, 430)
	_card.size = Vector2(276, 236)
	_card.add_theme_font_size_override("font_size", 13)
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_card)

	_note = Label.new()
	_note.position = Vector2(8, 676)
	_note.size = Vector2(1264, 36)
	_note.add_theme_font_size_override("font_size", 16)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_note)


func _label(parent: Control, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _section(parent: Control, text: String) -> void:
	var label := _label(parent, 13)
	label.text = text.to_upper()
	label.modulate = Color(0.62, 0.64, 0.63)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _confirm.is_armed():
			_confirm.cancel()
			_note.text = ""
			get_viewport().set_input_as_handled()


## --- Reading the campaign ---


func _refresh() -> void:
	_queries = _Queries.compute(campaign, _selected_bowl, _chosen, _hold_sluice)
	_board.set_state(_queries.cards, _queries.edges, _selected_bowl)
	_day.text = _queries.day_label
	_currencies.text = _queries.currencies
	_people.text = _queries.people
	_food_lasts.text = _queries.food_lasts
	_scrap_line.text = _queries.scrap_line
	_assignments.text = _queries.assignments_left
	_morning.text = "\n".join(_queries.morning) if not _queries.morning.is_empty() else "nothing moved"
	_rebuild_labor()
	_rebuild_dispatch()
	_day_end.text = _queries.day_end_text


func _rebuild_labor() -> void:
	for child in _labor_box.get_children():
		child.queue_free()
	for row in _queries.labor:
		var line := HBoxContainer.new()
		var name := Label.new()
		name.text = row["name"]
		name.custom_minimum_size = Vector2(230, 0)
		line.add_child(name)
		var count := Label.new()
		count.text = str(row["hands"])
		count.custom_minimum_size = Vector2(34, 0)
		line.add_child(count)
		if row["bucket"] != Campaign.Bucket.IDLE:
			var less := Button.new()
			less.text = "−"
			less.pressed.connect(_assign.bind(row["bucket"], Campaign.Bucket.IDLE))
			line.add_child(less)
			var more := Button.new()
			more.text = "+"
			more.pressed.connect(_assign.bind(Campaign.Bucket.IDLE, row["bucket"]))
			line.add_child(more)
		_labor_box.add_child(line)


func _rebuild_dispatch() -> void:
	for child in _dispatch_box.get_children():
		child.queue_free()
	var d: Dictionary = _queries.dispatch
	var head := Label.new()
	head.text = d["out"] if d.has("out") else (d["bowl"] if d["bowl"] != "" else "choose a bowl on the board")
	head.add_theme_font_size_override("font_size", 15)
	_dispatch_box.add_child(head)
	## The bowl first, then the bodies (UI §8).
	_card.text = "\n".join(d.get("card", []))
	for line in (d.get("bowl_lines", []) as Array).slice(0, 2):
		var l := Label.new()
		l.text = str(line)
		l.add_theme_font_size_override("font_size", 13)
		_dispatch_box.add_child(l)
	if d.has("fuel_line"):
		var fuel := Label.new()
		fuel.text = str(d["fuel_line"])
		fuel.add_theme_font_size_override("font_size", 13)
		_dispatch_box.add_child(fuel)
	if d.get("has_sluice", false):
		var hold := CheckBox.new()
		hold.text = "hold the sluice"
		hold.button_pressed = _hold_sluice
		hold.toggled.connect(_on_hold)
		_dispatch_box.add_child(hold)
	var bodies := HBoxContainer.new()
	for id in d["bench"]:
		var box := CheckBox.new()
		box.text = str(id)
		box.button_pressed = id in _chosen
		box.toggled.connect(_on_body.bind(id))
		bodies.add_child(box)
	_dispatch_box.add_child(bodies)
	var why := Label.new()
	why.text = "" if d["ok"] else str(d["reason"])
	why.add_theme_font_size_override("font_size", 13)
	_dispatch_box.add_child(why)


## Every string the surface shows, so a test can assert UI §8's never-shows column.
func all_text() -> Array[String]:
	var out: Array[String] = []
	_collect(self, out)
	for line in _board.drawn_text:
		out.append(line)
	return out


func _collect(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		if not child.is_queued_for_deletion():
			_collect(child, out)


## --- Acting ---


func _on_bowl(id: String) -> void:
	_selected_bowl = id
	_hold_sluice = false
	_chosen = [] as Array[int]
	_confirm.cancel()
	_note.text = ""
	_refresh()


func _on_hold(pressed: bool) -> void:
	_hold_sluice = pressed
	_refresh()


func _on_body(pressed: bool, id: int) -> void:
	if pressed and id not in _chosen:
		_chosen.append(id)
	elif not pressed:
		_chosen.erase(id)
	_refresh()


func _assign(from_bucket: Campaign.Bucket, to_bucket: Campaign.Bucket) -> void:
	_try(AssignLaborCommand.new(from_bucket, to_bucket, 1))


func _on_dispatch() -> void:
	_try(DispatchCommand.new(_selected_bowl, _chosen, _hold_sluice))


func _on_day_end() -> void:
	_try(EndDayCommand.new())


func _try(command: TableCommand) -> void:
	var check := command.validate(campaign)
	if not check.ok:
		_note.text = check.reason
		return
	if command.needs_confirm(campaign) and not _confirm.press(command):
		_note.text = _Confirm.text_for_day_end(campaign)
		return
	_confirm.cancel()
	campaign = command.apply(campaign)
	_note.text = ""
	if command is DispatchCommand and not wired:
		_note.text = "nothing is listening: run the table through the game (make table) to play the fight"
	_refresh()
	if command is EndDayCommand:
		campaign_committed.emit(campaign, "day_end")
	elif command is DispatchCommand:
		campaign_committed.emit(campaign, "dispatch")
