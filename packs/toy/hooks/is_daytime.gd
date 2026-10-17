extends NpcfConditionHook
## True between 06:00 and 22:00.


func check(view: NpcfNpcView, _args: Dictionary[StringName, Variant]) -> bool:
	var minute: int = view.minute_of_day()
	return minute >= 360 and minute <= 1320
