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

## One ignored late pump walks Dry to Mud and stops while the rest of the ring holds (GDD §6.2).
const LEAK_CAP_STEP := Taxonomy.WaterStep.MUD


static func wetter(step: Taxonomy.WaterStep) -> Taxonomy.WaterStep:
	return maxi(int(step) - 1, int(Taxonomy.WaterStep.FLOODED)) as Taxonomy.WaterStep


static func drier(step: Taxonomy.WaterStep) -> Taxonomy.WaterStep:
	return mini(int(step) + 1, int(Taxonomy.WaterStep.DRY)) as Taxonomy.WaterStep
