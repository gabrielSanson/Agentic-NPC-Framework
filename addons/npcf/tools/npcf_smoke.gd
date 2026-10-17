class_name NpcfSmoke
extends RefCounted
## Provider smoke check (C6c): runs every check a model set needs against a started runtime that already has
## use_providers() called, one step at a time, and reports each step as OK or FAIL. Used by `npcf_cli.gd smoke`.
## Knows no pack content: the NPC, the player's text and the audio come from the caller.

const SKIPPED: String = "skipped: no provider"
const SPEAK_TEXT: String = "Testing one two three."
const SPEECH_RATE: int = 24000
const TRANSCRIBE_RATE: int = 16000
const CUT_DETAIL: String = "audio arrived but the stream end was reported as cut (chunked close, see docs/providers.md)"


class Step extends RefCounted:
	var name: StringName = &""
	var ok: bool = false
	var detail: String = ""


class Report extends RefCounted:
	var steps: Array[Step] = []


	func add(step_name: StringName, step_ok: bool, detail: String) -> void:
		var s: Step = Step.new()
		s.name = step_name
		s.ok = step_ok
		s.detail = detail
		steps.append(s)


	## True when every step is ok.
	func ok() -> bool:
		for s: Step in steps:
			if not s.ok:
				return false
		return true


	## One line per step: "OK   intents  provider (cw.greet, 0.91)" or "FAIL ...".
	func lines() -> PackedStringArray:
		var out: PackedStringArray = []
		for s: Step in steps:
			var tag: String = "OK" if s.ok else "FAIL"
			out.append("%-4s %-8s %s" % [tag, String(s.name), s.detail])
		return out


## A result slot that the callbacks fill and the pump reads.
class Slot extends RefCounted:
	var done: bool = false
	var status: StringName = &""
	var text: String = ""
	var line_id: int = -1
	var bytes: PackedByteArray = PackedByteArray()
	var refused: StringName = &""


## Runs every check against a started runtime that already has use_providers() called.
## npc must be in the cast. text is what the player says. wav_pcm is 16 kHz mono s16le, or empty.
## also_poll is called on every pump turn (tests pass FakeHttpServer.poll). max_ms bounds each wait.
static func run(rt: NpcfRuntime, npc: StringName, text: String, wav_pcm: PackedByteArray,
		max_ms: int, also_poll: Callable = Callable()) -> Report:
	var report: Report = Report.new()
	var gw: NpcfProviderGateway = rt.providers()
	if gw == null:
		report.add(&"providers", false, "no provider set: call use_providers first")
		return report
	if gw.ids().is_empty():
		report.add(&"providers", false, "the set has no providers")
		return report
	_providers_step(gw, report, max_ms, also_poll)
	var speech: PackedByteArray = _voice_out_step(rt, gw, npc, report, max_ms, also_poll)
	_voice_in_step(rt, gw, report, wav_pcm, speech, max_ms, also_poll)
	_dialogue_steps(rt, gw, npc, text, report, max_ms, also_poll)
	return report


static func _providers_step(gw: NpcfProviderGateway, report: Report, max_ms: int, also_poll: Callable) -> void:
	gw.check_all_blocking(max_ms, also_poll)
	var parts: PackedStringArray = []
	var all_ready: bool = true
	for id: StringName in gw.ids():
		var state: StringName = gw.state(id)
		var part: String = "%s=%s" % [String(id), String(state)]
		if state != &"ready":
			all_ready = false
			var why: String = gw.reason(id)
			if why != "":
				part += " (" + why + ")"
		parts.append(part)
	report.add(&"providers", all_ready, ", ".join(parts))


static func _voice_out_step(rt: NpcfRuntime, gw: NpcfProviderGateway, npc: StringName, report: Report,
		max_ms: int, also_poll: Callable) -> PackedByteArray:
	if not _has_use(gw, &"voice_out"):
		report.add(&"voice_out", true, SKIPPED)
		return PackedByteArray()
	var slot: Slot = Slot.new()
	rt.speak(SPEAK_TEXT, rt.speech_instruction(npc, {}), rt.speech_voice_id(npc),
		func(pcm: PackedByteArray) -> void: slot.bytes.append_array(pcm),
		func(status: StringName) -> void:
			slot.status = status
			slot.done = true)
	if not _wait(rt, max_ms, also_poll, func() -> bool: return slot.done):
		report.add(&"voice_out", false, "no end of speech within %d ms" % max_ms)
		return PackedByteArray()
	var n: int = slot.bytes.size()
	if n > 0 and slot.status == &"ok":
		report.add(&"voice_out", true, "%d bytes at 24 kHz" % n)
	elif n > 0 and slot.status == &"http":
		report.add(&"voice_out", true, CUT_DETAIL)
	else:
		report.add(&"voice_out", false, "status %s, %d bytes" % [String(slot.status), n])
	return slot.bytes


static func _voice_in_step(rt: NpcfRuntime, gw: NpcfProviderGateway, report: Report, wav_pcm: PackedByteArray,
		speech: PackedByteArray, max_ms: int, also_poll: Callable) -> void:
	if not _has_use(gw, &"voice_in"):
		report.add(&"voice_in", true, SKIPPED)
		return
	var pcm: PackedByteArray = wav_pcm
	if pcm.is_empty():
		pcm = _speech_as_16k(speech)
	if pcm.is_empty():
		report.add(&"voice_in", false, "no audio: pass --wav")
		return
	var slot: Slot = Slot.new()
	rt.transcribe(pcm, func(heard: String, status: StringName) -> void:
		slot.text = heard
		slot.status = status
		slot.done = true)
	if not _wait(rt, max_ms, also_poll, func() -> bool: return slot.done):
		report.add(&"voice_in", false, "no transcript within %d ms" % max_ms)
		return
	if slot.status == &"ok" and slot.text != "":
		report.add(&"voice_in", true, slot.text)
	else:
		report.add(&"voice_in", false, "status %s" % String(slot.status))


