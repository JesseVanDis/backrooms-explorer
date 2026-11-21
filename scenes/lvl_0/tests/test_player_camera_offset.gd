## [AI-DOC] Headless integration regression for status-gated camera offsets, stationary pitch pivot, and independent bob
## spec: docs/ai/systems/player.md
## status: partial

extends SceneTree

var _player: Player = null
var _camera_pitch_pivot_default_position: Vector3 = Vector3.ZERO
var _camera_default_position: Vector3 = Vector3.ZERO

# Loads the real player scene so camera offset tests use the gameplay AnimationTree and hierarchy.
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

	root.add_child(player_node)
	_player = player_node as Player
	if _player == null:
		push_error("player_node is not Player")
		quit(1)
		return

	_player.set_physics_process(false)
	call_deferred("_run_camera_offset_tests")

# Verifies XYZ offsets, status-gated blend-out, same-frame run release, and root-relative camera movement.
func _run_camera_offset_tests() -> void:
	var animation_tree: AnimationTree = UtilsNode.find_animation_tree_recursive(_player)
	if animation_tree == null:
		push_error("Player AnimationTree is null")
		quit(1)
		return
	if _player._node_camera_pitch_pivot == null:
		push_error("Player camera pitch pivot is null")
		quit(1)
		return
	var pivot_parent: Node3D = _player._node_camera_pitch_pivot.get_parent() as Node3D
	if pivot_parent == null:
		push_error("Player camera pitch pivot parent is null")
		quit(1)
		return
	if _player._node_camera == null:
		push_error("Player camera is null")
		quit(1)
		return

	animation_tree.active = false
	_player.control_enabled = false
	_player.rotation.y = 0.7
	pivot_parent.rotation = Vector3(0.3, -0.4, 0.2)
	_player._spine_pitch = deg_to_rad(20.0)
	_player._node_camera_pitch_pivot.rotation.x = -_player._spine_pitch
	_camera_pitch_pivot_default_position = _player._node_camera_pitch_pivot.position
	_camera_default_position = _player._node_camera.position
	var original_pivot_rotation: Vector3 = _player._node_camera_pitch_pivot.rotation
	var original_camera_rotation: Vector3 = _player._node_camera.rotation
	var run_additional_settings: Dictionary = _player._behaviour._behaviours["run"].additional_settings
	var expected_run_offset: Vector3 = run_additional_settings.get("player_camera_offset", Vector3.ZERO)
	var expected_run_speed: float = run_additional_settings.get("player_camera_offset_speed", 1.0)
	_player.activate_behaviour("run")
	if not _expect_camera_offset_setting(expected_run_offset, _player._behaviour.active_settings.player_camera_offset, "registered run offset"):
		return
	if not is_equal_approx(expected_run_speed, _player._behaviour.active_settings.player_camera_offset_speed):
		push_error("Registered run camera offset speed did not match its settings")
		quit(1)
		return
	_player.deactivate_behaviour("run")
	_player._behaviour.update(1.0)
	run_additional_settings.erase("player_camera_offset")
	run_additional_settings.erase("player_camera_offset_speed")
	_player._behaviour._behaviours["run"].animation_tree_parameter = ""
	_player._behaviour._behaviours["push"].animation_tree_parameter = ""

	_player.add_behaviour("test_camera_offset_default", "parameters/lvl_0_landing/request", {
		"anim_activation_speed": 100.0,
		"anim_deactivation_speed": 100.0,
		"player_camera_offset": Vector3(1.0, -1.0, 2.0)
	})
	_player.activate_behaviour("test_camera_offset_default")
	if not _expect_behaviour_status(PlayerBehaviour.BehaviourStatus.ENABLING, "test_camera_offset_default", "one-shot offset activation"):
		return
	if not _advance_and_expect_offset(0.25, Vector3(0.25, -0.25, 0.25), "default one-unit-per-second shared offset speed"):
		return
	if not _advance_and_expect_offset(10.0, Vector3(1.0, -1.0, 2.0), "XYZ default-speed target without overshoot"):
		return
	_player.deactivate_behaviour("test_camera_offset_default")
	if not _expect_behaviour_status(PlayerBehaviour.BehaviourStatus.IDLE, "test_camera_offset_default", "cancelled offset behaviour status"):
		return
	if not _advance_and_expect_offset(10.0, Vector3.ZERO, "default-speed return"):
		return

	_player.add_behaviour("test_camera_offset_base", "parameters/run/blend_amount", {
		"anim_activation_speed": 100.0,
		"anim_deactivation_speed": 4.0,
		"player_camera_offset": Vector3(2.0, -1.0, -3.0),
		"player_camera_offset_speed": 2.0
	})
	_player.add_behaviour("test_camera_offset_override", "parameters/push/blend_amount", {
		"anim_activation_speed": 100.0,
		"anim_deactivation_speed": 1.0,
		"player_camera_offset": Vector3(-2.0, 4.0, 1.0),
		"player_camera_offset_speed": 1.0,
		"player_movement_multiplier": 0.5
	})
	_player.activate_behaviour("test_camera_offset_base")
	if not _expect_behaviour_status(PlayerBehaviour.BehaviourStatus.ENABLING, "test_camera_offset_base", "base offset activation"):
		return
	if not _advance_and_expect_offset(0.25, Vector3(0.5, -0.5, -0.5), "shared custom speed with rotated root and attachment"):
		return
	if not _advance_and_expect_offset(10.0, Vector3(2.0, -1.0, -3.0), "XYZ target without overshoot"):
		return
	if not _expect_camera_offset(Vector3(2.0, -1.0, -3.0), "while applying camera offsets"):
		return
	var simulated_head_bob_offset: Vector3 = Vector3(0.05, -0.1, 0.0)
	_player._camera_bob_offset = simulated_head_bob_offset
	_player._handle_head_bob(0.0)
	if not _expect_camera_offset(Vector3(2.0, -1.0, -3.0), "while head bob is present"):
		return
	_player._camera_bob_offset = Vector3.ZERO
	_player._apply_camera_position()
	_player._spine_pitch = deg_to_rad(-25.0)
	_player._handle_camera_limits(0.0)
	original_pivot_rotation = _player._node_camera_pitch_pivot.rotation
	if not _expect_camera_offset(Vector3(2.0, -1.0, -3.0), "after changing pitch with an active camera offset"):
		return
	if not _expect_camera_rotations(original_pivot_rotation, original_camera_rotation, "while applying camera offsets"):
		return

	_player.activate_behaviour("test_camera_offset_override")
	if not _advance_and_expect_offset(0.25, Vector3(1.75, -0.75, -2.75), "later behaviour overrides the complete vector"):
		return
	if not _expect_behaviour_status(PlayerBehaviour.BehaviourStatus.ACTIVE, "test_camera_offset_override", "override reaches active"):
		return
	_player.deactivate_behaviour("test_camera_offset_override")
	if not _expect_behaviour_status(PlayerBehaviour.BehaviourStatus.DISABLING, "test_camera_offset_override", "override blend-out status"):
		return
	if not _advance_and_expect_offset(0.25, Vector3(2.0, -1.0, -3.0), "camera offset returns to the remaining active behaviour during blend-out"):
		return
	if not is_equal_approx(0.5, _player._behaviour.active_settings.player_movement_multiplier):
		push_error("Movement restriction did not remain active during override blend-out")
		quit(1)
		return
	if not _advance_and_expect_offset(0.75, Vector3(2.0, -1.0, -3.0), "base behaviour resumes after override fade-out"):
		return
	if not _expect_behaviour_status(PlayerBehaviour.BehaviourStatus.IDLE, "test_camera_offset_override", "completed override blend-out"):
		return

	_player.deactivate_behaviour("test_camera_offset_base")
	if not _advance_and_expect_offset(0.25, Vector3(1.5, -0.5, -2.5), "shared speed remains active for the return after settings release"):
		return
	if not _advance_and_expect_offset(10.0, Vector3.ZERO, "shared-speed return reaches the base pivot without overshoot"):
		return
	if not _expect_camera_rotations(original_pivot_rotation, original_camera_rotation, "after offset return"):
		return

	_player.add_behaviour("test_camera_offset_negative_speed", "parameters/lvl_0_landing/request", {
		"anim_activation_speed": 100.0,
		"player_camera_offset": Vector3(1.0, 2.0, 3.0),
		"player_camera_offset_speed": -1.0
	})
	_player.activate_behaviour("test_camera_offset_negative_speed")
	if not _advance_and_expect_offset(1.0, Vector3.ZERO, "negative shared speed does not move any axis"):
		return
	_player.deactivate_behaviour("test_camera_offset_negative_speed")
	_player._behaviour.update(1.0)

	var base_offset_behaviour: PlayerBehaviour.Behaviour = _player._behaviour._behaviours["test_camera_offset_base"]
	base_offset_behaviour.animation_tree_parameter = ""
	base_offset_behaviour.additional_settings.clear()
	var override_offset_behaviour: PlayerBehaviour.Behaviour = _player._behaviour._behaviours["test_camera_offset_override"]
	override_offset_behaviour.animation_tree_parameter = ""
	override_offset_behaviour.additional_settings.clear()
	_player._behaviour.refresh_active_settings()
	run_additional_settings["player_camera_offset"] = expected_run_offset
	run_additional_settings["player_camera_offset_speed"] = expected_run_speed
	_player._behaviour._behaviours["run"].animation_tree_parameter = "parameters/run/blend_amount"
	_player.control_enabled = true
	Input.action_press("forward")
	_player._physics_process(0.1)
	var run_offset_step: float = maxf(0.0, expected_run_speed) * 0.1
	var expected_run_entry_offset: Vector3 = Vector3(
		move_toward(0.0, expected_run_offset.x, run_offset_step),
		move_toward(0.0, expected_run_offset.y, run_offset_step),
		move_toward(0.0, expected_run_offset.z, run_offset_step)
	)
	if not _expect_behaviour_status(PlayerBehaviour.BehaviourStatus.ENABLING, "run", "run input activation status"):
		Input.action_release("forward")
		return
	if not _expect_camera_offset(expected_run_entry_offset, "run input activates camera framing"):
		Input.action_release("forward")
		return
	Input.action_release("forward")
	_player._physics_process(0.1)
	var expected_run_exit_offset: Vector3 = Vector3(
		move_toward(expected_run_entry_offset.x, 0.0, run_offset_step),
		move_toward(expected_run_entry_offset.y, 0.0, run_offset_step),
		move_toward(expected_run_entry_offset.z, 0.0, run_offset_step)
	)
	if not _expect_behaviour_status(PlayerBehaviour.BehaviourStatus.DISABLING, "run", "run input release status"):
		return
	if not _expect_camera_offset(expected_run_exit_offset, "releasing run input starts camera retraction in the same physics frame"):
		return
	if animation_tree["parameters/run/blend_amount"] <= 0.0:
		push_error("Run blend reached zero before camera offset retraction was checked")
		quit(1)
		return

	print("TEST: PASS")
	quit(0)

