## [AI-DOC] Headless integration regression for off-tree Level 0 chunk attachment and frontroom transition
## spec: docs/ai/systems/level_flow.md
## status: complete

extends SceneTree

const FRONTROOM_SCENE_PATH: String = "res://scenes/frontroom_0/frontroom_0.tscn"
const LEVEL_ZERO_SCENE_PATH: String = "res://scenes/lvl_0/lvl_0.tscn"
const MAP_NODE_PATH: NodePath = NodePath("_viewport_container/_viewport/Map")
const INITIAL_CHUNK_INDICES: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(-1, -1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
]
const PRELOAD_TIMEOUT_MSEC: int = 180000


# Checks the invalid-map path first, then exercises the real frontroom preload and Level 0 scene swap.
func _initialize() -> void:
	call_deferred("_run_tests")


# Verifies missing-map reporting, off-tree chunk ownership, cache reuse, and transition into the loaded level.
func _run_tests() -> void:
	if not _test_missing_map_is_reported():
		quit(1)
		return
	if not await _test_frontroom_preload_and_transition():
		quit(1)
		return

	print("TEST: PASS")
	quit(0)


# Confirms initialization rejects a missing Map node without generating or caching detached chunks.
func _test_missing_map_is_reported() -> bool:
	var level_scene: PackedScene = load(LEVEL_ZERO_SCENE_PATH)
	if level_scene == null:
		return _fail("Failed to load lvl_0.tscn for the missing-map case")

	var level_node: Lvl_0 = level_scene.instantiate() as Lvl_0
	if level_node == null:
		return _fail("Failed to instantiate lvl_0.tscn for the missing-map case")

	var map_node: Node = level_node.get_node_or_null(MAP_NODE_PATH)
	if map_node == null:
		level_node.free()
		return _fail("The test Level 0 scene has no Map node to remove")
	var map_parent: Node = map_node.get_parent()
	if map_parent == null:
		level_node.free()
		return _fail("The test Map node has no parent")
	map_parent.remove_child(map_node)
	map_node.free()

	if level_node.initialized():
		level_node.free()
		return _fail("Level 0 reported initialized without its required Map node")
	if not level_node.chunks.is_empty():
		level_node.free()
		return _fail("Level 0 cached chunks even though its Map node was missing")

	level_node.free()
	print("Missing Map is reported and no detached chunks are cached.")
	return true


# Exercises actual frontroom preload, verifies cached chunks and the shared offset table before and after the scene swap.
func _test_frontroom_preload_and_transition() -> bool:
	var frontroom_scene: PackedScene = load(FRONTROOM_SCENE_PATH)
	if frontroom_scene == null:
		return _fail("Failed to load frontroom_0.tscn")

	var frontroom_node: Node = frontroom_scene.instantiate()
	if frontroom_node == null:
		return _fail("Failed to instantiate frontroom_0.tscn")
	root.add_child(frontroom_node)
	current_scene = frontroom_node

	var transition_value: Variant = frontroom_node.get("_level_transition")
	if transition_value == null:
		return _fail("frontroom_0 did not create its LevelTransition")
	if not transition_value is LevelTransition:
		return _fail("frontroom_0 created an invalid LevelTransition")
	var level_transition: LevelTransition = transition_value

	var preload_deadline_msec: int = Time.get_ticks_msec() + PRELOAD_TIMEOUT_MSEC
	while not level_transition._loaded_levels.has(LEVEL_ZERO_SCENE_PATH):
		if Time.get_ticks_msec() >= preload_deadline_msec:
			return _fail("Timed out waiting for frontroom to preload Level 0")
		await process_frame

	var level_zero_value: Variant = level_transition._loaded_levels.get(LEVEL_ZERO_SCENE_PATH)
	if not level_zero_value is Lvl_0:
		return _fail("The preloaded Level 0 instance is invalid")
	var level_zero: Lvl_0 = level_zero_value
	if not level_zero._preload_radius_offsets_table(true):
		return _fail("The preloaded Level 0 radius-offset table is not ready")
	if level_zero.is_inside_tree():
		return _fail("Level 0 entered the tree before the transition")

	var map_node: Node3D = level_zero.get_node_or_null(MAP_NODE_PATH) as Node3D
	if map_node == null:
		return _fail("The preloaded Level 0 has no Node3D Map node")
	if not _assert_initial_chunks_parented(level_zero, map_node):
		return false

	var expected_chunk: Variant = level_zero.chunks.get(Vector2i(0, 0))
	var original_map_child_count: int = map_node.get_child_count()
	var cached_chunk: Variant = level_zero._get_or_create_chunk(Vector2i(0, 0), false)
	if cached_chunk != expected_chunk:
		return _fail("Cached chunk access returned a different chunk instance")
	if map_node.get_child_count() != original_map_child_count:
		return _fail("Cached chunk access duplicated nodes under Map")

	await level_transition._perform_transition(level_zero)
	if current_scene != level_zero or not level_zero.is_inside_tree():
		return _fail("The real level transition did not enter Level 0 into the scene tree")
	if not _assert_initial_chunks_parented(level_zero, map_node):
		return false
	return true


# Checks both chunk nodes for each preloaded starting chunk are direct children of the authored Map node.
func _assert_initial_chunks_parented(level_zero: Lvl_0, map_node: Node3D) -> bool:
	for chunk_index: Vector2i in INITIAL_CHUNK_INDICES:
		if not level_zero.chunks.has(chunk_index):
			return _fail("Preloaded Level 0 is missing chunk " + str(chunk_index))
		var chunk: Variant = level_zero.chunks.get(chunk_index)
		if chunk == null:
			return _fail("Preloaded Level 0 has a null chunk at " + str(chunk_index))
		var static_body_value: Variant = chunk.static_body_3d
		var tiles_value: Variant = chunk.tiles
		if not static_body_value is StaticBody3D or not tiles_value is Node3D:
			return _fail("Preloaded chunk " + str(chunk_index) + " has missing child nodes")
		var static_body: StaticBody3D = static_body_value
		var tiles: Node3D = tiles_value
		if static_body.get_parent() != map_node or tiles.get_parent() != map_node:
			return _fail("Preloaded chunk " + str(chunk_index) + " is not parented under Map")
	return true


# Reports a regression failure through Godot's error channel and lets the test exit with a non-zero status.
func _fail(error_message: String) -> bool:
	push_error(error_message)
	return false