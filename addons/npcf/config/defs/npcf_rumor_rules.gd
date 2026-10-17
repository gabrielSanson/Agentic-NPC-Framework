@tool
class_name NpcfRumorRules
extends Resource
## How npcf.share_beliefs spreads beliefs (R11.3, R11.4).

@export var max_per_period: int = 2
@export var period_ticks: int = 60
@export var beliefs_per_share: int = 1
@export_range(-100, 100) var confidence_delta: int = -20
