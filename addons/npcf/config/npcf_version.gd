class_name NpcfVersion
extends RefCounted
## The framework version and semantic-version comparison used for pack compatibility (R2.2).

const FRAMEWORK: String = "0.2.0"


## Parses "major.minor.patch" into three ints, or an empty array if malformed.
static func parse(v: String) -> PackedInt32Array:
	var parts: PackedStringArray = v.strip_edges().split(".")
	if parts.size() != 3:
		return PackedInt32Array()
	var out: PackedInt32Array = []
	for p: String in parts:
		if not p.is_valid_int() or p.to_int() < 0:
			return PackedInt32Array()
		out.append(p.to_int())
	return out


## -1, 0 or 1 as a < b, a == b, a > b. Both must be valid.
static func compare(a: String, b: String) -> int:
	var pa: PackedInt32Array = parse(a)
	var pb: PackedInt32Array = parse(b)
	for i: int in 3:
		if pa[i] != pb[i]:
			return -1 if pa[i] < pb[i] else 1
	return 0
