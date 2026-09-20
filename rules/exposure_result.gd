class_name Exposure
extends RefCounted
## Who can see this unit (UI §4.2). count vs sources.size() gap = hidden watchers.

enum State {
	HIDDEN,
	EXPOSED,
	NO_HIDE,
}

var state: State = State.HIDDEN
## Every hostile with a clean line, including hidden watchers.
var count: int = 0
## Hostile cells the viewer can locate (apex / body visible). May be < count.
var sources: Array[Vector3i] = []
