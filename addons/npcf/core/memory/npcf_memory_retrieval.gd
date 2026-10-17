class_name NpcfMemoryRetrieval
extends RefCounted
## Ranks memory records for dialogue context (R7.3). Never called by decision code.


## One record with its retrieval score.
class Scored extends RefCounted:
	var record: NpcfMemoryRecord
	var score: float = 0.0


	func _init(p_record: NpcfMemoryRecord, p_score: float) -> void:
		record = p_record
		score = p_score


## The top `k` records by score, highest first, ties by ascending record ID.
## score = w_recency * 0.5^(age / half_life) + w_salience * salience / 100 + w_subject * overlap,
## age = now - record.tick (>= 0), overlap = (number of `subjects` present in record.subjects) / subjects.size()
## (0 when `subjects` is empty).
static func top(log: NpcfMemoryLog, subjects: Array[StringName], now: int, k: int, sim: NpcfSimConfig) -> Array[NpcfMemoryRecord]:
	var out: Array[NpcfMemoryRecord] = []
	if k <= 0 or log.records.is_empty():
		return out
	var half_life: float = float(maxi(1, sim.retrieval_half_life_ticks))
	var scored: Array[Scored] = []
	for r: NpcfMemoryRecord in log.records:
		var age: int = maxi(0, now - r.tick)
		var recency: float = pow(0.5, float(age) / half_life)
		var salience: float = float(r.salience) / 100.0
		var overlap: float = 0.0
		if not subjects.is_empty():
			var hits: int = 0
			for s: StringName in subjects:
				if r.subjects.has(s):
					hits += 1
			overlap = float(hits) / float(subjects.size())
		var score: float = sim.retrieval_w_recency * recency + sim.retrieval_w_salience * salience + sim.retrieval_w_subject * overlap
		scored.append(Scored.new(r, score))
	scored.sort_custom(_better)
	for i: int in mini(k, scored.size()):
		out.append(scored[i].record)
	return out


static func _better(a: Scored, b: Scored) -> bool:
	if a.score != b.score:
		return a.score > b.score
	return a.record.id < b.record.id
