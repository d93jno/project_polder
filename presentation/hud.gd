extends CanvasLayer
## Tactical HUD chrome. Setters take primitives. fight_view binds them from CombatState.

signal slot_pressed(index: int)
signal end_phase_pressed

const _KEY := preload("res://presentation/mint_key.gdshader")

var _ap_row: HBoxContainer
var _hit_row: HBoxContainer
var _bleed_row: HBoxContainer
var _exposure: TextureRect
var _pin: TextureRect
var _watch: TextureRect
var _phase: TextureRect
var _names: Array[Label] = []
var _slots: Array[Control] = []
var _height: Label
var _fuel: Label
var _note: Label
var _key_mat: ShaderMaterial


func _ready() -> void:
	layer = 10
	_key_mat = ShaderMaterial.new()
	_key_mat.shader = _KEY
	_build()


func set_fireteam(names: PackedStringArray) -> void:
	for i in 4:
		if i < _names.size():
			_names[i].text = names[i] if i < names.size() else ""


func set_selected(index: int) -> void:
	for i in _slots.size():
		_slots[i].modulate = Color(1.2, 1.15, 1.05) if i == index else Color(0.78, 0.78, 0.78)


func set_ap(current: int, pool: int) -> void:
	_fill_pips(_ap_row, current, pool)


func set_hits(remaining: int, max_hits: int) -> void:
	_fill_pips(_hit_row, remaining, max_hits)


func set_bleed_rounds(n: int) -> void:
	_bleed_row.get_parent().visible = n > 0
	_fill_pips(_bleed_row, n, 3)


func set_exposure(kind: String) -> void:
	var file := "ui_icon_exposed.png"
	match kind:
		"hidden":
			file = "ui_icon_hidden.png"
		"no_hide":
			file = "ui_icon_no_hide.png"
		_:
			file = "ui_icon_exposed.png"
	_exposure.texture = load(PresentationCatalog.UI_ICONS + file) as Texture2D


func set_pin(kind: String) -> void:
	_pin.visible = kind != "none"
	if kind == "ducked":
		_pin.texture = load(PresentationCatalog.UI_ICONS + "ui_icon_ducked.png") as Texture2D
	elif kind == "ducking_next":
		_pin.texture = load(PresentationCatalog.UI_ICONS + "ui_icon_ducking_next.png") as Texture2D


func set_watch_spent(spent: bool) -> void:
	var file := "ui_icon_watch_spent.png" if spent else "ui_icon_watch_friendly.png"
	_watch.texture = load(PresentationCatalog.UI_ICONS + file) as Texture2D


func set_phase_yours(yours: bool) -> void:
	var file := "ui_phase_yours.png" if yours else "ui_phase_theirs.png"
	_phase.texture = load(PresentationCatalog.UI_THEME + file) as Texture2D


func set_height_read(text: String) -> void:
	_height.text = text
	_height.visible = not text.is_empty()


func set_fuel_count(n: int) -> void:
	_fuel.text = str(n)


func set_note(text: String) -> void:
	if _note:
		_note.text = text


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.name = "Root"
	add_child(root)

	var strip := HBoxContainer.new()
	strip.position = Vector2(16, 16)
	strip.add_theme_constant_override("separation", 8)
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(strip)
	for i in 4:
		var slot := _slot()
		var idx := i
		slot.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				slot_pressed.emit(idx)
		)
		strip.add_child(slot)
		_slots.append(slot)

	var status := HBoxContainer.new()
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.offset_left = 16
	status.offset_bottom = -16
	status.offset_top = -96
	status.offset_right = 720
	status.add_theme_constant_override("separation", 10)
	root.add_child(status)

	_ap_row = _pip_box("AP", PresentationCatalog.UI_THEME + "ui_pip_ap.png")
	_hit_row = _pip_box("Hits", PresentationCatalog.UI_THEME + "ui_pip_hit.png")
	var bleed_wrap := _pip_box("Bleed", PresentationCatalog.UI_THEME + "ui_pip_bleed.png")
	_bleed_row = bleed_wrap
	status.add_child(_ap_row.get_parent())
	status.add_child(_hit_row.get_parent())
	status.add_child(_bleed_row.get_parent())

	_exposure = _icon(PresentationCatalog.UI_ICONS + "ui_icon_exposed.png")
	_pin = _icon(PresentationCatalog.UI_ICONS + "ui_icon_ducked.png")
	_watch = _icon(PresentationCatalog.UI_ICONS + "ui_icon_watch_friendly.png")
	status.add_child(_exposure)
	status.add_child(_pin)
	status.add_child(_watch)

	_phase = _icon(PresentationCatalog.UI_THEME + "ui_phase_yours.png")
	_phase.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_phase.offset_left = -80
	_phase.offset_top = 16
	_phase.offset_right = -16
	_phase.offset_bottom = 80
	_phase.custom_minimum_size = Vector2(64, 64)
	_phase.mouse_filter = Control.MOUSE_FILTER_STOP
	_phase.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			end_phase_pressed.emit()
	)
	root.add_child(_phase)

	_note = Label.new()
	_note.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_note.offset_left = 16
	_note.offset_right = -16
	_note.offset_bottom = -8
	_note.offset_top = -36
	_note.add_theme_font_size_override("font_size", 16)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_note)

	_height = Label.new()
	_height.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_height.offset_left = 16
	_height.offset_bottom = -100
	_height.offset_top = -128
	_height.offset_right = 480
	_height.add_theme_font_size_override("font_size", 18)
	root.add_child(_height)

	var fuel_wrap := HBoxContainer.new()
	fuel_wrap.position = Vector2(16, 84)
	var fuel_frame := TextureRect.new()
	fuel_frame.texture = load(PresentationCatalog.UI_THEME + "ui_fuel_count_frame_128.png") as Texture2D
	fuel_frame.custom_minimum_size = Vector2(72, 48)
	fuel_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fuel_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fuel = Label.new()
	_fuel.text = "4"
	_fuel.add_theme_font_size_override("font_size", 22)
	fuel_wrap.add_child(fuel_frame)
	fuel_wrap.add_child(_fuel)
	root.add_child(fuel_wrap)


func _slot() -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(140, 56)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := TextureRect.new()
	bg.texture = load(PresentationCatalog.UI_THEME + "ui_fireteam_slot.png") as Texture2D
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	box.add_child(bg)
	var lab := Label.new()
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 16)
	box.add_child(lab)
	_names.append(lab)
	return box


func _pip_box(caption: String, tex_path: String) -> HBoxContainer:
	var wrap := VBoxContainer.new()
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 12)
	wrap.add_child(cap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.set_meta("tex", tex_path)
	wrap.add_child(row)
	return row


func _fill_pips(row: HBoxContainer, filled: int, total: int) -> void:
	for c in row.get_children():
		c.queue_free()
	var path: String = row.get_meta("tex")
	var tex := load(path) as Texture2D
	for i in total:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(22, 22)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.material = _key_mat
		r.modulate = Color.WHITE if i < filled else Color(1, 1, 1, 0.22)
		row.add_child(r)


func _icon(path: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path) as Texture2D
	r.custom_minimum_size = Vector2(48, 48)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.material = _key_mat
	return r
