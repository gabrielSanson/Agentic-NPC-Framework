class_name NpcfDialogueRequest
extends RefCounted
## One LLM request (R13.5). Holds no key and no endpoint (those belong to the transport).

var npc: StringName = &""
var messages: Array[NpcfChatMessage] = []
## Handle -> the fact it names. The reply may cite only these handles.
var handles: Dictionary[StringName, NpcfFactRef] = {}
var legal_actions: Array[StringName] = []
var variant: StringName = &""
var memory_ids: Array[int] = []
## "handle=subject/fact" for each fact in the prompt, for the turn record.
var injected_facts: Array[String] = []
var temperature: float = 0.7
var max_tokens: int = 200
var structured_output: bool = true
## JSON schema of the expected reply (see NpcfLineValidator.schema_for).
var schema: Dictionary = {}
