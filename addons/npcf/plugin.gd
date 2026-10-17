@tool
extends EditorPlugin
## Editor integration: a Project > Tools menu item that checks the pack named in the project
## setting npcf/editor/check_manifest by running the command line checker in a subprocess.

const MENU_TEXT: String = "NPCF: Check pack"
const SETTING: String = "npcf/editor/check_manifest"
const CLI: String = "res://addons/npcf/tools/npcf_cli.gd"


func _enter_tree() -> void:
	add_tool_menu_item(MENU_TEXT, _check_pack)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_TEXT)


func _check_pack() -> void:
	var manifest: String = ProjectSettings.get_setting(SETTING, "")
	if manifest == "":
		print("NPCF: set %s in Project Settings to a pack manifest first." % SETTING)
		return
	var output: Array = []
	var args: PackedStringArray = PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", CLI, "--", "check", "--manifest", manifest,
	])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	print("NPCF check of %s (exit %d):" % [manifest, code])
	for line: Variant in output:
		print(str(line))
