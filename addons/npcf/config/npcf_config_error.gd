class_name NpcfConfigError
extends RefCounted
## One configuration error, with the resource file, the property path inside it
## (`personalities[1].goal_multipliers["toy.rest"]`), the reason and a fix hint (R4.2).

var resource_path: String = ""
var property_path: String = ""
var reason: String = ""
var hint: String = ""


static func make(p_resource_path: String, p_property_path: String, p_reason: String, p_hint: String = "") -> NpcfConfigError:
	var e: NpcfConfigError = NpcfConfigError.new()
	e.resource_path = p_resource_path
	e.property_path = p_property_path
	e.reason = p_reason
	e.hint = p_hint
	return e


## `path: property: reason (hint: ...)`, with the parts that are empty left out.
func format() -> String:
	var s: String = resource_path if resource_path != "" else "<unsaved resource>"
	if property_path != "":
		s += ": " + property_path
	s += ": " + reason
	if hint != "":
		s += " (hint: %s)" % hint
	return s
