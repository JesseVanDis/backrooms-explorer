## [AI-DOC] Integration test verifying tile visibility culling and rotation tracking in lvl_0
## spec: scenes/lvl_0/docs/SPEC.md
## status: complete

extends SceneTree

var _lvl: Lvl_0 = null
var _player: Player = null
var _step: int = 0
var _frames: int = 0

# Initializes headless test environment with Level 0 scene
func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	print("Starting visibility pattern integration test in lvl_0...")
	var lvl_scene: PackedScene = load("res://scenes/lvl_0/lvl_0.tscn")
	if lvl_scene == null:
		push_error("Failed to load lvl_0.tscn")
		quit(1)
		return

	var lvl_node: Node = lvl_scene.instantiate()
	if lvl_node == null:
		push_error("Failed to instantiate lvl_0.tscn")
		quit(1)
		return

	root.add_child(lvl_node)
	_lvl = lvl_node as Lvl_0
	if _lvl == null:
		push_error("lvl_node is not Lvl_0")
		quit(1)
		return

	_step = 1

# Advances test state machine across multiple frames to verify tile culling upon player rotation
func _process(_delta: float) -> bool:
	_frames += 1
	
	if _step == 1:
		if _lvl.chunks.has(Vector2i(0, 0)):
			_player = _lvl._player
			if _player == null:
				push_error("Player is null")
				quit(1)
				return false
			_player.set_cheat_disable_gravity(true)
			_player.set_cheat_fast_mode(true)
			_player.set_cheat_collisions_disabled(true)
			_player.global_position = Vector3(0, 0, 0)
			_player.rotation.y = 0.0 # Facing North (-Z)
			print("Player placed at (0, 0, 0) facing North")
			_step = 2
			_frames = 0
			
	elif _step == 2:
		# Let several frames process so graphics tiles are spawned in North direction
		if _frames > 30:
			var north_tile_visible: bool = _lvl._is_tile_visible(Vector2i(0, -20))
			var south_tile_visible: bool = _lvl._is_tile_visible(Vector2i(0, 20))
			print("Facing North -> North tile (0, -20) visible: ", north_tile_visible, ", South tile (0, 20) visible: ", south_tile_visible)
			if not north_tile_visible or south_tile_visible:
				push_error("Visibility check failed when facing North")
				quit(1)
				return false
			
			var north_placed_count: int = _lvl._graphic_tiles_cache.placed_tiles.size()
			print("Total graphics tiles placed when facing North: ", north_placed_count)
			if north_placed_count == 0:
				push_error("No graphic tiles placed")
				quit(1)
				return false
			
			# Now rotate player 180 degrees to face South (+Z)
			_player.rotation.y = PI
			print("Rotated player 180 degrees to face South")
			_step = 3
			_frames = 0
			
	elif _step == 3:
		# Process frames for removal of old tiles and addition of new tiles
		if _frames > 60:
			var north_tile_visible: bool = _lvl._is_tile_visible(Vector2i(0, -20))
			var south_tile_visible: bool = _lvl._is_tile_visible(Vector2i(0, 20))
			print("Facing South -> North tile (0, -20) visible: ", north_tile_visible, ", South tile (0, 20) visible: ", south_tile_visible)
			if north_tile_visible or not south_tile_visible:
				push_error("Visibility check failed when facing South")
				quit(1)
				return false
			
			# Verify that the tile (0, -20) is no longer in _graphic_tiles_cache
			if _lvl._graphic_tiles_cache.placed_tiles.has(Vector2i(0, -20)):
				push_error("North tile was not culled after turning South!")
				quit(1)
				return false
				
			print("North tile (0, -20) successfully culled from graphic tiles cache!")
			print("TEST: PASS")
			quit(0)
			return true

	return false
