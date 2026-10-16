class_name NpcfValueCodec
extends RefCounted
## Encodes fact and payload values for JSON-friendly dictionaries (event logs, traces, saves).
## A StringName is written as "&name" so it stays distinguishable from a String; ints stay ints.
## Task 21 extends this into the full save codec.


## Encodes one value: bool, int and float as themselves, StringName as "&name", String as is.
static func encode(v: Variant) -> Variant:
	match typeof(v):
		TYPE_STRING_NAME:
			var sn: StringName = v
			return "&" + String(sn)
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return v
		_:
			return var_to_str(v)


## Encodes a typed payload dictionary with keys sorted.
static func encode_dict(d: Dictionary[StringName, Variant]) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array[StringName] = d.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for k: StringName in keys:
		out[String(k)] = encode(d[k])
	return out


## Encodes an array of StringNames as plain strings.
static func names(a: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for n: StringName in a:
		out.append(String(n))
	return out
