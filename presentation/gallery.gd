extends Node3D
## Art smoke: flooded bowl + water shader + one humanoid + dummy cone + HUD.
## Not a fight. Does not load CombatState, LOS, or commands.

const _UnitView := preload("res://presentation/unit_view.gd")
const _ConeView := preload("res://presentation/watch_cone_view.gd")
const _Select := preload("res://presentation/selection_ring.gd")
const _Hud := preload("res://presentation/hud.gd")


func _ready() -> void:
	var bowl := (load(PresentationCatalog.FLOODED_BOWL) as PackedScene).instantiate()
	bowl.name = "Bowl"
	add_child(bowl)

	var boat := bowl.find_child("BoatCamp", true, false)
	if boat:
		PresentationCatalog.set_boat_fuel(boat, 4)

	var unit := _UnitView.new()
	unit.name = "UnitView"
	unit.weapon = "machete"
	unit.clip = "idle"
	unit.position = Vector3(2.0, 0.0, 0.2)
	unit.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	add_child(unit)

	var ring := _Select.new()
	ring.name = "Selection"
	ring.position = Vector3(2.0, 0.04, 0.2)
	add_child(ring)

	# Dummy volume for the shader, not a rules cone. Apex on a roof, looking at the street.
	var cone := _ConeView.new()
	cone.name = "DummyWatch"
	cone.mode = 1
	add_child(cone)
	cone.aim(Vector3(4.0, 6.2, 6.0), Vector3(2.0, 0.2, 0.2))

	var hud := _Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.set_height_read("roof 3  street 0  water 2")