# Advances the real disabled-controls physics path before checking camera-only behavior offsets.
func _advance_and_expect_offset(delta: float, expected_offset: Vector3, description: String) -> bool:
	_player._physics_process(delta)
	return _expect_camera_offset(expected_offset, description)

# Checks the public player status query against an expected behaviour lifecycle state.
func _expect_behaviour_status(expected_status: PlayerBehaviour.BehaviourStatus, unique_name: String, description: String) -> bool:
	var actual_status: PlayerBehaviour.BehaviourStatus = _player.get_behaviour_status(unique_name)
	if actual_status != expected_status:
		push_error(description + " expected " + str(expected_status) + ", got " + str(actual_status))
		quit(1)
		return false
	return true

# Checks that behavior displacement reaches the camera in player-root axes without translating the pitch pivot.
func _expect_camera_offset(expected_offset: Vector3, description: String) -> bool:
	if not _player._node_camera_pitch_pivot.position.is_equal_approx(_camera_pitch_pivot_default_position):
		push_error(description + " unexpectedly moved the camera pitch pivot")
		quit(1)
		return false
	var camera_parent: Node3D = _player._node_camera.get_parent() as Node3D
	if camera_parent == null:
		push_error("Player camera parent is null")
		quit(1)
		return false
	var camera_local_offset: Vector3 = _player._node_camera.position - _camera_default_position
	var behavior_camera_local_offset: Vector3 = camera_local_offset - _player._camera_bob_offset
	var player_relative_offset: Vector3 = _player.global_transform.basis.inverse() * camera_parent.global_transform.basis * behavior_camera_local_offset
	if not player_relative_offset.is_equal_approx(expected_offset):
		push_error(description + " expected camera offset " + str(expected_offset) + ", got " + str(player_relative_offset))
		quit(1)
		return false
	return true

# Ensures camera translation leaves the pitch pivot and camera's local animation rotations unchanged.
func _expect_camera_rotations(expected_pivot_rotation: Vector3, expected_camera_rotation: Vector3, description: String) -> bool:
	if not _player._node_camera_pitch_pivot.rotation.is_equal_approx(expected_pivot_rotation):
		push_error("Camera pitch pivot rotation changed " + description)
		quit(1)
		return false
	if not _player._node_camera.rotation.is_equal_approx(expected_camera_rotation):
		push_error("Camera local rotation changed " + description)
		quit(1)
		return false
	return true

# Reports a targeted failure when the behaviour camera-offset vector has an unexpected value.
func _expect_camera_offset_setting(expected_value: Vector3, actual_value: Vector3, description: String) -> bool:
	if not actual_value.is_equal_approx(expected_value):
		push_error(description + " expected " + str(expected_value) + ", got " + str(actual_value))
		quit(1)
		return false
	return true