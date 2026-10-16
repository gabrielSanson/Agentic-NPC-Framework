@tool
class_name NpcfConsiderationDef
extends Resource
## One input to a utility score, shaped by a response curve (design "3. Utility scoring").

enum InputKind { NEED, FACT, BELIEF_CONFIDENCE, RELATIONSHIP, TIME_OF_DAY, SCHEDULE, TRAVEL_TIME, HOOK }
enum CurveKind { LINEAR, POWER, LOGISTIC, STEP }

@export var id: StringName = &""
@export var input: InputKind = InputKind.NEED
@export var need: NpcfNeedDef = null
@export var fact: NpcfFactDef = null
@export var subject_from: NpcfConditionDef.SubjectFrom = NpcfConditionDef.SubjectFrom.SELF
## Relationship dimension ID (RELATIONSHIP input, task 17).
@export var dim: StringName = &""
## Location tag for TRAVEL_TIME.
@export var location_tag: StringName = &""
## Script extending NpcfConsiderationHook, for HOOK input.
@export var hook: Script = null
@export var hook_params: Dictionary[StringName, Variant] = {}
## Numeric FACT and TRAVEL_TIME inputs are normalized from in_min..in_max to 0..1.
@export var in_min: float = 0.0
@export var in_max: float = 1.0
@export var curve: CurveKind = CurveKind.LINEAR
## Maps x to 1 - x before the curve.
@export var invert: bool = false
## LINEAR: y = m * x + b
@export var m: float = 1.0
@export var b: float = 0.0
## POWER: y = x ^ exponent
@export var exponent: float = 1.0
## LOGISTIC: y = 1 / (1 + e^(-k (x - mid)))
@export var k: float = 10.0
@export var mid: float = 0.5
## STEP: y = 1 if x >= threshold else 0
@export var threshold: float = 0.5
