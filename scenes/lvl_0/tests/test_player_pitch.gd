## [AI-DOC] Headless regression test ensuring player pitch initializes within asymmetric camera look limits
## spec: docs/ai/systems/player.md
## status: partial

extends SceneTree

var _player: Player = null
var _camera_local_rotation: Vector3 = Vector3.ZERO

# Starts beyond the new downward limit so ready-time initialization must clamp to 80 degrees.
func _initialize() -> void:
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

	_player = player_node as Player
	if _player == null:
		push_error("player_node is not Player")
		quit(1)
		return
	_player.initial_pitch = 90.0
	_player.ready.connect(_on_player_ready, CONNECT_ONE_SHOT)
	root.add_child(player_node)

# Verifies startup pitch is clamped before a physics tick can synchronize the camera pivot.
func _on_player_ready() -> void:
	_player.set_physics_process(false)
	if _player._node_camera == null:
		push_error("Player camera is null")
		quit(1)
		return
	if _player._node_camera_pitch_pivot == null:
		push_error("Player camera pitch pivot is null")
		quit(1)
		return
	_camera_local_rotation = _player._node_camera.rotation
	if not _expect_pitch_at(80.0, "initializing at the downward limit"):
		return

	_run_pitch_tests()

# Verifies the asymmetric default pitch bounds, pivot-driven orbit, and narrower behaviour limits.
func _run_pitch_tests() -> void:
	if _player._node_camera_pitch_pivot == null:
		push_error("Player camera pitch pivot is null")
		quit(1)
		return
	if _player._node_camera == null:
		push_error("Player camera is null")
		quit(1)
		return
	var pivot_parent: Node3D = _player._node_camera_pitch_pivot.get_parent() as Node3D
	if pivot_parent == null:
		push_error("Player camera pitch pivot parent is null")
		quit(1)
		return

	var camera_position_before_mouse_look: Vector3 = pivot_parent.to_local(_player._node_camera.global_position)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_send_mouse_motion(-100.0)
	if not _expect_pitch_within(90.0, "looking up from the initial pitch"):
		return
	if not _expect_camera_orbit(pivot_parent, camera_position_before_mouse_look, "looking up from the initial pitch"):
		return

	_send_mouse_motion(-20000.0)
	if not _expect_pitch_at(-90.0, "looking above the default upward limit"):
		return
	_send_mouse_motion(-20000.0)
	if not _expect_pitch_at(-90.0, "repeatedly looking above the default upward limit"):
		return
	_send_mouse_motion(20000.0)
	if not _expect_pitch_at(80.0, "looking below the default downward limit"):
		return
	_send_mouse_motion(20000.0)
	if not _expect_pitch_at(80.0, "repeatedly looking below the default downward limit"):
		return
	_send_mouse_motion(-20000.0)
	if not _expect_pitch_at(-90.0, "reversing from the lower default limit"):
		return

	_player.add_behaviour("pitch_test", "", {"player_max_look_freedom_degrees_v": 40.0})
	_player._behaviour.update(0.0)
	_send_mouse_motion(-100000.0)
	if not _expect_pitch_at(-20.0, "looking above the restricted limit"):
		return
	_send_mouse_motion(100000.0)
	if not _expect_pitch_at(20.0, "looking below the restricted limit"):
		return

	_player._spine_pitch = deg_to_rad(20.0)
	_player._node_camera_pitch_pivot.rotation.x = -_player._spine_pitch
	_player._behaviour.active_settings.additional_settings["player_max_look_freedom_degrees_v"] = 10.0
	_player._handle_camera_limits(0.0)
	if not _expect_pitch_within(5.0, "updating the limit during a camera-limit pass"):
		return
	_player._spine_pitch = deg_to_rad(-20.0)
	_player._node_camera_pitch_pivot.rotation.x = -_player._spine_pitch
	_player._handle_camera_limits(0.0)
	if not _expect_pitch_at(-5.0, "applying the narrower upward behaviour limit"):
		return

	print("TEST: PASS")
	quit(0)

# Sends vertical mouse input through the player's captured-mouse handler.
func _send_mouse_motion(vertical_motion: float) -> void:
	var mouse_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(0.0, vertical_motion)
	_player._unhandled_input(mouse_motion)

# Ensures pitch clamping updates the pivot without changing the camera's local rotation.
func _expect_pitch_within(limit_degrees: float, description: String) -> bool:
	var camera_pitch_degrees: float = rad_to_deg(-_player._node_camera_pitch_pivot.rotation.x)
	if absf(camera_pitch_degrees) > limit_degrees + 0.001:
		push_error("Camera pitch exceeded " + str(limit_degrees) + " degrees while " + description + ": " + str(camera_pitch_degrees))
		quit(1)
		return false
	if not is_equal_approx(_player._node_camera_pitch_pivot.rotation.x, -_player._spine_pitch):
		push_error("Camera pivot and spine pitch diverged while " + description)
		quit(1)
		return false
	if not _player._node_camera.rotation.is_equal_approx(_camera_local_rotation):
		push_error("Camera local rotation changed while " + description)
		quit(1)
		return false
	return true

# Confirms pitch reaches the requested asymmetric clamp boundary while preserving the camera relationship.
func _expect_pitch_at(expected_degrees: float, description: String) -> bool:
	if not _expect_pitch_within(absf(expected_degrees), description):
		return false
	var actual_pitch_degrees: float = rad_to_deg(-_player._node_camera_pitch_pivot.rotation.x)
	if not is_equal_approx(actual_pitch_degrees, expected_degrees):
		push_error("Camera pitch did not reach " + str(expected_degrees) + " degrees while " + description + ": " + str(actual_pitch_degrees))
		quit(1)
		return false
	return true

# Confirms vertical look moves the camera through its pivot relative to the animated attachment.
func _expect_camera_orbit(pivot_parent: Node3D, previous_camera_position: Vector3, description: String) -> bool:
	var current_camera_position: Vector3 = pivot_parent.to_local(_player._node_camera.global_position)
	if current_camera_position.distance_to(previous_camera_position) <= 0.001:
		push_error("Camera did not orbit its pitch pivot while " + description)
		quit(1)
		return false
	return true