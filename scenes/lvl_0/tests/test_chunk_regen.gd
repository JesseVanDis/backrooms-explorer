## [AI-DOC] Headless test script to verify chunk [0, 0] regeneration after removal
## spec: docs/ai/systems/map_generation.md
## status: partial

extends SceneTree

var _lvl: Lvl_0 = null
var _player: Player = null
var _state: int = 0
var _frame_count_since_state_change: int = 0

var _start_time: float = 0.0

# Verifies that chunk [0, 0] unloads when the player moves far away and successfully regenerates when returning
func _initialize() -> void:
	print("Starting chunk regeneration test...")
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

	_state = 1
	_start_time = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	_frame_count_since_state_change += 1
	var old_state := _state
	# var elapsed_state_ms: float = Time.get_ticks_msec() - _start_time
	if _state == 1:
		if _lvl.chunks.has(Vector2i(0, 0)):
			print("Initial chunk [0, 0] loaded successfully")
			_player = _lvl._player
			if _player == null:
				push_error("Player is null")
			else:
				_player.set_cheat_disable_gravity(true)
				_player.set_cheat_fast_mode(true)
				print("Initial scene loaded. Waiting for player to hit ground and stand up again")
				_state = 2
				
	elif _state == 2:
		if _player.active_wieldable == "lvl_0_landing":
			print("Player hit ground and it playing the standing-up animation")
			_state = 3
			
	elif _state == 3:
		if _player.active_wieldable != "lvl_0_landing":
			_player.set_cheat_collisions_disabled(true)
			print("Player stood up again. Test now begins")
			print("Moving player to x == 4000. and waiting for chunk to generate")
			_lvl._player.global_position.x = 4000
			_state = 4
			
	elif _state == 4:
		if _lvl.get_num_chunks_in_progress() > 0:
			print("Chunks loaded. Waiting couple of frame for just some stuff to happen in the next couple of frames")
			_state = 5

	elif _state == 5:
		if _frame_count_since_state_change > 200:
			print("Waiting done")
			_state = 6

	elif _state == 6:
		if _frame_count_since_state_change > 5:
			if !_lvl.chunks.has(Vector2i(0, 0)):
				print("Chunk [0,0] got indeed removed. now teleporting back, and wait for chunks to load again")
				_lvl._player.global_position.x = 0
				_state = 7
				
		if _frame_count_since_state_change > 500:
			push_error("Chunk [0,0] did not get removed")
			quit(1)
				
	elif _state == 7:
		if _lvl.get_num_chunks_in_progress() > 0:
			print("Chunks loaded")
			_state = 8
			
	elif _state == 8:
		if _lvl.chunks.has(Vector2i(0, 0)):
			print("Chunk [0,0] got regenerated again.")
			print("TEST: PASS")
			#_state = 8
			quit(0)
			
	
	if _state != old_state:
		_frame_count_since_state_change = 0
			
	return false
