@tool
class_name NpcfLlmConfig
extends Resource
## Generation settings for LLM lines. Endpoints, models, keys and timeouts belong to providers (batch C3).

@export_range(0.0, 2.0) var temperature: float = 0.7
@export_range(16, 4096) var max_tokens: int = 200
@export var structured_output: bool = true
