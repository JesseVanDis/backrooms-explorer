## [AI-DOC] Integration test verifying frontroom box proximity drives push movement and perspective-hands yaw
## spec: scenes/frontroom_0/docs/SPEC.md
## status: complete

extends SceneTree

const FRONTROOM_SCENE_PATH: String = "res://scenes/frontroom_0/frontroom_0.tscn"
const MOVING_BOX_PATHS: Array[NodePath] = [
	NodePath("_viewport_container/_viewport/MovingBox1"),
	NodePath("_viewport_container/_viewport/MovingBox2"),
	NodePath("_viewport_container/_viewport/MovingBox_kitchen_big"),
	NodePath("_viewport_container/_viewport/MovingBox_kitchen_big2")
]

var _frontroom: Node = null
var _player: Player = null
var _animation_tree: AnimationTree = null
var _head_pitch_modifier: SkeletonModifier = null
var _hands_modifier: SkeletonModifier = null
var _moving_boxes: Array[RigidBody3D] = []


# Loads the real frontroom scene so the regression exercises its current player and AnimationTree integration.
func _initialize() -> void:
	var frontroom_scene: PackedScene = load(FRONTROOM_SCENE_PATH)
	if frontroom_scene == null:
		push_error("Failed to load frontroom_0.tscn")
		quit(1)
		return

	_frontroom = frontroom_scene.instantiate()
	if _frontroom == null:
		push_error("Failed to instantiate frontroom_0.tscn")
		quit(1)
		return

	root.add_child(_frontroom)
	_player = UtilsNode.find_player(self)
	if _player == null:
		push_error("Player not found in frontroom_0")
		quit(1)
		return

	call_deferred("_run_box_push_tests")


