class_name Ending
extends Object
## What the campaign's record says, as queries (plan 08 §8.2, GDD §6.6). The ending is computed from hidden
## counts and there is no score screen: nothing here draws, and nothing in the table calls it. It
## exists so the plan that writes the ending has a tested answer to ask.


## The redirections still hanging: not the first-contact card, and the bowl still wetter than before.
static func hanging_redirections(campaign: Campaign) -> Array[Redirection]:
	var out: Array[Redirection] = []
	for r in campaign.redirections:
		var redirection: Redirection = r
		if not redirection.first_contact and redirection.hangs(campaign.basin):
			out.append(redirection)
	return out


## Bitter: a redirection other than the first-contact sluice still has a hanging wet bowl at the
## end. Neighbours kept, land spent (GDD §6.6).
static func is_bitter(campaign: Campaign) -> bool:
	return not hanging_redirections(campaign).is_empty()


## Starved (GDD §6.6, civic lose): the food is gone and no Dry, un-ruined field stands to bring more in.
## A query for the plan that writes the endings; nothing draws it.
static func is_starved(campaign: Campaign) -> bool:
	if campaign.food > 0:
		return false
	return Economy.capacity(campaign) == 0


## A warm band is half of the door left open (GDD §6.6, plan 10). A query; nothing draws it.
static func has_warm_band(campaign: Campaign) -> bool:
	return Bands.warm_count(campaign) > 0


enum Act { I, II, III }


## Which act the campaign is in, read from the state and never stored (plan 11 §11.0, GDD §3.2). Act II when the
## terrace has dried; Act III when the highland has begun to build. A land bridge the player made also starts
## Act III, once plan 11.2 can say so.
static func act(campaign: Campaign) -> Act:
	if campaign.pressure.stage == Pressure.Stage.BUILDING:
		return Act.III
	var terrace: BasinBowl = campaign.basin.bowl("terrace")
	if terrace != null and terrace.step == Taxonomy.WaterStep.DRY:
		return Act.II
	return Act.I
