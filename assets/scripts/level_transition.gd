class_name LevelTransition

var _scene_path: String = ""
var _loading_state: int = 0
var _next_level: Node = null
var _loading_screen: Node = null
var _fade_in_complete: bool = false
var _tree: SceneTree = null

func _init(tree: SceneTree) -> void:
	if tree == null:
		push_error("SceneTree is null")
	_tree = tree

func switch_to_level(scene_path: String) -> void:
	if scene_path == "":
		push_error("Scene path is empty")
		return
	
	_scene_path = scene_path
	_loading_state = 1
	_fade_in_complete = false
	
	if _tree == null:
		push_error("SceneTree is null")
		return

	if _loading_screen == null:
		# Using the hardcoded path from frontroom_0.gd for now as requested
		_loading_screen = UtilsScreen.fade_in_screen(_tree, "res://scenes/frontroom_0/transition_frontrooms_lvl_0.tscn", func() -> void: _fade_in_complete = true)

func update() -> void:
	if _loading_state == 0:
		return
		
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
					_next_level = packed_scene.instantiate()
					if _next_level == null:
						push_error("Failed to instantiate level")
						return
						
					if _next_level.has_method("initialize_async"):
						print("Initializing level asynchronously...")
						_next_level.call("initialize_async")
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
			if _next_level.has_method("initialized"):
				var result: Variant = _next_level.call("initialized")
				if typeof(result) == TYPE_BOOL:
					is_initialized = result
				
			if is_initialized:
				print("Initializing level... done")
				_loading_state = 4
		4:
			if _fade_in_complete:
				_perform_transition()
				_loading_state = 0

func _perform_transition() -> void:
	if _tree == null:
		push_error("SceneTree is null")
		return
		
	print("Switching to new level")
	var old_scene: Node = _tree.current_scene
	if old_scene == null:
		push_error("current_scene is null")
		# Even if null, we try to proceed to add the new level
	else:
		old_scene.queue_free()
		# We don't necessarily need to await here if we are just switching root scene,
		# but frontroom_0 did it.
	
	# If old_scene was null, we don't need to await.
	if old_scene != null:
		# This might be tricky in a non-Node class, but we have _tree.
		# We can't use await here easily without being async.
		# But we can just add the child and set current_scene.
		_tree.root.add_child(_next_level)
		_tree.current_scene = _next_level
	else:
		_tree.root.add_child(_next_level)
		_tree.current_scene = _next_level
