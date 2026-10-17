class_name NpcfMemoryRecord
extends RefCounted
## One entry in an NPC's capped episodic log. Used for dialogue context and traces only (R7.4).

var id: int = -1
var tick: int = 0
var event_id: int = -1
var kind: StringName = &""
var subjects: Array[StringName] = []
var location: StringName = &""
var source: int = NpcfBelief.Source.WITNESSED
var salience: int = 0
var message_key: StringName = &""
var params: Dictionary[StringName, Variant] = {}


func to_dict() -> Dictionary:
	return {
		"id": id, "tick": tick, "event_id": event_id, "kind": String(kind),
		"subjects": NpcfValueCodec.names(subjects), "location": String(location), "source": source,
		"salience": salience, "message_key": String(message_key), "params": NpcfValueCodec.encode_dict(params),
	}


## Save form: parameter values are tagged (see NpcfSaveCodec); pairs keep live order.
func to_save() -> Dictionary:
	var rows: Array = []
	for k: StringName in params:
		rows.append([String(k), NpcfSaveCodec.encode_value(params[k], "memory params")])
	return {
		"id": id, "tick": tick, "event_id": event_id, "kind": String(kind),
		"subjects": NpcfValueCodec.names(subjects), "location": String(location), "source": source,
		"salience": salience, "message_key": String(message_key), "params": rows,
	}


## Reads a memory record written by to_save.
static func from_save(r: NpcfSaveCodec.Reader, d: Variant, path: String) -> NpcfMemoryRecord:
	var m: NpcfMemoryRecord = NpcfMemoryRecord.new()
	m.id = r.int_at(d, "id", path)
	m.tick = r.int_at(d, "tick", path)
	m.event_id = r.int_at(d, "event_id", path)
	m.kind = r.name_at(d, "kind", path)
	m.subjects = r.names_at(d, "subjects", path)
	m.location = r.name_at(d, "location", path)
	m.source = r.int_at(d, "source", path)
	m.salience = r.int_at(d, "salience", path)
	m.message_key = r.name_at(d, "message_key", path)
	for row: Variant in r.arr_at(d, "params", path):
		var kv: Array = r.pair_v(row, path + ".params")
		var key: StringName = r.name_v(kv[0], path + ".params")
		m.params[key] = r.value_v(kv[1], path + ".params")
	return m
