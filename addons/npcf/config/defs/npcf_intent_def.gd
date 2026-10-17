@tool
class_name NpcfIntentDef
extends Resource
## One thing the player can mean (R13.2). Matched by keywords and patterns, or by a classifier provider.

@export var id: StringName = &""
## One sentence describing the intent; a choice provider shows it as the option's description.
@export var description: String = ""
@export var keywords: PackedStringArray = []
## RegEx patterns matched against the lowercased text. Any match gives confidence 1.0.
@export var patterns: PackedStringArray = []
@export var outcome: NpcfOutcomeDef = null
## Optional script extending NpcfIntentHook. Runs before outcome; outcome is its fallback.
@export var hook: Script = null
