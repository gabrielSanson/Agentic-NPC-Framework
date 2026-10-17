class_name NpcfEvent
extends RefCounted
## A committed event. Payload values are validated against the event kind's fields on emit.

## Who receives an event besides its participants (NpcfEventKindDef.visibility mirrors this).
enum Visibility { LOCAL, PUBLIC, PARTICIPANTS_ONLY }

var id: int = -1
var tick: int = 0
var kind: StringName = &""
var actors: Array[StringName] = []
var targets: Array[StringName] = []
var location: StringName = &""
var payload: Dictionary[StringName, Variant] = {}
var salience: int = 0
var visibility: int = Visibility.LOCAL


func to_dict() -> Dictionary:
	return {
		"id": id, "tick": tick, "kind": String(kind), "actors": NpcfValueCodec.names(actors),
		"targets": NpcfValueCodec.names(targets), "location": String(location),
		"payload": NpcfValueCodec.encode_dict(payload), "salience": salience, "visibility": visibility,
	}


## Save form: Variant values are tagged (see NpcfSaveCodec); payload pairs keep live order.
func to_save() -> Dictionary:
	var rows: Array = []
	for k: StringName in payload:
		rows.append([String(k), NpcfSaveCodec.encode_value(payload[k], "event payload")])
	return {
		"id": id, "tick": tick, "kind": String(kind), "actors": NpcfValueCodec.names(actors),
		"targets": NpcfValueCodec.names(targets), "location": String(location), "payload": rows,
		"salience": salience, "visibility": visibility,
	}


## Reads an event written by to_save. Event kinds the pack does not define fail the reader.
static func from_save(r: NpcfSaveCodec.Reader, d: Variant, path: String) -> NpcfEvent:
	var e: NpcfEvent = NpcfEvent.new()
	e.id = r.int_at(d, "id", path)
	e.tick = r.int_at(d, "tick", path)
	e.kind = r.name_at(d, "kind", path)
	if not r.known_kinds.has(e.kind):
		r.fail("%s: unknown event kind %s" % [path, e.kind])
	e.actors = r.names_at(d, "actors", path)
	e.targets = r.names_at(d, "targets", path)
	e.location = r.name_at(d, "location", path)
	for row: Variant in r.arr_at(d, "payload", path):
		var kv: Array = r.pair_v(row, path + ".payload")
		var key: StringName = r.name_v(kv[0], path + ".payload")
		e.payload[key] = r.value_v(kv[1], path + ".payload")
	e.salience = r.int_at(d, "salience", path)
	e.visibility = r.int_at(d, "visibility", path)
	return e