# Covers box selection, target-relative movement, locomotion selection, push blending, and hand aiming in the real scene.
func _run_box_push_tests() -> void:
	_frontroom.set_physics_process(false)
	_player.set_physics_process(false)
	_player.control_enabled = false
	_animation_tree = UtilsNode.find_animation_tree_recursive(_player)
	if _animation_tree == null:
		push_error("Player AnimationTree is null")
		quit(1)
		return
	_head_pitch_modifier = UtilsNode.find_node_with_name_recursive(_player, "_skeleton_modifier_headpitch") as SkeletonModifier
	_hands_modifier = UtilsNode.find_node_with_name_recursive(_player, "_skeleton_modifier_perspective_hands") as SkeletonModifier
	if _head_pitch_modifier == null:
		push_error("Player head-pitch modifier is null")
		quit(1)
		return
	if _hands_modifier == null:
		push_error("Player perspective-hands modifier is null")
		quit(1)
		return

	_animation_tree.active = true
	for box_path: NodePath in MOVING_BOX_PATHS:
		var box: RigidBody3D = _frontroom.get_node(box_path) as RigidBody3D
		if box == null:
			push_error("Moving box not found: " + str(box_path))
			quit(1)
			return
		box.freeze = true
		_moving_boxes.append(box)

	_player.global_position = Vector3(0.0, 1.0, 0.0)
	_set_boxes_out_of_range()
	_frontroom.call("_update_player_speed")
	if not _expect_target(null, "no nearby box clears the push target"):
		return
	if not _expect_setting(3.0, _player._current_speed(Vector2(0.0, -1.0)), "normal movement speed with no nearby box"):
		return

	_player.activate_behaviour("run")
	_player._behaviour.update(0.5)
	_frontroom.call("_update_player_speed")
	var run_blend_amount: float = _animation_tree["parameters/run/blend_amount"]
	if not _expect_setting(1.0, run_blend_amount, "unrelated run behaviour remains active"):
		return
	var expected_head_pitch: Vector3 = Vector3(4.0, 7.0, -9.0)
	var expected_hands_x: float = 13.0
	var expected_hands_z: float = -19.0
	_head_pitch_modifier.extra_rotation_degrees = expected_head_pitch
	_hands_modifier.extra_rotation_degrees = Vector3(expected_hands_x, 35.0, expected_hands_z)
	_player.behaviour_target = _moving_boxes[0]
	var expected_run_only_yaw: float = rad_to_deg(lerp_angle(deg_to_rad(35.0), 0.0, 0.3))
	_player._physics_process(0.01)
	if not _expect_setting(expected_run_only_yaw, _hands_modifier.extra_rotation_degrees.y, "a non-push target does not steer the hands"):
		return
	if not _expect_modifier_axes(expected_hands_x, expected_hands_z, expected_head_pitch, "run-only hand return"):
		return
	_player.behaviour_target = null
	_player.deactivate_behaviour("run")
	_player._behaviour.update(1.0)

	for box_index: int in range(_moving_boxes.size()):
		_set_boxes_out_of_range()
		var selected_box: RigidBody3D = _moving_boxes[box_index]
		selected_box.global_position = _player.global_position + Vector3(0.5, 0.0, 0.0)
		_frontroom.call("_update_player_speed")
		if not _expect_target(selected_box, "each moving box selects its own push target"):
			return

	_set_boxes_out_of_range()
	_moving_boxes[0].global_position = _player.global_position + Vector3(0.5, 0.0, 0.0)
	_moving_boxes[1].global_position = _player.global_position + Vector3(0.5, 0.0, 0.0)
	_frontroom.call("_update_player_speed")
	if not _expect_target(_moving_boxes[0], "the first nearby box retains priority"):
		return

	_set_boxes_out_of_range()
	var target_box: RigidBody3D = _moving_boxes[3]
	target_box.global_position = _player.global_position + Vector3(0.0, 0.0, -0.5)
	_frontroom.call("_update_player_speed")
	if not _expect_target(target_box, "changing nearby boxes updates the push target"):
		return
	if not _expect_setting(0.15, _player._behaviour.active_settings.player_max_movement_speed_to_target, "push target speed cap"):
		return
	if not _expect_setting(0.15, _player._current_speed(Vector2(0.0, -1.0)), "movement speed toward the selected box"):
		return

	_player.global_rotation.y = deg_to_rad(37.0)
	_head_pitch_modifier.extra_rotation_degrees = expected_head_pitch
	_hands_modifier.extra_rotation_degrees = Vector3(expected_hands_x, 0.0, expected_hands_z)
	_set_target_box_local_offset(target_box, Vector3(0.5, 0.0, 0.0))
	if not _expect_behaviour_active(true, "push is active after a nearby box is selected"):
		return
	var expected_right_yaw: float = rad_to_deg(lerp_angle(0.0, deg_to_rad(-90.0), 0.3))
	_player._physics_process(0.01)
	if not _expect_setting(expected_right_yaw, _hands_modifier.extra_rotation_degrees.y, "hands smoothly turn toward a right-side box in player space"):
		return
	if not _expect_modifier_axes(expected_hands_x, expected_hands_z, expected_head_pitch, "right-side hand aim"):
		return

	_set_target_box_local_offset(target_box, Vector3(-0.5, 0.0, 0.0))
	var expected_left_yaw: float = rad_to_deg(lerp_angle(deg_to_rad(expected_right_yaw), deg_to_rad(90.0), 0.3))
	_player._physics_process(0.01)
	if not _expect_setting(expected_left_yaw, _hands_modifier.extra_rotation_degrees.y, "hands follow a changed left-side target"):
		return
	if not _expect_modifier_axes(expected_hands_x, expected_hands_z, expected_head_pitch, "left-side hand aim"):
		return

	_set_target_box_local_offset(target_box, Vector3(0.0, 0.0, -0.5))
	var expected_forward_yaw: float = rad_to_deg(lerp_angle(deg_to_rad(expected_left_yaw), 0.0, 0.3))
	_player._physics_process(0.01)
	if not _expect_setting(expected_forward_yaw, _hands_modifier.extra_rotation_degrees.y, "hands follow a forward target after the player turns"):
		return
	if not _expect_modifier_axes(expected_hands_x, expected_hands_z, expected_head_pitch, "forward hand aim"):
		return

	var push_blend_amount: float = _animation_tree["parameters/push/blend_amount"]
	if push_blend_amount <= 0.0 or push_blend_amount >= 1.0:
		push_error("Push behaviour did not blend in gradually: " + str(push_blend_amount))
		quit(1)
		return
	_player._behaviour.update(0.1)

	_set_boxes_out_of_range()
	_moving_boxes[0].global_position = _player.global_position + Vector3(1.0, 0.0, 0.0)
	_frontroom.call("_update_player_speed")
	if not _expect_target(null, "a box exactly one metre away is outside the strict detection range"):
		return
	if not _expect_setting(3.0, _player._current_speed(Vector2(0.0, -1.0)), "normal movement speed returns as soon as the target clears"):
		return
	if not _expect_behaviour_active(true, "push remains active during its fade-out"):
		return
	var yaw_before_release: float = _hands_modifier.extra_rotation_degrees.y
	var expected_release_yaw: float = rad_to_deg(lerp_angle(deg_to_rad(yaw_before_release), 0.0, 0.3))
	_player._physics_process(0.01)
	if not _expect_setting(expected_release_yaw, _hands_modifier.extra_rotation_degrees.y, "hands smoothly return toward neutral when the target clears"):
		return
	if not _expect_modifier_axes(expected_hands_x, expected_hands_z, expected_head_pitch, "hand aim fade-out"):
		return

	var blend_amount_before_fade_out: float = _animation_tree["parameters/push/blend_amount"]
	_player._behaviour.update(0.05)
	var blend_amount_during_fade_out: float = _animation_tree["parameters/push/blend_amount"]
	if blend_amount_during_fade_out <= 0.0 or blend_amount_during_fade_out >= blend_amount_before_fade_out:
		push_error("Push behaviour did not blend out gradually: " + str(blend_amount_during_fade_out))
		quit(1)
		return
	_player._behaviour.update(1.0)
	var final_push_blend_amount: float = _animation_tree["parameters/push/blend_amount"]
	if not _expect_setting(0.0, final_push_blend_amount, "push behaviour finishes blending out"):
		return
	if not _expect_behaviour_active(false, "push becomes inactive after its fade-out"):
		return
	_player._physics_process(1.0)
	if not _expect_setting(0.0, _hands_modifier.extra_rotation_degrees.y, "hands finish returning to neutral"):
		return
	if not _expect_modifier_axes(expected_hands_x, expected_hands_z, expected_head_pitch, "neutral hand pose"):
		return
	if not _run_locomotion_tests():
		return

	print("TEST: PASS")
	quit(0)


