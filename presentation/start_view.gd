extends Control
## The start screen: continue, new game, quit. It draws nothing from the rules and decides nothing; it
## says whether there is a save and tells the game what the player chose. A new game over a save asks twice
## and says what it replaces (UI §5: an irreversible action names its cost). Preloaded, not class_named.

signal continue_pressed
signal new_game_pressed
signal quit_pressed

const _Confirm := preload("res://presentation/confirm_prompt.gd")

## Whether a saved campaign exists; the game sets it before the view enters the tree.
var has_save: bool = false
var _continue: Button
var _new: Button
var _note: Label
var _armed := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color(0.06, 0.07, 0.08) ## the table's own ground
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(320, 0)
	column.position = Vector2(480, 220)
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var title := Label.new()
	title.text = "Project Polder"
	title.add_theme_font_size_override("font_size", 44)
	column.add_child(title)
	var sub := Label.new()
	sub.text = "a basin that is only drained as far as someone keeps it"
	sub.add_theme_font_size_override("font_size", 14)
	sub.modulate = Color(0.62, 0.64, 0.63)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 28)
	column.add_child(gap)

	_continue = _button(column, "continue", _on_continue)
	_continue.visible = has_save
	_new = _button(column, "new game", _on_new)
	_button(column, "quit", func() -> void: quit_pressed.emit())
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 14)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)


func _button(parent: Control, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


func _on_continue() -> void:
	continue_pressed.emit()


## With a save, the first press arms and says what it replaces; the second starts over.
func _on_new() -> void:
	if has_save and not _armed:
		_armed = true
		_note.text = "this replaces your saved campaign: press new game again · Esc cancels"
		return
	_armed = false
	new_game_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _armed:
		_armed = false
		_note.text = ""
		get_viewport().set_input_as_handled()


## Every string the screen shows, so a test can assert what it never says.
func all_text() -> Array[String]:
	var out: Array[String] = []
	_collect(self, out)
	return out


func _collect(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_collect(child, out)
