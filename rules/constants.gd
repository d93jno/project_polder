class_name RulesConstants
extends Object
## Working defaults — tune here, nowhere else (plan §4 / §5).


## Watch cone length in chebyshev cells, by weapon class. *Working default.*
static func cone_length(weapon: Taxonomy.WeaponClass) -> int:
	match weapon:
		Taxonomy.WeaponClass.PISTOL:
			return 4
		Taxonomy.WeaponClass.MELEE:
			return 1
		Taxonomy.WeaponClass.SPEAR:
			return 2
		Taxonomy.WeaponClass.SHOTGUN:
			return 3
		Taxonomy.WeaponClass.RIFLE:
			return 8
		Taxonomy.WeaponClass.LMG:
			return 7
		Taxonomy.WeaponClass.SNIPER:
			return 12
		_:
			return 4
