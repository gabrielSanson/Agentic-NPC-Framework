class_name NpcfDialogueText
extends RefCounted
## Text helpers shared by the keyword classifier and the line validator.


## Lowercase, every run of characters outside [a-z0-9'] becomes one space, padded with one space on each side.
## Whole words match as " word " inside the result.
static func norm(s: String) -> String:
	var re: RegEx = RegEx.create_from_string("[^a-z0-9']+")
	var collapsed: String = re.sub(s.to_lower(), " ", true).strip_edges()
	return " " + collapsed + " "
