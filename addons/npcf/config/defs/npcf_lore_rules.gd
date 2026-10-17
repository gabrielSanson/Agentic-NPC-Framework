@tool
class_name NpcfLoreRules
extends Resource
## What a generated line may not say: banned whole words and the length limit.

## Matched as whole words, case-insensitively.
@export var banned_terms: PackedStringArray = []
@export_range(20, 2000) var max_line_chars: int = 300
