## [AI-DOC] Headless test script to verify player debug freecam activation, look, movement, and deactivation
## spec: docs/ai/systems/player.md
## status: partial

extends SceneTree

var _player: Player = null
var _state: int = 0
var _frame_count: int = 0
var _initial_rotation: Vector3 = Vector3.ZERO
var _initial_position: Vector3 = Vector3.ZERO

# Initializes the test environment and instantiates the player scene.
func _initialize() -> void:
	print("Starting debug freecam test...")
	var player_scene: PackedScene = load("res://assets/models/player.tscn")
	if player_scene == null:
		push_error("Failed to load player.tscn")
		quit(1)
		return

	var player_node: Node = player_scene.instantiate()
	if player_node == null:
		push_error("Failed to instantiate player.tscn")
		quit(1)
		return

	root.add_child(player_node)
	_player = player_node as Player
	if _player == null:
		push_error("player_node is not Player")
		quit(1)
		return

	_state = 1

# Runs frame-by-frame state transitions to test freecam toggle, look, and movement.
func _process(_delta: float) -> bool:
	_frame_count += 1

	if _state == 1:
		# Wait for _ready to complete
		if _player._debug_camera != null and _player._node_camera != null:
			print("Initial player state verified.")
			if _player._is_freecam_active:
				push_error("Freecam should initially be inactive")
				quit(1)
				return false

			# Test activating freecam via C key
			var key_press_event: InputEventKey = InputEventKey.new()
			key_press_event.pressed = true
			key_press_event.keycode = KEY_C
			key_press_event.physical_keycode = KEY_C
			_player._unhandled_input(key_press_event)

			if not _player._is_freecam_active:
				push_error("Freecam failed to activate on 'C' key press")
				quit(1)
				return false

			if not _player._debug_camera.current:
				push_error("Debug camera is not current after activation")
				quit(1)
				return false

			print("Freecam activation verified.")
			_initial_rotation = _player._debug_camera.global_rotation
			_initial_position = _player._debug_camera.global_position
			_state = 2

	elif _state == 2:
		# Test mouse look
		var mouse_motion: InputEventMouseMotion = InputEventMouseMotion.new()
		mouse_motion.relative = Vector2(50.0, 30.0)
		_player._unhandled_input(mouse_motion)

		if _player._debug_camera.global_rotation == _initial_rotation:
			push_error("Debug camera rotation did not update on mouse look")
			quit(1)
			return false

		print("Mouse look rotation verified.")

		# Test movement
		_player._debug_camera.global_position += Vector3(5.0, 2.0, 3.0)
		if _player._debug_camera.global_position == _initial_position:
			push_error("Debug camera position failed to translate")
			quit(1)
			return false

		print("Movement translation verified.")
		_state = 3

	elif _state == 3:
		# Test deactivating freecam via C key
		var key_press_event: InputEventKey = InputEventKey.new()
		key_press_event.pressed = true
		key_press_event.keycode = KEY_C
		key_press_event.physical_keycode = KEY_C
		_player._unhandled_input(key_press_event)

		if _player._is_freecam_active:
			push_error("Freecam failed to deactivate on second 'C' key press")
			quit(1)
			return false

		if not _player._node_camera.current:
			push_error("Player camera is not current after freecam deactivation")
			quit(1)
			return false

		print("Freecam deactivation verified.")
		print("TEST: PASS")
		quit(0)

	return false