## The step-2 speech (24 kHz mono) converted to 16 kHz mono s16le, for the round trip. Empty for no speech.
static func _speech_as_16k(speech: PackedByteArray) -> PackedByteArray:
	if speech.is_empty():
		return PackedByteArray()
	var mono: PackedFloat32Array = NpcfPcm.to_mono(NpcfPcm.s16le_to_frames(speech))
	return NpcfPcm.to_s16le(NpcfPcm.resample(mono, SPEECH_RATE, TRANSCRIBE_RATE))


## Sends one line to npc and checks the record of the turn: intents, presentation, then the line itself.
static func _dialogue_steps(rt: NpcfRuntime, gw: NpcfProviderGateway, npc: StringName, text: String, report: Report,
		max_ms: int, also_poll: Callable) -> void:
	var slot: Slot = Slot.new()
	var on_line: Callable = func(speaker: StringName, line: String, line_id: int, _source: StringName,
			_presentation: Dictionary) -> void:
		if speaker == npc and not slot.done:
			slot.text = line
			slot.line_id = line_id
			slot.done = true
	var on_refused: Callable = func(reason: StringName) -> void:
		slot.refused = reason
	rt.npc_line.connect(on_line)
	rt.no_addressee.connect(on_refused)
	rt.report_player_location(rt.location_of(npc))
	var turn: int = rt.player_say(text, npc)
	var answered: bool = false
	if turn >= 0:
		answered = _wait(rt, max_ms, also_poll, func() -> bool: return slot.done)
	rt.npc_line.disconnect(on_line)
	rt.no_addressee.disconnect(on_refused)
	var failure: String = ""
	var rec: NpcfDialogueTurnRecord = null
	if turn < 0:
		failure = "no dialogue turn (%s)" % String(slot.refused)
	elif not answered:
		failure = "no line within %d ms" % max_ms
	else:
		var recs: Array[NpcfDialogueTurnRecord] = rt.dialogue_records()
		if recs.is_empty() or recs.back().line_id != slot.line_id:
			failure = "no turn record for line %d" % slot.line_id
		else:
			rec = recs.back()
	_intent_step(gw, rec, failure, report)
	_presentation_step(gw, rec, failure, report)
	_lines_step(gw, rec, slot.text, failure, report)


static func _intent_step(gw: NpcfProviderGateway, rec: NpcfDialogueTurnRecord, failure: String, report: Report) -> void:
	if not _has_use(gw, &"intents"):
		report.add(&"intents", true, SKIPPED)
	elif failure != "":
		report.add(&"intents", false, failure)
	elif rec.classifier_source != &"provider":
		report.add(&"intents", false, "keyword fallback (Kev not used)")
	elif rec.fell_back:
		report.add(&"intents", false, "provider answer fell back to %s (%.2f)" % [String(rec.intent), rec.confidence])
	else:
		report.add(&"intents", true, "provider (%s, %.2f)" % [String(rec.intent), rec.confidence])


static func _presentation_step(gw: NpcfProviderGateway, rec: NpcfDialogueTurnRecord, failure: String,
		report: Report) -> void:
	if not _has_use(gw, &"presentation"):
		report.add(&"presentation", true, SKIPPED)
	elif failure != "":
		report.add(&"presentation", false, failure)
	elif rec.presentation.is_empty():
		report.add(&"presentation", false, "the turn has no presentation answers")
	else:
		var parts: PackedStringArray = []
		for key: StringName in rec.presentation:
			parts.append("%s=%s" % [String(key), String(rec.presentation[key])])
		var note: String = " (the turn record does not show which chooser answered)"
		report.add(&"presentation", true, ", ".join(parts) + note)


static func _lines_step(gw: NpcfProviderGateway, rec: NpcfDialogueTurnRecord, line: String, failure: String,
		report: Report) -> void:
	if not _has_use(gw, &"lines"):
		report.add(&"lines", true, SKIPPED)
	elif failure != "":
		report.add(&"lines", false, failure)
	elif rec.line_source == &"llm":
		report.add(&"lines", true, line)
	else:
		report.add(&"lines", false, "authored line (llm_status %s, failure %s)" % [String(rec.llm_status), String(rec.failure)])


static func _has_use(gw: NpcfProviderGateway, use: StringName) -> bool:
	for id: StringName in gw.ids():
		var cfg: NpcfProviderConfig = gw.config(id)
		if cfg != null and cfg.use_for.has(use):
			return true
	return false


## Polls the gateway (and also_poll) until done is true or max_ms passes. Returns done's last value.
static func _wait(rt: NpcfRuntime, max_ms: int, also_poll: Callable, done: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + max_ms
	var finished: bool = done.call()
	while not finished and Time.get_ticks_msec() < deadline:
		rt.providers().poll()
		if also_poll.is_valid():
			also_poll.call()
		OS.delay_msec(5)
		finished = done.call()
	return finished
