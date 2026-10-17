class_name NpcfWorldState
extends RefCounted
## Ground-truth facts per subject (design "1. World state"). Only NpcfEffectApplier writes here.

var _subjects: Dictionary[StringName, NpcfSubjectFacts] = {}
var _defs: Dictionary[StringName, NpcfFactDef] = {}


func _init(defs: Dictionary[StringName, NpcfFactDef] = {}) -> void:
	_defs = defs


func fact_def(fact_id: StringName) -> NpcfFactDef:
	return _defs.get(fact_id)


## The stored value, or the fact's declared default when the subject never had it set.
func get_fact(subject: StringName, fact_id: StringName) -> Variant:
	var sf: NpcfSubjectFacts = _subjects.get(subject)
	if sf != null and sf.values.has(fact_id):
		return sf.values[fact_id]
	var def: NpcfFactDef = _defs.get(fact_id)
	return def.default_value if def != null else null


func has_fact(subject: StringName, fact_id: StringName) -> bool:
	var sf: NpcfSubjectFacts = _subjects.get(subject)
	return sf != null and sf.values.has(fact_id)


## Writes a value without validation. Only NpcfEffectApplier calls this.
func write(subject: StringName, fact_id: StringName, value: Variant) -> void:
	var sf: NpcfSubjectFacts = _subjects.get(subject)
	if sf == null:
		sf = NpcfSubjectFacts.new()
		_subjects[subject] = sf
	sf.values[fact_id] = value


## Subjects with at least one stored fact, sorted.
func subjects() -> Array[StringName]:
	var out: Array[StringName] = _subjects.keys()
	out.sort_custom(NpcfWorldState.name_less)
	return out


## Fact IDs stored for a subject, sorted.
func facts_of(subject: StringName) -> Array[StringName]:
	var sf: NpcfSubjectFacts = _subjects.get(subject)
	if sf == null:
		return []
	var out: Array[StringName] = sf.values.keys()
	out.sort_custom(NpcfWorldState.name_less)
	return out


## Stored facts in live order, [[subject, [[fact_id, value], ...]], ...], for saves.
func export_rows() -> Array:
	var out: Array = []
	for subject: StringName in _subjects:
		var sf: NpcfSubjectFacts = _subjects[subject]
		var pairs: Array = []
		for fact_id: StringName in sf.values:
			pairs.append([fact_id, sf.values[fact_id]])
		out.append([subject, pairs])
	return out


## Sort predicate for StringNames by string value (determinism rule).
static func name_less(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)
