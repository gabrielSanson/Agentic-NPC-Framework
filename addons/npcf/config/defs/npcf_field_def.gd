@tool
class_name NpcfFieldDef
extends Resource
## One typed field of an event payload or of action arguments (R3.5).

## Field types. ANY is reserved for framework event kinds and rejected in packs.
enum FieldType { BOOL, INT, FLOAT, STRING_NAME, ANY }

@export var name: StringName = &""
@export var type: FieldType = FieldType.STRING_NAME
@export var required: bool = true


static func make(p_name: StringName, p_type: FieldType, p_required: bool = true) -> NpcfFieldDef:
	var f: NpcfFieldDef = NpcfFieldDef.new()
	f.name = p_name
	f.type = p_type
	f.required = p_required
	return f


## Checks `values` against `fields`. Returns an empty string when valid, else the reason
## (`missing field "x"`, `field "x" must be int`, `unknown field "y"`).
static func validate(fields: Array[NpcfFieldDef], values: Dictionary[StringName, Variant]) -> String:
	var known: Dictionary[StringName, bool] = {}
	for f: NpcfFieldDef in fields:
		known[f.name] = true
		if not values.has(f.name):
			if f.required:
				return "missing field \"%s\"" % f.name
			continue
		if f.type != FieldType.ANY and not NpcfFactDef.type_matches(f.type, values[f.name]):
			return "field \"%s\" must be %s" % [f.name, NpcfFactDef.type_name(f.type)]
	for k: StringName in values:
		if not known.has(k):
			return "unknown field \"%s\"" % k
	return ""
