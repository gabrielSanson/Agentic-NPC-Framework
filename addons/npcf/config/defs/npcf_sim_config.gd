@tool
class_name NpcfSimConfig
extends Resource
## Simulation settings for a pack.

## Game minutes per tick.
@export var minutes_per_tick: int = 1
## Real seconds per tick at speed 1.0 in game.
@export var real_seconds_per_tick: float = 1.0
@export var max_ticks_per_frame: int = 2
@export var max_decisions_per_tick: int = 64
## Plans older than this many ticks are rejected as STALE at start.
@export var staleness_limit_ticks: int = 5
## K in the directive bias factor 1 + K * D.
@export var directive_gain: float = 1.0
## Delivered events at or above this salience are remembered (task 17).
@export_range(0, 100) var memory_threshold: int = 30
@export var memory_cap: int = 64
@export var retrieval_w_recency: float = 1.0
@export var retrieval_w_salience: float = 1.0
@export var retrieval_w_subject: float = 1.0
@export var retrieval_half_life_ticks: int = 720
@export var retrieval_k: int = 3
## In-game invariant check interval; headless runs check every tick.
@export var invariant_interval_ticks: int = 60
## Decision records kept per NPC.
@export var decision_records: int = 20
## The player's entity ID.
@export var player_entity: StringName = &""
