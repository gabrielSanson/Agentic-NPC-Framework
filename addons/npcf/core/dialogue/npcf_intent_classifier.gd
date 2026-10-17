class_name NpcfIntentClassifier
extends RefCounted
## Turns player text into an intent (R13.2). The dialogue service applies the threshold and fallback afterwards,
## so every classifier is treated alike. on_done receives one NpcfIntentResult, exactly once.


func classify(_text: String, _intents: Array[NpcfIntentDef], _ctx: NpcfDialogueContext, on_done: Callable) -> void:
	on_done.call(NpcfIntentResult.make(&"", 0.0, &"none"))
