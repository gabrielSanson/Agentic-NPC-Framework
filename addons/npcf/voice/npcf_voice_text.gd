class_name NpcfVoiceText
extends RefCounted
## Builds what the speech server is told about an NPC's voice. Pure; reads config only.


## The NPC's speech instruction: its layers' text (or the dialogue default), then the delivery text for the
## presentation answer of the delivery question, joined with one space. "" when there is nothing.
static func instruction(c: NpcfResolvedCharacter, d: NpcfDialogueDef, presentation: Dictionary) -> String:
	var parts: PackedStringArray = []
	var base: String = c.speech_instruction.strip_edges() if c != null else ""
	if base == "" and d != null:
		base = d.default_speech_instruction.strip_edges()
	if base != "":
		parts.append(base)
	if d != null and d.delivery_question != &"" and presentation.has(d.delivery_question):
		var answer: Variant = presentation[d.delivery_question]
		if answer is StringName or answer is String:
			var key: StringName = StringName(str(answer))
			var extra: String = d.delivery_instructions.get(key, "")
			extra = extra.strip_edges()
			if extra != "":
				parts.append(extra)
	return " ".join(parts)


## The NPC's voice_id, or the dialogue default, or "".
static func voice_id(c: NpcfResolvedCharacter, d: NpcfDialogueDef) -> String:
	if c != null and c.speech_voice_id != "":
		return c.speech_voice_id
	return d.default_speech_voice_id.strip_edges() if d != null else ""
