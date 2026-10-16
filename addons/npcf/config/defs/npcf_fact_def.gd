@tool
class_name NpcfFactDef
extends Resource
## Declares one fact: a typed value stored per subject (R5.1).

## Which subjects hold this fact.
enum Scope { GLOBAL, ENTITY, LOCATION }
## The value's type. Values are checked against it on load and on every write.
enum ValueType { BOOL, INT, FLOAT, STRING_NAME }

## Namespaced ID, for example `toy.widgets`.
@export var id: StringName = &""
@export var scope: Scope = Scope.ENTITY
@export var value_type: ValueType = ValueType.BOOL
## Value used when a subject has never had the fact set. Must match value_type.
@export var default_value: Variant = false
## Public facts are read from world state by every NPC; others are read from beliefs.
@export var public: bool = false
## Shareable facts can spread by rumor (task 17).
@export var shareable: bool = false
## Numbers only: when true, writes outside min_value..max_value are rejected.
@export var bounded: bool = false
@export var min_value: float = 0.0
@export var max_value: float = 0.0


## True when `v` has this fact's value type.
func accepts(v: Variant) -> bool:
	return NpcfFactDef.type_matches(value_type, v)


## True when `v` has the given ValueType. INT accepts only ints; FLOAT accepts ints and floats.
static func type_matches(t: int, v: Variant) -> bool:
	match t:
		ValueType.BOOL:
			return typeof(v) == TYPE_BOOL
		ValueType.INT:
			return typeof(v) == TYPE_INT
		ValueType.FLOAT:
			return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT
		ValueType.STRING_NAME:
			return typeof(v) == TYPE_STRING_NAME
	return false


## True when `v` is inside the declared bounds (always true for unbounded or non-numeric facts).
func in_bounds(v: Variant) -> bool:
	if not bounded or not (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT):
		return true
	var f: float = v
	return f >= min_value and f <= max_value


## The type name used in error messages.
static func type_name(t: int) -> String:
	var n: String = ValueType.keys()[t]
	return n.to_lower()
