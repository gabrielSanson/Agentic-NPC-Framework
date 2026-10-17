class_name NpcfKevAdapter
extends NpcfProviderAdapter
## The Kev choice server (kev.serve) for CHOOSE: one POST /v1/systemone carries every question of a turn as a
## choice question. Health is the default (any answer below 500 counts as up). parse() is tolerant about the
## name of the chosen option: answer, option or choice, whichever is a non-empty String first.


## One choice question: the options in order, each with its description (same order as options).
class Question extends RefCounted:
	var id: StringName = &""
	var instructions: String = ""
	var options: Array[StringName] = []
	var descriptions: Array[String] = []


## One answer: the chosen option, its confidence and the probability of each option.
class Choice extends RefCounted:
	var option: StringName = &""
	var confidence: float = 0.0
	var probabilities: Dictionary[StringName, float] = {}


func kind() -> NpcfProviderConfig.Kind:
	return NpcfProviderConfig.Kind.CHOOSE


func build(cfg: NpcfProviderConfig, state: String, questions: Array[Question]) -> NpcfHttpSpec:
	var qs: Dictionary = {}
	for q: Question in questions:
		var criteria: Dictionary = {}
		for i: int in q.options.size():
			var option: String = String(q.options[i])
			var description: String = q.descriptions[i] if i < q.descriptions.size() else ""
			criteria[option] = description if description != "" else option
		qs[String(q.id)] = {"type": "choice", "instructions": q.instructions, "criteria": criteria}
	var model: String = cfg.model if cfg.model != "" else "kev-latest"
	var d: Dictionary = {"state": state, "model": model, "questions": qs}
	var s: NpcfHttpSpec = NpcfHttpSpec.new()
	s.method = HTTPClient.METHOD_POST
	s.path = "/v1/systemone"
	s.headers = PackedStringArray(["Content-Type: application/json"])
	# sort_keys false: the options keep their authored order on the wire (the server lists them in that order).
	s.body = JSON.stringify(d, "", false).to_utf8_buffer()
	s.timeout_ms = cfg.effective_timeout_ms()
	return s


## The answers that could be read, by question id. Empty unless the request was ok. A question with a missing or
## malformed answer is left out.
func parse(r: NpcfHttpResult) -> Dictionary[StringName, Choice]:
	var out: Dictionary[StringName, Choice] = {}
	if r.status != &"ok":
		return out
	var data: Dictionary = r.json()
	var answers_v: Variant = data.get("answers")
	if not (answers_v is Dictionary):
		return out
	var answers: Dictionary = answers_v
	for key: Variant in answers.keys():
		var answer_v: Variant = answers[key]
		if not (answer_v is Dictionary):
			continue
		var answer: Dictionary = answer_v
		var option: String = _option_of(answer)
		if option == "":
			continue
		var choice: Choice = Choice.new()
		choice.option = StringName(option)
		choice.probabilities = _probabilities_of(answer)
		choice.confidence = _confidence_of(answer, choice.probabilities)
		out[StringName(str(key))] = choice
	return out


## The option named by the first of answer, option, choice that is a non-empty String.
static func _option_of(answer: Dictionary) -> String:
	for field: String in ["answer", "option", "choice"]:
		var v: Variant = answer.get(field)
		if v is String:
			var s: String = v
			if s != "":
				return s
	return ""


## The numeric probabilities; entries that are not numbers are skipped.
static func _probabilities_of(answer: Dictionary) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	var probs_v: Variant = answer.get("probabilities")
	if not (probs_v is Dictionary):
		return out
	var probs: Dictionary = probs_v
	for k: Variant in probs.keys():
		var num: float = 0.0
		var v: Variant = probs[k]
		if v is float:
			num = v
		elif v is int:
			var as_int: int = v
			num = float(as_int)
		else:
			continue
		out[StringName(str(k))] = num
	return out


## The reported confidence. Without one: the highest probability. Without both: 1.0 (an option was named).
static func _confidence_of(answer: Dictionary, probs: Dictionary[StringName, float]) -> float:
	var conf_v: Variant = answer.get("confidence")
	if conf_v is float:
		var c: float = conf_v
		return c
	if conf_v is int:
		var ci: int = conf_v
		return float(ci)
	if not probs.is_empty():
		var best: float = -1.0
		for k: StringName in probs:
			var p: float = probs[k]
			best = maxf(best, p)
		return best
	return 1.0