# Verifies slow push movement selects stumble and that normal speed, idle, and control locks select the correct blends.
func _run_locomotion_tests() -> bool:
	_player.global_position = Vector3(0.0, 1.0, 0.0)
	_player.global_rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_player.control_enabled = true
	Input.action_release("forward")
	Input.action_release("backward")
	_set_boxes_out_of_range()
	_frontroom.call("_update_player_speed")

	Input.action_press("forward")
	_player._physics_process(0.01)
	_player._behaviour.update(0.05)
	if not _expect_locomotion_blends(0.2, 0.0, "normal movement starts run"):
		return false
	_player._behaviour.update(1.0)
	if not _expect_locomotion_blends(1.0, 0.0, "normal movement completes run blend"):
		return false

	var target_box: RigidBody3D = _moving_boxes[3]
	_set_target_box_local_offset(target_box, Vector3(0.0, 0.0, -0.5))
	if not _expect_target(target_box, "slow movement test selects the nearby box"):
		return false
	if not _expect_setting(0.15, _player._current_speed(Vector2(0.0, -1.0)), "slow movement speed toward the box"):
		return false
	_player._physics_process(0.01)
	var slow_horizontal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	if slow_horizontal_speed >= 1.0:
		push_error("Movement toward a box should be below the stumble threshold: " + str(slow_horizontal_speed))
		quit(1)
		return false
	_player._behaviour.update(0.05)
	if not _expect_locomotion_blends(0.8, 0.2, "slow box movement cross-fades run into stumble"):
		return false
	_player._behaviour.update(1.0)
	if not _expect_locomotion_blends(0.0, 1.0, "slow box movement completes stumble blend"):
		return false
	if _animation_tree["parameters/push/blend_amount"] <= 0.0:
		push_error("Push behaviour should remain active while stumble is selected")
		quit(1)
		return false

	Input.action_release("forward")
	Input.action_press("backward")
	_player._physics_process(0.01)
	var recovery_horizontal_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	if recovery_horizontal_speed < 1.0:
		push_error("Movement away from the box should recover to run speed: " + str(recovery_horizontal_speed))
		quit(1)
		return false
	_player._behaviour.update(0.05)
	if not _expect_locomotion_blends(0.2, 0.8, "movement away from the box cross-fades stumble into run"):
		return false
	_player._behaviour.update(1.0)
	if not _expect_locomotion_blends(1.0, 0.0, "movement away from the box completes run blend"):
		return false

	Input.action_release("backward")
	_player._physics_process(0.01)
	_player._behaviour.update(1.0)
	if not _expect_locomotion_blends(0.0, 0.0, "releasing movement clears both locomotion blends"):
		return false

	_player.behaviour_target = null
	var original_max_speed: float = _player.max_speed
	_player.max_speed = 0.999
	Input.action_press("forward")
	_player._physics_process(0.01)
	_player._behaviour.update(1.0)
	if not _expect_locomotion_blends(0.0, 1.0, "speed just below the threshold selects stumble"):
		return false

	_player.activate_behaviour("run")
	_player._behaviour.update(1.0)
	_player.control_enabled = false
	_player._physics_process(0.01)
	_player._behaviour.update(1.0)
	if not _expect_locomotion_blends(0.0, 0.0, "control lock clears run and stumble"):
		return false
	if _animation_tree["parameters/push/blend_amount"] <= 0.0:
		push_error("Control lock should not clear the independent push behaviour")
		quit(1)
		return false

	_player.control_enabled = true
	_player.max_speed = 1.0
	_player._physics_process(0.01)
	_player._behaviour.update(1.0)
	if not _expect_locomotion_blends(1.0, 0.0, "speed exactly at the threshold selects run"):
		return false

	_player.max_speed = original_max_speed
	_player.control_enabled = false
	Input.action_release("forward")
	Input.action_release("backward")
	return true


