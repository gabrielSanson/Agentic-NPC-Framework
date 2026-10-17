@tool
class_name NpcfMacroCondition
extends Resource
## A test of one macro variable against a number, used by Director rules.

@export var macro: NpcfMacroVarDef = null
## EQ, NE, LT, LE, GT, GE (EXISTS is rejected by the loader).
@export var compare: NpcfConditionDef.Compare = NpcfConditionDef.Compare.GE
@export var value: float = 0.0
