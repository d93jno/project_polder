class_name BasinRules
extends Object
## The basin's tuning in one place (plan 07 §7.1). All *working defaults* from GDD §6.1 and §6.2: the
## digits are prototype work, the shape of each rule is the design.

## Days without a post before a pump reads thin, then failing, then breaks (plan 07 §7.5: wear is a clock).
const THIN_AFTER_DAYS := 2
const FAILING_AFTER_DAYS := 4
const BREAKS_AFTER_DAYS := 6

## A bowl steps *down* (drier) only when this many of its feeders are already that dry, or all of them
## if it has fewer (GDD §6.1: "two neighbors, or majority of the ring").
const FEEDERS_NEEDED_TO_DRY := 2

## Days a step takes to walk drier. How fast a bowl walks wetter is its own `leak_days` (outer fast,
## inner slow, GDD §6.2).
const DRY_DAYS := 2

## Days a redirected bowl is held wet before it can walk drier again: "the target sector walks one step
## wetter and stays there for days" (GDD §6.4). Working default.
const REDIRECTION_HANG_DAYS := 5

## How many steps wetter a feeder must stand before it pushes the bowl it feeds (plan 08 §7.1).
const SPREAD_STEPS := 2

## Food (plan 09 §9.0): one ration feeds this many people for a day; a part-fed group still eats a whole one.
## A working default, so ten people eat three a day.
const MOUTHS_PER_FOOD := 4

## Fields (plan 09 §9.1, §7.1): each Dry, un-ruined field yields this much food a day, and each hand
## in the FIELDS bucket adds this much more, one hand to a field (GDD §4.3: the labor board's food engine).
const FIELD_YIELD := 1
const HAND_YIELD := 1

## Fuel for the fireteam's leg, each way, by the bowl's water (plan 09 §9.2, GDD §4.2 "Travel"): boats on
## Flooded and Falling, slow going through Mud, and nothing on Dry ground, where they walk.
const FUEL_PER_WAY := {
	Taxonomy.WaterStep.FLOODED: 1,
	Taxonomy.WaterStep.FALLING: 1,
	Taxonomy.WaterStep.MUD: 2,
	Taxonomy.WaterStep.DRY: 0,
}

## Scrap (plan 09 §9.3, §7.4): each hand in WORKSHOP makes this much a day, after the pumps are posted, so
## a day's scrap cannot pay for that same night's posts (readable the evening before).
const SCRAP_PER_WORKSHOP_HAND := 1

## People (plan 09 §9.4, §7.5): the camp grows by this many a day toward what its Dry fields can feed,
## and only while it ate in full and has food for one more. One person leaves for each ration the camp
## was short, and for each field the water ruined (GDD §4.3: "ruin a field ... and some leave or die").
const ARRIVALS_PER_DAY := 1
const LEAVERS_PER_RATION_SHORT := 1
const LEAVERS_PER_RUINED_FIELD := 1

## Bands (plan 10 §10.0): how many met bands one ring (grade) holds (GDD §5.12: "cap bands per ring").
const BANDS_PER_RING := 2

## How many days ahead the food forecast looks before it says "more than" (plan 09 §9.0).
const FORECAST_DAYS := 30

## One ignored late pump walks Dry to Mud and stops while the rest of the ring holds (GDD §6.2).
const LEAK_CAP_STEP := Taxonomy.WaterStep.MUD


static func food_for(mouths: int) -> int:
	return (maxi(mouths, 0) + MOUTHS_PER_FOOD - 1) / MOUTHS_PER_FOOD


static func wetter(step: Taxonomy.WaterStep) -> Taxonomy.WaterStep:
	return maxi(int(step) - 1, int(Taxonomy.WaterStep.FLOODED)) as Taxonomy.WaterStep


static func drier(step: Taxonomy.WaterStep) -> Taxonomy.WaterStep:
	return mini(int(step) + 1, int(Taxonomy.WaterStep.DRY)) as Taxonomy.WaterStep