# Checks the current run and stumble blend values together so cross-fades cannot leave both targets active.
func _expect_locomotion_blends(expected_run: float, expected_stumble: float, description: String) -> bool:
	var run_blend_amount: float = _animation_tree["parameters/run/blend_amount"]
	var stumble_blend_amount: float = _animation_tree["parameters/stumble/blend_amount"]
	if not _expect_setting(expected_run, run_blend_amount, description + " run"):
		return false
	if not _expect_setting(expected_stumble, stumble_blend_amount, description + " stumble"):
		return false
	return true


# Moves every frozen box far from the player to isolate each proximity check.
func _set_boxes_out_of_range() -> void:
	for box_index: int in range(_moving_boxes.size()):
		var box: RigidBody3D = _moving_boxes[box_index]
		box.global_position = _player.global_position + Vector3(10.0 + float(box_index) * 3.0, 0.0, 20.0)


# Positions one box using player-local coordinates and lets frontroom select the resulting push target.
func _set_target_box_local_offset(box: RigidBody3D, local_offset: Vector3) -> void:
	_set_boxes_out_of_range()
	box.global_position = _player.global_position + _player.global_transform.basis * local_offset
	_frontroom.call("_update_player_speed")


# Checks whether the named behaviour remains active through activation and fade-out transitions.
func _expect_behaviour_active(expected_active: bool, description: String) -> bool:
	var actual_active: bool = _player._behaviour.is_behaviour_active("push")
	if actual_active != expected_active:
		push_error(description + ": expected " + str(expected_active) + ", got " + str(actual_active))
		quit(1)
		return false
	return true


# Confirms aiming only changes the perspective modifier's yaw and never alters head pitch.
func _expect_modifier_axes(expected_hands_x: float, expected_hands_z: float, expected_head_pitch: Vector3, description: String) -> bool:
	if not _expect_setting(expected_hands_x, _hands_modifier.extra_rotation_degrees.x, description + " hands X"):
		return false
	if not _expect_setting(expected_hands_z, _hands_modifier.extra_rotation_degrees.z, description + " hands Z"):
		return false
	if not _expect_setting(expected_head_pitch.x, _head_pitch_modifier.extra_rotation_degrees.x, description + " head-pitch X"):
		return false
	if not _expect_setting(expected_head_pitch.y, _head_pitch_modifier.extra_rotation_degrees.y, description + " head-pitch Y"):
		return false
	if not _expect_setting(expected_head_pitch.z, _head_pitch_modifier.extra_rotation_degrees.z, description + " head-pitch Z"):
		return false
	return true


# Reports which selected box failed to become the player's current behaviour target.
func _expect_target(expected_target: Node3D, description: String) -> bool:
	if _player.behaviour_target != expected_target:
		push_error(description + ": expected " + str(expected_target) + ", got " + str(_player.behaviour_target))
		quit(1)
		return false
	return true


# Reports numeric mismatches with context so behaviour and movement regressions are easy to diagnose.
func _expect_setting(expected_value: float, actual_value: float, description: String) -> bool:
	if not is_equal_approx(expected_value, actual_value):
		push_error(description + " expected " + str(expected_value) + ", got " + str(actual_value))
		quit(1)
		return false
	return true