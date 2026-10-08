extends Object
## The first table day (plan 07 §7.2). Ten people, as GDD §4.2's working default (8 to 12), most at
## work and a few idle; the terrace's four on the bench. Preload (no class_name).

const BasinRing := preload("res://rules/fixtures/basin_ring.gd")


static func opening() -> Campaign:
	var campaign := Campaign.new()
	campaign.day = 1
	campaign.food = 12
	campaign.fuel = 4
	campaign.scrap = 6
	campaign.labor[Campaign.Bucket.IDLE] = 4
	campaign.labor[Campaign.Bucket.PUMPS] = 2
	campaign.labor[Campaign.Bucket.POSTS] = 1
	campaign.labor[Campaign.Bucket.FIELDS] = 2
	campaign.labor[Campaign.Bucket.ROSTER] = 1
	campaign.bench = [1, 2, 3, 4] as Array[int]
	campaign.basin = BasinRing.opening()
	return campaign
