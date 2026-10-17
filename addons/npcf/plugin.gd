@tool
extends EditorPlugin
## Editor integration: a Project > Tools menu item that checks the pack named in the project
## setting npcf/editor/check_manifest by running the command line checker in a subprocess.

const MENU_TEXT: String = "NPCF: Check pack"
const SETTING: String = "npcf/editor/check_manifest"
const CLI: String = "res://addons/npcf/tools/npcf_cli.gd"
const AUTOLOAD_NAME: String = "Npcf"
const AUTOLOAD_PATH: String = "res://addons/npcf/runtime/npcf_runtime.gd"


func _enter_tree() -> void:
	add_tool_menu_item(MENU_TEXT, _check_pack)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_TEXT)


## The runtime is the game's entry point: registered as the autoload Npcf when the plugin is enabled.
func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


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
