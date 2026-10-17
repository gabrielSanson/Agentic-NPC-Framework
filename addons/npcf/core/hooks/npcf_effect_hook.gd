class_name NpcfEffectHook
extends RefCounted
## Extension point: computes state changes for an action effect. The changes are validated as a
## batch and applied only if all of them are valid. Safe default on failure: no changes, and the
## action fails with `hook_error`.


func compute(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> Array[NpcfStateChange]:
	return []
