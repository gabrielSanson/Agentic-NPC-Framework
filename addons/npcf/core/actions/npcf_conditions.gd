class_name NpcfConditions
extends RefCounted
## Evaluates condition definitions for an NPC view (R5.4) and resolves subjects (shared with the
## effect applier). Static helpers only.


## The entity a condition or effect is about. Unknown or missing values give &"" (never an error).
static func subject(world: NpcfWorld, npc: StringName, from: NpcfConditionDef.SubjectFrom, arg: StringName, args: Dictionary[StringName, Variant]) -> StringName:
	match from:
		NpcfConditionDef.SubjectFrom.SELF:
			return npc
		NpcfConditionDef.SubjectFrom.ARG:
			var v: Variant = args.get(arg, &"")
			if typeof(v) == TYPE_STRING_NAME:
				var s: StringName = v
				return s
			return &""
		NpcfConditionDef.SubjectFrom.CURRENT_LOCATION:
			return world.location_of(npc)
		NpcfConditionDef.SubjectFrom.GLOBAL:
			return NpcfFramework.GLOBAL
		NpcfConditionDef.SubjectFrom.PLAYER:
			return world.sim.player_entity
	return &""


## True when `c` holds for the NPC behind `view`. An ARG subject whose argument is missing gives
## `args_pending`: legality checks pass true, start revalidation passes false.
static func check(world: NpcfWorld, view: NpcfNpcView, c: NpcfConditionDef, args: Dictionary[StringName, Variant], args_pending: bool = false) -> bool:
	match c.op_kind:
		NpcfConditionDef.OpKind.FACT:
			if c.subject_from == NpcfConditionDef.SubjectFrom.ARG and not args.has(c.arg):
				return args_pending
			var subj: StringName = subject(world, view.npc_id(), c.subject_from, c.arg, args)
			var r: NpcfFactRead = view.fact(subj, c.fact.id)
			if c.compare == NpcfConditionDef.Compare.EXISTS:
				return r.confidence >= c.min_confidence
			if r.confidence < c.min_confidence:
				return false
			return compare(r.value, c.compare, c.value)
		NpcfConditionDef.OpKind.NEED:
			return compare(view.need(c.need.id), c.compare, c.value)
		NpcfConditionDef.OpKind.TAG:
			if c.subject_from == NpcfConditionDef.SubjectFrom.ARG and not args.has(c.arg):
				return args_pending
			if c.subject_from == NpcfConditionDef.SubjectFrom.SELF:
				return view.has_tag(c.tag)
			var tsubj: StringName = subject(world, view.npc_id(), c.subject_from, c.arg, args)
			var tags: Array[StringName] = view.tags_of(tsubj)
			return tags.has(c.tag)
		NpcfConditionDef.OpKind.AT_LOCATION:
			if c.subject_from == NpcfConditionDef.SubjectFrom.ARG and not args.has(c.arg):
				return args_pending
			var loc: StringName = view.location()
			if c.subject_from != NpcfConditionDef.SubjectFrom.SELF and c.subject_from != NpcfConditionDef.SubjectFrom.CURRENT_LOCATION:
				loc = view.location_of(subject(world, view.npc_id(), c.subject_from, c.arg, args))
			if c.location != null:
				return loc == c.location.id
			return world.pack.location_index.has_tag(loc, c.location_tag)
		NpcfConditionDef.OpKind.ALL:
			for child: NpcfConditionDef in c.children:
				if not check(world, view, child, args, args_pending):
					return false
			return true
		NpcfConditionDef.OpKind.ANY:
			for child: NpcfConditionDef in c.children:
				if check(world, view, child, args, args_pending):
					return true
			return false
		NpcfConditionDef.OpKind.NOT:
			if c.children.is_empty():
				return false
			return not check(world, view, c.children[0], args, args_pending)
		NpcfConditionDef.OpKind.HOOK:
			var merged: Dictionary[StringName, Variant] = c.hook_args.duplicate()
			merged.merge(args)
			return world.hooks.condition(c.hook, view, merged)
	return false


## The FACT leaves that are false under the truth view and whose value under the NPC's view differs.
## Used to report expectation_failed when an NPC's belief was wrong. The result carries the truth.
static func mismatched_facts(world: NpcfWorld, npc_view: NpcfNpcView, truth_view: NpcfNpcView, c: NpcfConditionDef, args: Dictionary[StringName, Variant]) -> Array[NpcfFact]:
	var out: Array[NpcfFact] = []
	match c.op_kind:
		NpcfConditionDef.OpKind.FACT:
			if c.fact == null or (c.subject_from == NpcfConditionDef.SubjectFrom.ARG and not args.has(c.arg)):
				return out
			var subj: StringName = subject(world, npc_view.npc_id(), c.subject_from, c.arg, args)
			if check(world, truth_view, c, args):
				return out
			var believed: Variant = npc_view.fact(subj, c.fact.id).value
			var actual: Variant = truth_view.fact(subj, c.fact.id).value
			if believed != actual:
				out.append(NpcfFact.make(subj, c.fact.id, actual))
		NpcfConditionDef.OpKind.ALL, NpcfConditionDef.OpKind.ANY, NpcfConditionDef.OpKind.NOT:
			for child: NpcfConditionDef in c.children:
				out.append_array(mismatched_facts(world, npc_view, truth_view, child, args))
	return out


## Compares two values. Numbers compare as floats; EQ and NE also work on bools and StringNames;
## ordered comparison of anything else is false.
static func compare(a: Variant, op: NpcfConditionDef.Compare, b: Variant) -> bool:
	if _is_number(a) and _is_number(b):
		var x: float = a
		var y: float = b
		match op:
			NpcfConditionDef.Compare.EQ:
				return x == y
			NpcfConditionDef.Compare.NE:
				return x != y
			NpcfConditionDef.Compare.LT:
				return x < y
			NpcfConditionDef.Compare.LE:
				return x <= y
			NpcfConditionDef.Compare.GT:
				return x > y
			NpcfConditionDef.Compare.GE:
				return x >= y
		return false
	match op:
		NpcfConditionDef.Compare.EQ:
			return a == b
		NpcfConditionDef.Compare.NE:
			return a != b
	return false


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
