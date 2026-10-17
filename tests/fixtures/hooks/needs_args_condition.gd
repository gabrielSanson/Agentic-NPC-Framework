extends NpcfConditionHook
## Fixture: a condition hook whose constructor needs an argument (loader must reject it).

var _limit: int = 0


func _init(limit: int) -> void:
	_limit = limit


func check(_view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> bool:
	return _limit > 0
