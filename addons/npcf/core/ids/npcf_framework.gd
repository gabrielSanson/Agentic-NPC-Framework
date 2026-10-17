class_name NpcfFramework
extends RefCounted
## Definitions the framework itself contributes: the `npcf.at` fact, the framework event kinds
## and the `npcf.move_to` action. Built once per loaded pack.

const GLOBAL: StringName = NpcfIds.GLOBAL_SUBJECT
const AT: StringName = &"npcf.at"
const FACT_CHANGED: StringName = &"npcf.fact_changed"
const EXPECTATION_FAILED: StringName = &"npcf.expectation_failed"
const ARRIVED: StringName = &"npcf.arrived"
const DEPARTED: StringName = &"npcf.departed"
const TAGS_CHANGED: StringName = &"npcf.tags_changed"
const NEED_THRESHOLD: StringName = &"npcf.need_threshold"
const CONVERSATION: StringName = &"npcf.conversation"
const MOVE_TO: StringName = &"npcf.move_to"


static func at_fact() -> NpcfFactDef:
	var f: NpcfFactDef = NpcfFactDef.new()
	f.id = AT
	f.scope = NpcfFactDef.Scope.ENTITY
	f.value_type = NpcfFactDef.ValueType.STRING_NAME
	f.default_value = &""
	f.public = false
	f.shareable = true
	return f


static func event_kinds() -> Array[NpcfEventKindDef]:
	var sn: NpcfFieldDef.FieldType = NpcfFieldDef.FieldType.STRING_NAME
	var any: NpcfFieldDef.FieldType = NpcfFieldDef.FieldType.ANY
	return [
		_kind(FACT_CHANGED, [NpcfFieldDef.make(&"subject", sn), NpcfFieldDef.make(&"fact", sn), NpcfFieldDef.make(&"value", any)], NpcfEvent.Visibility.LOCAL, 20),
		_kind(EXPECTATION_FAILED, [NpcfFieldDef.make(&"subject", sn), NpcfFieldDef.make(&"fact", sn), NpcfFieldDef.make(&"value", any)], NpcfEvent.Visibility.PARTICIPANTS_ONLY, 30),
		_kind(ARRIVED, [], NpcfEvent.Visibility.LOCAL, 5),
		_kind(DEPARTED, [], NpcfEvent.Visibility.LOCAL, 5),
		_kind(TAGS_CHANGED, [NpcfFieldDef.make(&"tag", sn), NpcfFieldDef.make(&"added", NpcfFieldDef.FieldType.BOOL)], NpcfEvent.Visibility.LOCAL, 20),
		_kind(NEED_THRESHOLD, [NpcfFieldDef.make(&"need", sn), NpcfFieldDef.make(&"threshold", sn), NpcfFieldDef.make(&"direction", sn)], NpcfEvent.Visibility.PARTICIPANTS_ONLY, 0),
	]


static func move_to_action() -> NpcfActionDef:
	var a: NpcfActionDef = NpcfActionDef.new()
	a.id = MOVE_TO
	a.tier = NpcfActionDef.Tier.RULES
	a.args = [NpcfFieldDef.make(&"location", NpcfFieldDef.FieldType.STRING_NAME)]
	a.cost = 1.0
	a.duration_ticks = 1
	return a


static func _kind(id: StringName, fields: Array[NpcfFieldDef], visibility: NpcfEvent.Visibility, salience: int) -> NpcfEventKindDef:
	var k: NpcfEventKindDef = NpcfEventKindDef.new()
	k.id = id
	k.payload_fields = fields
	k.visibility = visibility
	k.salience = salience
	return k
