class_name CampaignSave
extends Object
## Saving and loading the campaign through the plan 4.6 store (plan 07 §7.5). One save, one file: the
## campaign rides in the store beside `bowls`, so a fight ending (which writes the store) cannot lose
## it. Written at Day end and when the fireteam is home, never mid-fight: an abandoned fight keeps
## nothing, as plan 4.6 already says for what the squad learned.


## Null when there is no save, or it is damaged: the caller starts a new campaign.
static func load_campaign(path: String = KnowledgeStore.DEFAULT_PATH) -> Campaign:
	var store := KnowledgeStore.load_from(path)
	if store.campaign_data.is_empty():
		return null
	var campaign := CampaignCodec.from_dict(store.campaign_data)
	if campaign == null:
		push_warning("CampaignSave: the campaign in %s is damaged; starting fresh" % path)
		return null
	## A save is never written with the fireteam out (a fight abandoned in the middle keeps nothing).
	campaign.deployment = {}
	campaign.dispatched_today = false
	return campaign


static func save_campaign(campaign: Campaign, path: String = KnowledgeStore.DEFAULT_PATH) -> void:
	var store := KnowledgeStore.load_from(path)
	store.campaign_data = CampaignCodec.to_dict(campaign)
	store.path = path
	store.save()
