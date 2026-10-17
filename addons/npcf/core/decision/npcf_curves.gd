class_name NpcfCurves
extends RefCounted
## Response curves that shape a consideration input into a 0..1 score (design "3. Utility scoring").


## Clamps x to 0..1, inverts it when the consideration asks, applies the curve and clamps the result.
static func apply(c: NpcfConsiderationDef, x: float) -> float:
	var v: float = clampf(x, 0.0, 1.0)
	if c.invert:
		v = 1.0 - v
	var y: float = 0.0
	match c.curve:
		NpcfConsiderationDef.CurveKind.LINEAR:
			y = c.m * v + c.b
		NpcfConsiderationDef.CurveKind.POWER:
			y = pow(v, c.exponent)
		NpcfConsiderationDef.CurveKind.LOGISTIC:
			y = 1.0 / (1.0 + exp(-c.k * (v - c.mid)))
		NpcfConsiderationDef.CurveKind.STEP:
			y = 1.0 if v >= c.threshold else 0.0
	return clampf(y, 0.0, 1.0)
