class_name LevelTransition

var _scene_path: String = ""
var _loading_state: int = 0
var _loading_level: Node = null
var _next_level_path: String = ""
var _next_level: Node = null
var _loading_screen: Node = null
var _fade_in_complete: bool = false
var _tree: SceneTree = null
var _loaded_levels: Dictionary = {}
var _transition_state: int = 0

func _init(tree: SceneTree) -> void:
	if tree == null:
		push_error("SceneTree is null")
	_tree = tree

func preload_level(scene_path: String) -> void:
	if scene_path == "":
		push_error("Scene path is empty")
		return
	
	if _transition_state > 0:
		return

	if _loaded_levels.has(scene_path):
		return

	if _scene_path != "" and _scene_path != scene_path:
		push_error("Another level is already being loaded or preloaded: " + _scene_path)
		return

	_scene_path = scene_path
	if _loading_state == 0:
		_loading_state = 1

func switch_to_level(scene_path: String) -> bool:
	if _transition_state > 0 && _next_level_path == scene_path:
		return false
	
	if scene_path == "":
		push_error("Scene path is empty")
		return false
	
	if _transition_state > 0:
		push_error("Cannot switch to level '" + scene_path + "' Already transitioning to another level")
		return false
	
	_scene_path = scene_path
	_next_level_path = scene_path
	_fade_in_complete = false
	
	if _tree == null:
		push_error("SceneTree is null")
		return false

	_transition_state = 1
	if _loading_screen == null:
		print("Fading in screen")
		_loading_screen = UtilsScreen.fade_in_screen(_tree, "res://scenes/frontroom_0/transition_frontrooms_lvl_0.tscn", func() -> void: _fade_in_complete = true)
	else:
		_fade_in_complete = true

	if _loaded_levels.has(scene_path):
		_next_level = _loaded_levels[scene_path]
		print("Next level set")
		return true
	else:
		push_error("Switch to level failed. level not loaded yet.")
		preload_level(scene_path)
		return false

func update() -> void:
	# print("update. fade in: " + str(_fade_in_complete))
	if _loading_state > 0:
		match _loading_state:
			1:
				var err: Error = ResourceLoader.load_threaded_request(_scene_path)
				if err != OK:
					push_error("Failed to start asynchronous loading of level: " + _scene_path + " Error: " + str(err))
					return
				_loading_state = 2
				
			2:
				var progress: Array[float] = []
				var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_scene_path, progress)
				
				match status:
					ResourceLoader.THREAD_LOAD_LOADED:
						var packed_scene: PackedScene = ResourceLoader.load_threaded_get(_scene_path) as PackedScene
						if packed_scene == null:
							push_error("Loaded resource is not a PackedScene")
							return
						_loading_level = packed_scene.instantiate()
						if _loading_level == null:
							push_error("Failed to instantiate level")
							return
							
						if _loading_level.has_method("initialize_async"):
							print("Initializing level asynchronously...")
							_loading_level.call("initialize_async")
							_loading_state = 3
						else:
							_loading_state = 4

					ResourceLoader.THREAD_LOAD_FAILED:
						push_error("Failed to load level asynchronously: " + _scene_path)
						_loading_state = 1
					ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
						push_error("Invalid resource path: " + _scene_path)
						_loading_state = 1
			3:
				var is_initialized: bool = true
				if _loading_level.has_method("initialized"):
					var result: Variant = _loading_level.call("initialized")
					if typeof(result) == TYPE_BOOL:
						is_initialized = result
					
				if is_initialized:
					print("Initializing level... done")
					_loading_state = 4
			4:
				_loaded_levels[_scene_path] = _loading_level
				print("level '" + _scene_path + "' loaded")
				_loading_state = 0

	if _next_level != null and _fade_in_complete and not _transition_state == 2:
		_transition_state = 2
		await _perform_transition()
		_scene_path = ""
		_transition_state = 0

func _perform_transition() -> void:
	print("Switching to level")
	var old_scene: Node = _tree.current_scene
	if old_scene == null:
		push_error("current_scene is null")
		return
		
	old_scene.queue_free()
	await old_scene.tree_exited
	
	if _next_level == null:
		push_error("_next_level is null during transition")
		return

	# Note: _loading_screen is already a child of root, so it stays when current_scene is freed
	_tree.root.add_child(_next_level)
	_tree.current_scene = _next_level
	_loaded_levels.erase(_scene_path)
	_next_level = null
	
	
