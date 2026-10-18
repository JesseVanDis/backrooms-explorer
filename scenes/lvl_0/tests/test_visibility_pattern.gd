## [AI-DOC] Integration test verifying tile visibility toggling and rotation tracking without removing tile nodes in lvl_0
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

# Advances test state machine across multiple frames to verify tile visibility toggling upon player rotation
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

			# Verify prioritization: when handling limited tiles in radius, visible tiles must be prioritized first
			var test_cache: Lvl_0.HandleTilesCache = Lvl_0.HandleTilesCache.new()
			var test_added_tiles: Array[Vector2i] = []
			var dummy_create: Callable = func(placed_tile: Lvl_0.PlacedTile, _chunk: Lvl_0.Chunk) -> void:
				test_added_tiles.append(placed_tile.tile_index)
			var dummy_remove: Callable = func(_placed_tile: Lvl_0.PlacedTile) -> void:
				pass
			_lvl._handle_tiles_in_radius(30, test_cache, dummy_create, dummy_remove, 10)
			if test_added_tiles.size() != 10:
				push_error("Expected 10 tiles to be added, got: " + str(test_added_tiles.size()))
				quit(1)
				return false
			for added_tile: Vector2i in test_added_tiles:
				if not _lvl._is_tile_visible(added_tile):
					push_error("Tile prioritized was not visible: " + str(added_tile))
					quit(1)
					return false
			print("Verified tile addition prioritization: all 10 initial tiles added are visible.")

			_step = 2
			_frames = 0
			
	elif _step == 2:
		var north_tile_index: Vector2i = Vector2i(0, -20)
		var south_tile_index: Vector2i = Vector2i(0, 20)
		
		if not _lvl._graphic_tiles_cache.placed_tiles.has(north_tile_index) or not _lvl._graphic_tiles_cache.placed_tiles.has(south_tile_index):
			return false

		if _frames < 5:
			return false
			
		var north_tile_visible: bool = _lvl._is_tile_visible(north_tile_index)
		var south_tile_visible: bool = _lvl._is_tile_visible(south_tile_index)
		print("Facing North -> North tile (0, -20) visible: ", north_tile_visible, ", South tile (0, 20) visible: ", south_tile_visible)
		if not north_tile_visible or south_tile_visible:
			push_error("Visibility calculation check failed when facing North")
			quit(1)
			return false
		
		var north_tile: Lvl_0.PlacedTile = _lvl.placed_tiles.get(north_tile_index)
		if north_tile == null:
			push_error("North tile PlacedTile not found")
			quit(1)
			return false
		
		var south_tile: Lvl_0.PlacedTile = _lvl.placed_tiles.get(south_tile_index)
		if south_tile == null:
			push_error("South tile PlacedTile not found")
			quit(1)
			return false
		
		if north_tile.graphics.is_empty() or south_tile.graphics.is_empty():
			push_error("Tile graphics empty for test tiles")
			quit(1)
			return false
		
		for graphic: Variant in north_tile.graphics.values():
			if graphic is Node3D:
				var graphic_node: Node3D = graphic
				if not graphic_node.visible:
					push_error("North tile graphic expected to be visible when facing North")
					quit(1)
					return false
		
		for graphic: Variant in south_tile.graphics.values():
			if graphic is Node3D:
				var graphic_node: Node3D = graphic
				if graphic_node.visible:
					push_error("South tile graphic expected to be hidden when facing North")
					quit(1)
					return false
		
		print("Facing North tile visibility verified.")
		
		# Rotate player 180 degrees to face South (+Z)
		_player.rotation.y = PI
		print("Rotated player 180 degrees to face South")
		_step = 3
		_frames = 0
		
	elif _step == 3:
		# Process frames for visibility toggling without destroying nodes
		if _frames > 5:
			var north_tile_index: Vector2i = Vector2i(0, -20)
			var south_tile_index: Vector2i = Vector2i(0, 20)
			var north_tile_visible: bool = _lvl._is_tile_visible(north_tile_index)
			var south_tile_visible: bool = _lvl._is_tile_visible(south_tile_index)
			print("Facing South -> North tile (0, -20) visible: ", north_tile_visible, ", South tile (0, 20) visible: ", south_tile_visible)
			if north_tile_visible or not south_tile_visible:
				push_error("Visibility check failed when facing South")
				quit(1)
				return false
			
			# Verify that the tile remains in _graphic_tiles_cache (not removed/destroyed)
			if not _lvl._graphic_tiles_cache.placed_tiles.has(north_tile_index):
				push_error("North tile was unexpectedly removed from graphic tiles cache instead of hidden!")
				quit(1)
				return false
			
			var north_tile: Lvl_0.PlacedTile = _lvl.placed_tiles.get(north_tile_index)
			if north_tile == null:
				push_error("North tile PlacedTile missing")
				quit(1)
				return false
			
			var south_tile: Lvl_0.PlacedTile = _lvl.placed_tiles.get(south_tile_index)
			if south_tile == null:
				push_error("South tile PlacedTile missing")
				quit(1)
				return false
			
			for graphic: Variant in north_tile.graphics.values():
				if graphic is Node3D:
					var graphic_node: Node3D = graphic
					if graphic_node.visible:
						push_error("North tile graphic was not hidden after turning South!")
						quit(1)
						return false
			
			for graphic: Variant in south_tile.graphics.values():
				if graphic is Node3D:
					var graphic_node: Node3D = graphic
					if not graphic_node.visible:
						push_error("South tile graphic was not made visible after turning South!")
						quit(1)
						return false
				
			print("North tile (0, -20) is hidden and South tile (0, 20) is visible without re-allocating nodes!")
			print("TEST: PASS")
			quit(0)
			return true

	return false
