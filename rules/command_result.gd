class_name CommandResult
extends RefCounted
## Outcome of Command.validate — never mutates state.

var ok: bool = false
var reason: String = ""


static func success() -> CommandResult:
	var r := CommandResult.new()
	r.ok = true
	return r


static func failure(p_reason: String) -> CommandResult:
	var r := CommandResult.new()
	r.ok = false
	r.reason = p_reason
	return r
