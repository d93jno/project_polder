extends Object
## A small authored basin (plan 07 §7.0, §7.2): three rim bowls, three on the floor ring and a sump.
## The terrace is the one bowl with an authored tactical map (`flooded_terrace.gd`). Preload (no class_name).

const RIDGE_W := "ridge_w"
const RIDGE_N := "ridge_n"
const RIDGE_E := "ridge_e"
const TERRACE := "terrace"
const POLDER_A := "polder_a"
const POLDER_B := "polder_b"
const SUMP := "sump"


static func _bowl(
	id: String, grade: BasinBowl.Grade, step: Taxonomy.WaterStep, feeders: Array[String], leak_days: int
) -> BasinBowl:
	var bowl := BasinBowl.new(id)
	bowl.grade = grade
	bowl.step = step
	bowl.feeders = feeders
	bowl.leak_days = leak_days
	return bowl


static func _graph(rim_step: Taxonomy.WaterStep, ring_step: Taxonomy.WaterStep) -> Basin:
	var basin := Basin.new()
	## Outer bowls leak fast and inner ones slowly (GDD §6.2). The rim has no feeders: it drains alone.
	basin.add_bowl(_bowl(RIDGE_W, BasinBowl.Grade.RIM, rim_step, [] as Array[String], 1))
	basin.add_bowl(_bowl(RIDGE_N, BasinBowl.Grade.RIM, rim_step, [] as Array[String], 1))
	basin.add_bowl(_bowl(RIDGE_E, BasinBowl.Grade.RIM, rim_step, [] as Array[String], 1))
	basin.add_bowl(_bowl(TERRACE, BasinBowl.Grade.FLOOR, ring_step, [RIDGE_W, RIDGE_N] as Array[String], 2))
	basin.add_bowl(_bowl(POLDER_A, BasinBowl.Grade.FLOOR, ring_step, [RIDGE_N, RIDGE_E] as Array[String], 2))
	basin.add_bowl(_bowl(POLDER_B, BasinBowl.Grade.FLOOR, ring_step, [RIDGE_E, TERRACE] as Array[String], 2))
	basin.add_bowl(_bowl(SUMP, BasinBowl.Grade.SUMP, ring_step, [TERRACE, POLDER_A, POLDER_B] as Array[String], 3))
	return basin


## The opening: wet everywhere, the rim a little drier, and only the terrace and the two ridges nearest
## it walked and read. Instruments are awake on the terrace alone.
static func opening() -> Basin:
	var basin := _graph(Taxonomy.WaterStep.FALLING, Taxonomy.WaterStep.FLOODED)
	for id in [TERRACE, RIDGE_W, RIDGE_N]:
		basin.bowl(id).known = true
	basin.bowl(TERRACE).instrumented = true
	## Roof plots are dry above a flooded street (GDD 5.8), so the terrace's camp and post stand in it.
	basin.bowl(TERRACE).camps = 1
	basin.bowl(TERRACE).posts = 1
	basin.bowl(RIDGE_W).posts = 1
	return basin


## A late, improved ring: everything walked, instrumented and Dry, every pump holding. The place the
## leak cap and a neglected pump are tested.
static func late_ring() -> Basin:
	var basin := _graph(Taxonomy.WaterStep.DRY, Taxonomy.WaterStep.DRY)
	for id in basin.order:
		basin.bowl(id).known = true
		basin.bowl(id).instrumented = true
	## Fields on the dry inner ring, the first real ones (GDD §4.3), a road through the second polder.
	basin.bowl(TERRACE).fields = 2
	basin.bowl(TERRACE).camps = 1
	basin.bowl(POLDER_A).fields = 3
	basin.bowl(POLDER_A).road = true
	basin.bowl(POLDER_B).fields = 2
	basin.bowl(POLDER_B).posts = 1
	basin.bowl(RIDGE_W).posts = 1
	return basin
