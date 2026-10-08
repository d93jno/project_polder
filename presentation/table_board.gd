extends Control
## The flat board of bowls and feeder edges (plan 07 §7.4, decision 7.3). It draws the cards and edges
## it is handed and nothing else: no water, no upkeep and no feeder rule of its own, and a bowl nobody
## has walked is a black box with a word in it (UI §8). Every state reads without hue (UI §14): the
## step is a pattern and a word, a pouring feeder is a solid line and a dry one a dashed line.

signal bowl_pressed(id: String)

const NODE_SIZE := Vector2(236.0, 132.0)
const MARGIN := 18.0
const INK := Color(0.86, 0.87, 0.84)
const DIM := Color(0.56, 0.58, 0.57)
const PANEL := Color(0.10, 0.12, 0.13)
const EDGE := Color(0.62, 0.64, 0.62)

## grade -> row, in the order the basin draws them: the rim above, the sump below.
const ROWS := {BasinBowl.Grade.RIM: 0, BasinBowl.Grade.FLOOR: 1, BasinBowl.Grade.SUMP: 2}

var cards: Array[Dictionary] = []
var edges: Array[Dictionary] = []
var selected: String = ""
## Every string the board draws, so a test can assert what it shows and never shows.
var drawn_text: Array[String] = []


func set_state(p_cards: Array[Dictionary], p_edges: Array[Dictionary], p_selected: String) -> void:
	cards = p_cards
	edges = p_edges
	selected = p_selected
	drawn_text.clear()
	for card in cards:
		drawn_text.append(str(card["id"]))
		for line in card["lines"]:
			drawn_text.append(str(line))
	queue_redraw()


## Where each card sits: rows by grade, spread across the board, the sump alone in the middle.
func rect_of(id: String) -> Rect2:
	var grade := _grade_of(id)
	var peers: Array[String] = []
	for card in cards:
		if _grade_of(card["id"]) == grade:
			peers.append(card["id"])
	var index := peers.find(id)
	var row: int = ROWS[grade]
	var usable := maxf(size.x - 2.0 * MARGIN - NODE_SIZE.x, 0.0)
	var x := MARGIN + (usable * 0.5 if peers.size() == 1 else usable * float(index) / float(peers.size() - 1))
	var gap := maxf((size.y - 2.0 * MARGIN - 3.0 * NODE_SIZE.y) / 2.0, 12.0)
	return Rect2(Vector2(x, MARGIN + float(row) * (NODE_SIZE.y + gap)), NODE_SIZE)


func _grade_of(id: String) -> BasinBowl.Grade:
	for card in cards:
		if card["id"] == id:
			return card["grade"]
	return BasinBowl.Grade.FLOOR


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for card in cards:
			if rect_of(card["id"]).has_point(event.position):
				bowl_pressed.emit(card["id"])
				return


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for edge in edges:
		_draw_edge(edge)
	for card in cards:
		var rect := rect_of(card["id"])
		draw_rect(rect, PANEL, true)
		var chosen: bool = card["id"] == selected
		draw_rect(rect, INK if card["known"] else DIM, false, 3.0 if chosen else 1.5)
		if chosen:
			draw_rect(rect.grow(-6.0), INK, false, 1.5)
		draw_string(font, rect.position + Vector2(48.0, 22.0), str(card["id"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
		if card["known"]:
			_draw_step_glyph(Rect2(rect.position + Vector2(8.0, 8.0), Vector2(32.0, 32.0)), card["step"])
		var y := 44.0
		for line in card["lines"]:
			draw_string(font, rect.position + Vector2(10.0, y + 12.0), str(line), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16.0, 13, INK if card["known"] else DIM)
			y += 18.0


## The water step as a pattern, so it separates without colour: Flooded solid, Falling hatched, Mud
## dotted, Dry empty.
func _draw_step_glyph(box: Rect2, step: Taxonomy.WaterStep) -> void:
	draw_rect(box, INK, false, 1.5)
	match step:
		Taxonomy.WaterStep.FLOODED:
			draw_rect(box.grow(-3.0), INK, true)
		Taxonomy.WaterStep.FALLING:
			var x := box.position.x + 6.0
			while x < box.end.x:
				draw_line(Vector2(x, box.end.y - 2.0), Vector2(minf(x + 12.0, box.end.x - 2.0), box.position.y + 2.0), INK, 1.5)
				x += 8.0
		Taxonomy.WaterStep.MUD:
			for ix in 3:
				for iy in 3:
					draw_circle(box.position + Vector2(7.0 + 9.0 * ix, 7.0 + 9.0 * iy), 2.0, INK)
		_:
			pass


func _draw_edge(edge: Dictionary) -> void:
	var from_rect := rect_of(edge["from"])
	var to_rect := rect_of(edge["to"])
	var a := from_rect.get_center() + Vector2(0.0, from_rect.size.y * 0.5)
	var b := to_rect.get_center() - Vector2(0.0, to_rect.size.y * 0.5)
	if a.y >= b.y:
		a = from_rect.get_center() + Vector2(from_rect.size.x * 0.5, 0.0)
		b = to_rect.get_center() - Vector2(to_rect.size.x * 0.5, 0.0)
	if edge["pouring"]:
		draw_line(a, b, EDGE, 3.0)
	else:
		var length := a.distance_to(b)
		var dir := (b - a) / maxf(length, 1.0)
		var t := 0.0
		while t < length:
			draw_line(a + dir * t, a + dir * minf(t + 8.0, length), EDGE, 1.5)
			t += 16.0
	var tip := b
	var side := Vector2(-(b - a).normalized().y, (b - a).normalized().x)
	var back := (a - b).normalized() * 10.0
	draw_colored_polygon(PackedVector2Array([tip, tip + back + side * 5.0, tip + back - side * 5.0]), EDGE)
