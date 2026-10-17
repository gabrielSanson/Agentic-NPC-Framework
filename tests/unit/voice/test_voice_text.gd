extends GdUnitTestSuite
## NpcfVoiceText: the speech instruction and voice_id that the speech server is told about an NPC.


func _char(instruction: String, voice_id: String = "") -> NpcfResolvedCharacter:
	var c: NpcfResolvedCharacter = NpcfResolvedCharacter.new()
	c.speech_instruction = instruction
	c.speech_voice_id = voice_id
	return c


func _dialogue(default_instruction: String = "", default_voice: String = "") -> NpcfDialogueDef:
	var d: NpcfDialogueDef = NpcfDialogueDef.new()
	d.default_speech_instruction = default_instruction
	d.default_speech_voice_id = default_voice
	d.delivery_question = &"x.mood"
	var extra: Dictionary[StringName, String] = {&"x.sad": "Quietly."}
	d.delivery_instructions = extra
	return d


func test_character_text_alone() -> void:
	assert_str(NpcfVoiceText.instruction(_char("A."), null, {})).is_equal("A.")


func test_dialogue_default_when_character_has_none() -> void:
	assert_str(NpcfVoiceText.instruction(_char(""), _dialogue("D."), {})).is_equal("D.")


func test_delivery_text_is_appended() -> void:
	var out: String = NpcfVoiceText.instruction(_char("A."), _dialogue(), {&"x.mood": &"x.sad"})
	assert_str(out).is_equal("A. Quietly.")


func test_delivery_text_is_skipped_when_not_applicable() -> void:
	var d: NpcfDialogueDef = _dialogue()
	assert_str(NpcfVoiceText.instruction(_char("A."), d, {&"x.mood": &"x.happy"})).is_equal("A.")
	assert_str(NpcfVoiceText.instruction(_char("A."), d, {})).is_equal("A.")
	assert_str(NpcfVoiceText.instruction(_char("A."), d, {&"x.mood": 3})).is_equal("A.")


func test_everything_empty_gives_empty_string() -> void:
	assert_str(NpcfVoiceText.instruction(_char(""), _dialogue(), {})).is_equal("")
	assert_str(NpcfVoiceText.instruction(null, null, {})).is_equal("")


func test_voice_id_prefers_character_then_default() -> void:
	assert_str(NpcfVoiceText.voice_id(_char("", "v-char"), _dialogue("", "v-default"))).is_equal("v-char")
	assert_str(NpcfVoiceText.voice_id(_char(""), _dialogue("", "v-default"))).is_equal("v-default")
	assert_str(NpcfVoiceText.voice_id(_char(""), null)).is_equal("")
