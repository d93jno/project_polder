class_name ContactResult
extends RefCounted
## Whether phases start, and why (GDD §3.1). Seeing is never contact.

enum Reason {
	NONE,
	ALREADY, ## Phases had already started
	HOSTILE_LINE, ## A hostile has a clean line on a squad body
	PLAYER_FIRED,
	KNOCKED_HOSTILE_SHELTER, ## Knocked a shelter with a hostile in it
	CONTESTED_MACHINE, ## Started a machine on a tile with a Live hostile
}

var contact: bool = false
var reason: Reason = Reason.NONE
## For HOSTILE_LINE: who has the line, and on whom.
var seer_id: int = -1
var target_id: int = -1
