## [AI-DOC] Headless integration test verifying the menu UI FPS label displays the current engine rate
## spec: docs/ai/systems/ui_subtitles.md
## status: complete

extends SceneTree

const MENU_UI_SCENE_PATH: String = "res://scenes/menu_ui/menu_ui.tscn"
const FPS_SCRIPT_PATH: String = "res://scenes/menu_ui/fps_label.gd"


# Loads the real menu UI so the test verifies the FPS script is attached to the authored label.
func _initialize() -> void:
	var menu_ui_scene: PackedScene = load(MENU_UI_SCENE_PATH)
	if menu_ui_scene == null:
		push_error("Failed to load menu_ui.tscn")
		quit(1)
		return

	var viewport: SubViewport = SubViewport.new()
	root.add_child(viewport)
	var menu_ui: Node = menu_ui_scene.instantiate()
	if menu_ui == null:
		push_error("Failed to instantiate menu_ui.tscn")
		quit(1)
		return
	viewport.add_child(menu_ui)

	var fps_label: Label = menu_ui.get_node_or_null("_fps") as Label
	if fps_label == null:
		push_error("FPS Label not found in menu_ui.tscn")
		quit(1)
		return
	var expected_script: Resource = load(FPS_SCRIPT_PATH)
	if expected_script == null:
		push_error("Failed to load fps_label.gd")
		quit(1)
		return
	if fps_label.get_script() != expected_script:
		push_error("FPS Label is not attached to fps_label.gd")
		quit(1)
		return

	_run_label_updates(fps_label)


# Ensures repeated updates render the engine's current FPS instead of leaving the authored placeholder.
func _run_label_updates(fps_label: Label) -> void:
	for _update_index: int in range(2):
		fps_label.call("_process", 0.0)
		var expected_text: String = "FPS: " + str(Engine.get_frames_per_second())
		if fps_label.text != expected_text:
			push_error("FPS Label text did not match the current engine FPS: " + fps_label.text)
			quit(1)
			return

	print("TEST: PASS")
	quit(0)