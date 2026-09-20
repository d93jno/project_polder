class_name Taxonomy
extends Object
## Shared enums and the CoverMaterial × WeaponClass stopping table.
## The table is the single source of truth for what breaks a line (GDD §5.4, assets §1).
## Named CoverMaterial (not Material) to avoid clashing with Godot's Material class.

enum CoverMaterial {
	AIR,
	PLANK,
	CRATE,
	MASONRY,
	METAL,
	DEPLOYED_BARRIER,
	SMOKE,
	WATER_DEEP,
	WATER_CHEST,
	GROUND,
}

enum WeaponClass {
	PISTOL,
	MELEE,
	SPEAR,
	SHOTGUN,
	RIFLE,
	LMG,
	SNIPER,
}

enum WaterStep {
	FLOODED,
	FALLING,
	MUD,
	DRY,
}

enum Faction {
	PLAYER,
	DRIFTER,
	WAKE_RIDER,
	PURIFIER,
	VANGUARD,
	NEUTRAL,
}

## Bit flags for Cell.flags.
class CellFlags:
	const SHELTER := 1 << 0
	const DECK := 1 << 1
	const SWIMMABLE := 1 << 2
	const INTERIOR := 1 << 3


## Bit flags for Unit.scars. Permanent, known penalties (GDD §8.5) — never a chance roll.
class Scar:
	const AGORAPHOBIA := 1 << 0 ## Breaks when a long cone sees them in the open (GDD §5.5, §8.5)
	const LUNG_DAMAGE := 1 << 1 ## Reduced AP in water. Data only until movement reads it


static func material_count() -> int:
	return CoverMaterial.values().size()


static func weapon_class_count() -> int:
	return WeaponClass.values().size()


static func material_name(material: CoverMaterial) -> String:
	return CoverMaterial.keys()[material]


static func weapon_class_name(weapon: WeaponClass) -> String:
	return WeaponClass.keys()[weapon]


## Long weapon classes (GDD §5.5): rifle, LMG, sniper. Short: pistol, shotgun, melee, speargun.
## The one definition — damage, cost, deep-water firing, soft cover and break all ask this,
## so "long" cannot mean two things (plan §1.5.1).
static func is_long(weapon: WeaponClass) -> bool:
	match weapon:
		WeaponClass.RIFLE, WeaponClass.LMG, WeaponClass.SNIPER:
			return true
		WeaponClass.PISTOL, WeaponClass.MELEE, WeaponClass.SPEAR, WeaponClass.SHOTGUN:
			return false
		_:
			push_error("Taxonomy.is_long: unhandled weapon %s" % weapon)
			return false


## Whether this material stops this weapon class (blocks the line).
## Soft cover (plank/crate) stops short/CQB and not rifles (GDD §5.4).
## Smoke and deep water block every class. Chest-deep water does not.
static func stops(material: CoverMaterial, weapon: WeaponClass) -> bool:
	match material:
		CoverMaterial.AIR, CoverMaterial.WATER_CHEST:
			return false
		CoverMaterial.SMOKE, CoverMaterial.WATER_DEEP, CoverMaterial.GROUND:
			return true
		CoverMaterial.PLANK, CoverMaterial.CRATE:
			return not is_long(weapon) ## Soft cover stops short weapons, not long ones
		CoverMaterial.MASONRY, CoverMaterial.METAL, CoverMaterial.DEPLOYED_BARRIER:
			return true
		_:
			push_error("Taxonomy.stops: unhandled material %s" % material)
			return true
