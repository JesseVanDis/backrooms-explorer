## [AI-DOC] Headless integration regression for AnimationTree-driven player behaviour statuses and restrictions
## spec: docs/ai/systems/player.md
## status: partial

extends SceneTree

var _player: Player = null
var _animation_tree: AnimationTree = null
var _animation_player: AnimationPlayer = null

# Loads the real player scene so behaviour tests use the gameplay AnimationTree.
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

	call_deferred("_run_behaviour_tests")

# Verifies behaviour status transitions, canonical restriction keys, one-shot lifetimes, and the built-in push speed cap.
func _run_behaviour_tests() -> void:
	_animation_tree = UtilsNode.find_animation_tree_recursive(_player)
	_animation_player = _player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_tree == null:
		push_error("Player AnimationTree is null")
		quit(1)
		return
	if _animation_player == null:
		push_error("Player AnimationPlayer is null")
		quit(1)
		return
	if _player._node_camera_pitch_pivot == null:
		push_error("Player camera pitch pivot is null")
		quit(1)
		return

	_animation_tree.active = true
	if not _expect_status(PlayerBehaviour.BehaviourStatus.ACTIVE, _player.get_behaviour_status(""), "always-active behaviour"):
		return
	if not _expect_setting(360.0, _player._behaviour.active_settings.player_max_look_freedom_degrees_h, "default horizontal look freedom"):
		return
	if not _expect_setting(1.0, _player._behaviour.active_settings.player_movement_multiplier, "default movement multiplier"):
		return

	_player.add_behaviour("test_common_look_blend", "parameters/run/blend_amount", {
		"player_max_look_freedom_degrees": 80.0
	})
	_player.activate_behaviour("test_common_look_blend")
	if not _expect_status(PlayerBehaviour.BehaviourStatus.ENABLING, _player.get_behaviour_status("test_common_look_blend"), "blend activation status"):
		return
	if not _expect_setting(80.0, _player._behaviour.active_settings.player_max_look_freedom_degrees_h, "common horizontal look freedom"):
		return
	if not _expect_setting(80.0, _player._behaviour.active_settings.player_max_look_freedom_degrees_v, "common vertical look freedom"):
		return
	_player._behaviour.update(1.0)
	if not _expect_status(PlayerBehaviour.BehaviourStatus.ACTIVE, _player.get_behaviour_status("test_common_look_blend"), "completed blend activation status"):
		return
	_player.deactivate_behaviour("test_common_look_blend")
	if not _expect_status(PlayerBehaviour.BehaviourStatus.DISABLING, _player.get_behaviour_status("test_common_look_blend"), "blend deactivation status"):
		return
	_player._behaviour.update(1.0)
	if not _expect_status(PlayerBehaviour.BehaviourStatus.IDLE, _player.get_behaviour_status("test_common_look_blend"), "completed blend deactivation status"):
		return
	var default_run_behaviour: PlayerBehaviour.Behaviour = _player._behaviour._behaviours["run"]
	default_run_behaviour.animation_tree_parameter = ""
	default_run_behaviour.additional_settings.erase("player_camera_offset")
	default_run_behaviour.additional_settings.erase("player_camera_offset_speed")
	_player._behaviour.refresh_active_settings()
	var common_look_behaviour: PlayerBehaviour.Behaviour = _player._behaviour._behaviours["test_common_look_blend"]
	common_look_behaviour.animation_tree_parameter = ""
	common_look_behaviour.additional_settings.clear()
	_player._behaviour.refresh_active_settings()

	_player.add_behaviour("test_interrupted_blend", "parameters/run/blend_amount", {
		"anim_activation_speed": 1.0,
		"anim_deactivation_speed": 1.0
	})
	_player.activate_behaviour("test_interrupted_blend")
	_player._behaviour.update(0.25)
	if not _expect_status(PlayerBehaviour.BehaviourStatus.ENABLING, _player.get_behaviour_status("test_interrupted_blend"), "partial blend activation status"):
		return
	_player.deactivate_behaviour("test_interrupted_blend")
	if not _expect_status(PlayerBehaviour.BehaviourStatus.DISABLING, _player.get_behaviour_status("test_interrupted_blend"), "partial blend deactivation status"):
		return
	_player._behaviour.update(0.1)
	if not _expect_status(PlayerBehaviour.BehaviourStatus.DISABLING, _player.get_behaviour_status("test_interrupted_blend"), "blend remains disabling while nonzero"):
		return
	_player.activate_behaviour("test_interrupted_blend")
	if not _expect_status(PlayerBehaviour.BehaviourStatus.ENABLING, _player.get_behaviour_status("test_interrupted_blend"), "reactivated blend status"):
		return
	_player._behaviour.update(1.0)
	if not _expect_status(PlayerBehaviour.BehaviourStatus.ACTIVE, _player.get_behaviour_status("test_interrupted_blend"), "reactivated blend reaches active"):
		return
	_player.deactivate_behaviour("test_interrupted_blend")
	_player._behaviour.update(1.0)
	if not _expect_status(PlayerBehaviour.BehaviourStatus.IDLE, _player.get_behaviour_status("test_interrupted_blend"), "interrupted blend returns to idle"):
		return
	var interrupted_behaviour: PlayerBehaviour.Behaviour = _player._behaviour._behaviours["test_interrupted_blend"]
	interrupted_behaviour.animation_tree_parameter = ""
	interrupted_behaviour.additional_settings.clear()
	_player._behaviour.refresh_active_settings()

	_player.add_behaviour("test_instant_blend", "parameters/run/blend_amount", {
		"anim_activation_speed": -1.0,
		"anim_deactivation_speed": -1.0
	})
	_player.activate_behaviour("test_instant_blend")
	if not _expect_status(PlayerBehaviour.BehaviourStatus.ACTIVE, _player.get_behaviour_status("test_instant_blend"), "instant blend activation status"):
		return
	_player.deactivate_behaviour("test_instant_blend")
	if not _expect_status(PlayerBehaviour.BehaviourStatus.IDLE, _player.get_behaviour_status("test_instant_blend"), "instant blend deactivation status"):
		return

	_player.add_behaviour("test_restricted_blend", "parameters/run/blend_amount", {
		"player_max_look_freedom_degrees_h": 0.0,
		"player_max_look_freedom_degrees_v": 0.0,
		"player_movement_multiplier": 0.0
	})
	_player.activate_behaviour("test_restricted_blend")
	if not _expect_setting(0.0, _player._behaviour.active_settings.player_max_look_freedom_degrees_h, "canonical horizontal look freedom"):
		return
	if not _expect_setting(0.0, _player._behaviour.active_settings.player_movement_multiplier, "canonical movement multiplier"):
		return
	if not _expect_setting(0.0, _player._current_speed(Vector2(0.0, -1.0)), "canonical movement speed"):
		return

	_player.add_behaviour("test_prefixed_blend", "parameters/push/blend_amount", {
		"player_max_look_freedom_degrees_v": 30.0,
		"player_max_movement_speed": 0.5
	})
	_player.activate_behaviour("test_prefixed_blend")
	if not _expect_setting(0.0, _player._behaviour.active_settings.player_max_look_freedom_degrees_h, "merged horizontal look freedom"):
		return
	if not _expect_setting(30.0, _player._behaviour.active_settings.player_max_look_freedom_degrees_v, "vertical look freedom"):
		return
	if not _expect_setting(0.0, _player._behaviour.active_settings.player_movement_multiplier, "merged movement multiplier"):
		return
	if not _expect_setting(0.5, _player._behaviour.active_settings.player_max_movement_speed, "movement speed cap"):
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_player.rotation.y = 0.0
	_player._spine_pitch = 0.0
	_send_mouse_motion(Vector2(100.0, 100000.0))
	if not _expect_setting(0.0, _player.rotation.y, "immediate horizontal look restriction"):
		return
	if not _expect_setting(deg_to_rad(15.0), _player._spine_pitch, "immediate vertical look restriction"):
		return

	_player.deactivate_behaviour("test_restricted_blend")
	_player.deactivate_behaviour("test_prefixed_blend")
	_player._behaviour.update(1.0)
	_player.add_behaviour("test_landing", "parameters/lvl_0_landing/request", {
		"player_max_look_freedom_degrees_h": 0.0,
		"player_max_look_freedom_degrees_v": 0.0,
		"player_movement_multiplier": 0.0
	})
	_player.activate_behaviour("test_landing")
	if not _expect_status(PlayerBehaviour.BehaviourStatus.ENABLING, _player.get_behaviour_status("test_landing"), "pending one-shot status"):
		return
	if not _expect_setting(0.0, _player._behaviour.active_settings.player_movement_multiplier, "pending one-shot movement restriction"):
		return
	var one_shot_request_value: float = _animation_tree["parameters/lvl_0_landing/request"]
	if not _expect_setting(1.0, one_shot_request_value, "one-shot fire request"):
		return

	_animation_tree.advance(0.0)
	_player._behaviour.refresh_active_settings()
	if not _expect_status(PlayerBehaviour.BehaviourStatus.ACTIVE, _player.get_behaviour_status("test_landing"), "playing one-shot status"):
		return
	if not _expect_setting(0.0, _player._behaviour.active_settings.player_max_look_freedom_degrees_h, "playing one-shot horizontal look restriction"):
		return
	var is_landing_animation_active: bool = _animation_tree["parameters/lvl_0_landing/active"]
	if not is_landing_animation_active:
		push_error("Landing one-shot did not become active after its fire request")
		quit(1)
		return

	var landing_animation: Animation = _animation_player.get_animation("lvl_0_landing")
	if landing_animation == null:
		push_error("lvl_0_landing animation is missing")
		quit(1)
		return
	_animation_tree.advance(landing_animation.length + 0.25)
	_player._behaviour.refresh_active_settings()
	if not _expect_status(PlayerBehaviour.BehaviourStatus.IDLE, _player.get_behaviour_status("test_landing"), "completed one-shot status"):
		return
	is_landing_animation_active = _animation_tree["parameters/lvl_0_landing/active"]
	if is_landing_animation_active:
		push_error("Landing one-shot remained active after its animation completed")
		quit(1)
		return
	if not _expect_setting(1.0, _player._behaviour.active_settings.player_movement_multiplier, "completed one-shot movement release"):
		return

	_player.activate_behaviour("test_landing")
	if not _expect_setting(0.0, _player._behaviour.active_settings.player_movement_multiplier, "replayed one-shot restriction"):
		return
	_animation_tree.advance(0.0)
	_player._behaviour.refresh_active_settings()
	is_landing_animation_active = _animation_tree["parameters/lvl_0_landing/active"]
	if not is_landing_animation_active:
		push_error("Landing one-shot did not replay after completion")
		quit(1)
		return

	_player.deactivate_behaviour("test_landing")
	if not _expect_status(PlayerBehaviour.BehaviourStatus.DISABLING, _player.get_behaviour_status("test_landing"), "aborted one-shot status"):
		return
	one_shot_request_value = _animation_tree["parameters/lvl_0_landing/request"]
	if not _expect_setting(2.0, one_shot_request_value, "one-shot abort request"):
		return
	_animation_tree.advance(0.0)
	_player._behaviour.refresh_active_settings()
	if not _expect_status(PlayerBehaviour.BehaviourStatus.IDLE, _player.get_behaviour_status("test_landing"), "cancelled one-shot status"):
		return
	is_landing_animation_active = _animation_tree["parameters/lvl_0_landing/active"]
	if is_landing_animation_active:
		push_error("Landing one-shot remained active after cancellation")
		quit(1)
		return
	if not _expect_setting(1.0, _player._behaviour.active_settings.player_movement_multiplier, "cancelled one-shot movement release"):
		return

	_player.activate_behaviour("test_landing")
	if not _expect_status(PlayerBehaviour.BehaviourStatus.ENABLING, _player.get_behaviour_status("test_landing"), "one-shot status before pending cancellation"):
		return
	_player.deactivate_behaviour("test_landing")
	if not _expect_status(PlayerBehaviour.BehaviourStatus.IDLE, _player.get_behaviour_status("test_landing"), "one-shot cancelled before playback"):
		return

	_player.activate_behaviour("push")
	if not _expect_setting(0.15, _player._behaviour.active_settings.player_max_movement_speed_to_target, "built-in push target speed cap"):
		return
	var push_target: Node3D = Node3D.new()
	root.add_child(push_target)
	push_target.global_position = _player.global_position + Vector3(0.0, 0.0, -1.0)
	_player.behaviour_target = push_target
	if not _expect_setting(0.15, _player._current_speed(Vector2(0.0, -1.0)), "built-in push movement speed"):
		return
	_player.behaviour_target = null
	push_target.queue_free()

	print("TEST: PASS")
	quit(0)

# Sends mouse motion through the same captured-mouse handler used by gameplay.
func _send_mouse_motion(relative_motion: Vector2) -> void:
	var mouse_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_motion.relative = relative_motion
	_player._unhandled_input(mouse_motion)

# Reports a targeted failure when a behaviour setting is not active immediately.
func _expect_setting(expected_value: float, actual_value: float, description: String) -> bool:
	if not is_equal_approx(expected_value, actual_value):
		push_error(description + " expected " + str(expected_value) + ", got " + str(actual_value))
		quit(1)
		return false
	return true

# Reports a targeted failure when a behaviour is not in the expected lifecycle state.
func _expect_status(expected_status: PlayerBehaviour.BehaviourStatus, actual_status: PlayerBehaviour.BehaviourStatus, description: String) -> bool:
	if expected_status != actual_status:
		push_error(description + " expected " + str(expected_status) + ", got " + str(actual_status))
		quit(1)
		return false
	return true