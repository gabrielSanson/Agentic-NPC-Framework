extends GdUnitTestSuite
## Who a player's line is addressed to: the named NPC, the NPC the player faces, the NPC last talked to, the only
## candidate in range, or nobody (none in range, ambiguous, unknown, busy).

const ANA: StringName = &"toy.ana"
const BO: StringName = &"toy.bo"
const CY: StringName = &"toy.cy"
const PLAYER: StringName = &"toy.player"

var _worlds: Array[NpcfWorld] = []
var _reasons: Array[StringName] = []
var _lines: Array[Array] = []


func after_test() -> void:
	for w: NpcfWorld in _worlds:
		w.dispose()
	_worlds.clear()


## The toy world with the player at home_a, where Ana and Cy start; Bo is at home_b.
func _world() -> NpcfWorld:
	var w: NpcfWorld = NpcfWorldBuilder.build(DialogueFixture.load_pack(), ToyFixture.basic(), 1)
	_worlds.append(w)
	_reasons.clear()
	_lines.clear()
	w.dialogue.no_addressee.connect(func(reason: StringName) -> void: _reasons.append(reason))
	w.dialogue.line.connect(func(npc: StringName, text: String, line_id: int, source: StringName, _pres: Dictionary) -> void:
		_lines.append([npc, text, line_id, source]))
	_move(w, PLAYER, &"toy.home_a")
	return w


func _move(w: NpcfWorld, entity: StringName, location: StringName) -> void:
	var changes: Array[NpcfStateChange] = [NpcfStateChange.set_fact(entity, NpcfFramework.AT, location)]
	assert_str(w.applier.apply(w, changes, -1, true)).is_equal("")


## Perception that reports a fixed facing, on top of the headless hearing rules.
class FacingPerception extends NpcfHeadlessAdapter.Perception:
	var facing: StringName = &""

	func facing_npc(_entity: StringName, _world: NpcfWorldView) -> StringName:
		return facing


## A classifier that never answers, so the turn stays pending.
class SilentClassifier extends NpcfIntentClassifier:
	func classify(_text: String, _intents: Array[NpcfIntentDef], _ctx: NpcfDialogueContext, _on_done: Callable) -> void:
		pass


func test_the_only_npc_in_range_is_addressed() -> void:
	var w: NpcfWorld = _world()
	_move(w, CY, &"toy.yard")
	var picked: Array[StringName] = w.dialogue.pick_addressee(w, &"")
	assert_array(picked).contains_exactly([ANA, &"only_candidate"])


func test_two_npcs_in_range_with_no_other_cue_is_ambiguous() -> void:
	var w: NpcfWorld = _world()
	var picked: Array[StringName] = w.dialogue.pick_addressee(w, &"")
	assert_array(picked).contains_exactly([&"", &"ambiguous"])
	var id: int = w.dialogue.begin_turn(w, "hello there", &"")
	assert_int(id).is_equal(-1)
	assert_array(_reasons).contains_exactly([&"ambiguous"])
	assert_array(_lines).is_empty()


func test_nobody_in_range_gives_none_in_range() -> void:
	var w: NpcfWorld = _world()
	_move(w, PLAYER, &"toy.yard")
	assert_array(w.dialogue.pick_addressee(w, &"")).contains_exactly([&"", &"none_in_range"])
	assert_int(w.dialogue.begin_turn(w, "hello", &"")).is_equal(-1)
	assert_array(_reasons).contains_exactly([&"none_in_range"])


func test_facing_an_npc_addresses_it_over_the_others() -> void:
	var w: NpcfWorld = _world()
	var perception: FacingPerception = FacingPerception.new()
	perception.facing = CY
	w.adapters.perception = perception
	assert_array(w.dialogue.pick_addressee(w, &"")).contains_exactly([CY, &"facing"])


func test_the_last_npc_talked_to_is_addressed_within_the_window_only() -> void:
	var w: NpcfWorld = _world()
	_move(w, CY, &"toy.yard")
	assert_int(w.dialogue.begin_turn(w, "hello hey", &"")).is_equal(1)
	_move(w, CY, &"toy.home_a")
	assert_array(w.dialogue.pick_addressee(w, &"")).contains_exactly([ANA, &"last_talked"])
	w.clock.tick += 31
	assert_array(w.dialogue.pick_addressee(w, &"")).contains_exactly([&"", &"ambiguous"])


func test_a_named_npc_is_addressed_even_when_elsewhere() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.dialogue.begin_turn(w, "hi", BO)).is_greater_equal(1)
	assert_int(_lines.size()).is_equal(1)
	assert_str(str(_lines[0][0])).is_equal(str(BO))


func test_a_named_entity_that_is_not_an_npc_is_unknown() -> void:
	var w: NpcfWorld = _world()
	assert_int(w.dialogue.begin_turn(w, "hi", PLAYER)).is_equal(-1)
	assert_array(_reasons).contains_exactly([&"unknown_npc"])


func test_a_second_turn_to_a_pending_npc_is_busy() -> void:
	var w: NpcfWorld = _world()
	w.dialogue.classifier = SilentClassifier.new()
	assert_int(w.dialogue.begin_turn(w, "hi", ANA)).is_equal(1)
	assert_int(w.dialogue.begin_turn(w, "hi again", ANA)).is_equal(-1)
	assert_array(_reasons).contains_exactly([&"busy"])
	assert_array(_lines).is_empty()
