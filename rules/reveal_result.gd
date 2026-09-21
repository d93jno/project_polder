class_name RevealResult
extends RefCounted
## What applying a command revealed (plan 04 §4.5 / UI §5).
## The fact plans/05 spends for undo — no chrome here.


## Cells that left Unknown (newly in Known-quiet ∪ Live) during this command.
var cells_peeled: Array[Vector3i] = []
## Watch unit ids that reacted: cone entry, or a qualifying act while already inside (GDD 1.13).
var watches_triggered: Array[int] = []
## Hostile unit ids whose clean line the actor newly entered this command.
var enemy_lines_entered: Array[int] = []
## Shoot / interact / throw / watch / extract — not a pure move (UI §5).
var was_act: bool = false


static func empty() -> RevealResult:
	return RevealResult.new()


func anything_revealed() -> bool:
	return (
		was_act
		or not cells_peeled.is_empty()
		or not watches_triggered.is_empty()
		or not enemy_lines_entered.is_empty()
	)


func record_watch(unit_id: int) -> void:
	if unit_id < 0 or unit_id in watches_triggered:
		return
	watches_triggered.append(unit_id)


func record_enemy_line(unit_id: int) -> void:
	if unit_id < 0 or unit_id in enemy_lines_entered:
		return
	enemy_lines_entered.append(unit_id)


func record_peeled(cell: Vector3i) -> void:
	if cell in cells_peeled:
		return
	cells_peeled.append(cell)
