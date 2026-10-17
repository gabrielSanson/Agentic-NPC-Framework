extends GdUnitTestSuite
## The LLM prompt (R13.5): undeclared macros fail at load, the variant follows its condition, macros read only the
## NPC's own view, the persona joins the voice, facts get handles and the cap holds, and actions and memories render.

const ANA: StringName = &"toy.ana"
const PLAYER: StringName = &"toy.player"
const TAG_WEARY: StringName = &"toy.weary"
const WAVE: StringName = &"toy.wave"

var _worlds: Array[NpcfWorld] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## The toy world with the player at Ana's house and a fresh copy of the dialogue.
func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(PLAYER, NpcfFramework.AT, &"toy.home_a")]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")
	return w


## Loads the toy pack with a dialogue copy that `change` edits, and returns the load result.
func _load_with(change: Callable) -> NpcfLoadResult:
	var manifest: NpcfPackManifest = ResourceLoader.load(ToyFixture.MANIFEST, "", ResourceLoader.CACHE_MODE_IGNORE) as NpcfPackManifest
	manifest.dialogue = DialogueFixture.fresh_dialogue()
	change.call(manifest.dialogue)
	return NpcfPackLoader.new().load_pack(manifest)


## Runs one player turn to Ana with a fake transport and returns the request it sent.
func _request(w: NpcfWorld, text: String) -> NpcfDialogueRequest:
	var transport: NpcfFakeLlmTransport = NpcfFakeLlmTransport.new()
	var gen: NpcfLlmLineGenerator = NpcfLlmLineGenerator.new(transport)
	w.dialogue.generator = gen
	var line_id: int = w.dialogue.begin_turn(w, text, ANA)
	assert_int(line_id).is_greater(0)
	assert_int(transport.requests.size()).is_equal(1)
	if transport.requests.is_empty():
		return null
	return transport.requests[0]


func _content(request: NpcfDialogueRequest, role: StringName) -> String:
	for m: NpcfChatMessage in request.messages:
		if m.role == role:
			return m.content
	return ""


func _add_belief(w: NpcfWorld, subject: StringName, confidence: int) -> void:
	var meta: NpcfBeliefMeta = NpcfBeliefMeta.new()
	meta.confidence = confidence
	meta.tick = w.clock.tick
	meta.source = NpcfBelief.Source.WITNESSED
	w.npc(ANA).beliefs.put(NpcfFact.make(subject, &"toy.sighting", true), meta)


func test_an_undeclared_macro_fails_to_load() -> void:
	var result: NpcfLoadResult = _load_with(func(d: NpcfDialogueDef) -> void:
		d.default_template.scenario_text = "{{mood}} {{npc_name}} {{situation}} {{memories}}.")
	assert_bool(result.ok).is_false()
	assert_str(result.format_errors()).contains("\"{{mood}}\" is not a declared macro")


func test_the_variant_follows_the_tag() -> void:
	var w: NpcfWorld = _world()
	var request: NpcfDialogueRequest = _request(w, "hello hey")
	assert_str(str(request.variant)).is_equal("toy.default")
	assert_str(_content(request, &"user")).contains("It is an ordinary day.")

	var tag: Array[NpcfStateChange] = [NpcfStateChange.tag_change(ANA, TAG_WEARY, true)]
	assert_str(w.applier.apply(w, tag, -1, true)).is_equal("")
	request = _request(w, "hello hey")
	assert_str(str(request.variant)).is_equal("toy.tired")
	assert_str(_content(request, &"user")).contains("Ana is exhausted")


func test_macros_come_only_from_the_npcs_own_view() -> void:
	var w: NpcfWorld = _world()
	var truth: Array[NpcfStateChange] = [NpcfStateChange.set_fact(&"toy.yard", &"toy.sighting", true)]
	assert_str(w.applier.apply(w, truth, -1, true)).is_equal("")
	var request: NpcfDialogueRequest = _request(w, "hello hey")
	for h: StringName in request.handles:
		assert_str(str(request.handles[h].subject)).is_not_equal("toy.yard")
	assert_str(_content(request, &"system")).not_contains("toy.sighting = true")

	_add_belief(w, &"toy.yard", 80)
	request = _request(w, "seen any news?")
	assert_str(str(request.handles[&"f1"].subject)).is_equal("toy.yard")
	assert_str(str(request.handles[&"f1"].fact_id)).is_equal("toy.sighting")
	assert_str(_content(request, &"system")).contains("f1: toy.yard toy.sighting = true")


func test_the_persona_is_the_joined_voice() -> void:
	var w: NpcfWorld = _world()
	var request: NpcfDialogueRequest = _request(w, "hello hey")
	assert_str(_content(request, &"system")).contains("Drawls, yawns, and changes the subject. Speaks briskly and keeps to the point.")


func test_the_legal_actions_are_listed_and_named() -> void:
	var w: NpcfWorld = _world()
	var request: NpcfDialogueRequest = _request(w, "hello hey")
	assert_array(request.legal_actions).contains_exactly([WAVE])
	assert_str(_content(request, &"system")).contains("toy.wave()")


func test_remembered_episodes_are_rendered_and_their_ids_kept() -> void:
	var w: NpcfWorld = _world()
	var spotted: Array[StringName] = []
	var e: NpcfEvent = NpcfEvent.new()
	e.kind = &"toy.spotted"
	e.location = &"toy.home_a"
	e.actors = spotted
	w.emit(e)
	w.step()
	var request: NpcfDialogueRequest = _request(w, "hello hey")
	assert_array(request.memory_ids).is_not_empty()
	# The memory text fills {location} with the location's display name, "Ana's house".
	assert_str(_content(request, &"user")).contains("spotted something at Ana's house")


func test_the_fact_cap_keeps_one_handle() -> void:
	var w: NpcfWorld = _world()
	w.pack.dialogue.max_prompt_facts = 1
	_add_belief(w, &"toy.yard", 80)
	_add_belief(w, &"toy.home_b", 50)
	var request: NpcfDialogueRequest = _request(w, "hello hey")
	assert_int(request.handles.size()).is_equal(1)
	assert_int(request.injected_facts.size()).is_equal(1)
