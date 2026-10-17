class_name NpcfChatMessage
extends RefCounted
## One message of an LLM chat request (role is `system`, `user` or `assistant`).

var role: StringName = &"user"
var content: String = ""


static func make(p_role: StringName, p_content: String) -> NpcfChatMessage:
	var m: NpcfChatMessage = NpcfChatMessage.new()
	m.role = p_role
	m.content = p_content
	return m
