class_name WatchCrossing
extends RefCounted
## Entering an enemy Live Watch along a move path (UI §4.1 / §4.4).

var cell: Vector3i = Vector3i.ZERO
var cell_index: int = -1
var watcher_id: int = -1
var weapon: Taxonomy.WeaponClass = Taxonomy.WeaponClass.PISTOL


func _init(
	p_cell: Vector3i = Vector3i.ZERO,
	p_cell_index: int = -1,
	p_watcher_id: int = -1,
	p_weapon: Taxonomy.WeaponClass = Taxonomy.WeaponClass.PISTOL,
) -> void:
	cell = p_cell
	cell_index = p_cell_index
	watcher_id = p_watcher_id
	weapon = p_weapon
