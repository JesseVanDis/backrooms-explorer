## [AI-DOC] Headless integration regression for smooth movement-facing animation, bounded spine compensation, and camera yaw stability
## spec: docs/ai/systems/player.md
## status: partial

extends SceneTree

const PLAYER_SCENE_PATH: String = "res://assets/models/player.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu_ui/menu_ui.tscn"
const TEST_FLOOR_SIZE: Vector3 = Vector3(30.0, 0.5, 30.0)
const FACING_DOT_THRESHOLD: float = 0.99
const TURN_SPEED_DEGREES_PER_SECOND: float = 450.0

var _player: Player = null
var _camera: Camera3D = null
var _facing_pivot: Node3D = null
var _camera_modifier: SkeletonModifier = null
var _spine_modifier: SkeletonModifier = null
var _spine_skeleton: Skeleton3D = null
var _spine_bone_index: int = -1
var _neutral_spine_forward: Vector3 = Vector3.ZERO
var _processed_spine_forward: Vector3 = Vector3.ZERO
var _test_viewport: SubViewport = null

# Creates the real player scene with the UI and floor required by its initialization and physics.
func _initialize() -> void:
	_test_viewport = SubViewport.new()
	_test_viewport.size = Vector2i(640, 480)
	root.add_child(_test_viewport)

	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_collision: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = TEST_FLOOR_SIZE
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.25
	floor_body.add_child(floor_collision)
	_test_viewport.add_child(floor_body)

	var menu_scene: PackedScene = load(MENU_SCENE_PATH)
	if menu_scene == null:
		push_error("Failed to load menu_ui.tscn")
		quit(1)
		return
	var menu_node: Node = menu_scene.instantiate()
	if menu_node == null:
		push_error("Failed to instantiate menu_ui.tscn")
		quit(1)
		return
	_test_viewport.add_child(menu_node)

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
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
	_player.position = Vector3(0.0, 1.0, 0.0)
	_player.initial_pitch = 20.0
	_player.set_cheat_disable_gravity(true)
	_test_viewport.add_child(_player)
	call_deferred("_run_facing_tests")

# Exercises cardinal and diagonal facing, camera compensation, blocked movement, and reset states.
func _run_facing_tests() -> void:
	_camera = UtilsNode.find_camera_recursive(_player)
	_facing_pivot = _player.find_child("_character_facing_pivot", true, false) as Node3D
	_camera_modifier = _player.find_child("_skeleton_modifier_cam", true, false) as SkeletonModifier
	_spine_modifier = _player.find_child("_skeleton_modifier_spine", true, false) as SkeletonModifier
	_spine_skeleton = _player.find_child("Skeleton3D", true, false) as Skeleton3D
	if _camera == null:
		push_error("Player camera is missing")
		quit(1)
		return
	if _facing_pivot == null:
		push_error("Player character-facing pivot is missing")
		quit(1)
		return
	if _camera_modifier == null:
		push_error("Player camera skeleton modifier is missing")
		quit(1)
		return
	if _spine_modifier == null:
		push_error("Player spine skeleton modifier is missing")
		quit(1)
		return
	if _spine_skeleton == null:
		push_error("Player skeleton is missing")
		quit(1)
		return
	_spine_bone_index = _spine_skeleton.find_bone("CC_Base_Spine01")
	if _spine_bone_index == -1:
		push_error("Player spine bone is missing")
		quit(1)
		return
	_spine_modifier.modification_processed.connect(_on_spine_modifier_processed)
	_player.set_physics_process(false)
	await _wait_for_physics_frames(2)
	await process_frame
	await process_frame
	_neutral_spine_forward = _processed_spine_forward

	if not await _test_spine_yaw_bounds():
		return
	if not await _expect_movement_facing(["forward"], Vector3(0.0, 0.0, -1.0), "forward"):
		return
	if not await _expect_movement_facing(["right"], Vector3(1.0, 0.0, 0.0), "right strafe"):
		return
	if not await _expect_movement_facing(["left"], Vector3(-1.0, 0.0, 0.0), "left strafe"):
		return
	if not await _expect_movement_facing(["forward", "left"], Vector3(-1.0, 0.0, -1.0), "diagonal movement"):
		return
	if not await _expect_movement_facing(["backward"], Vector3(0.0, 0.0, 1.0), "backward movement"):
		return
	if not await _test_smooth_direction_transition():
		return
	if not await _test_shortest_path_turn():
		return

	_release_movement_actions()
	_player.rotation.y = 0.65
	_player.velocity = Vector3.ZERO
	_facing_pivot.rotation.y = 0.0
	_camera_modifier.extra_rotation_degrees.y = 0.0
	await _step_player([])
	var camera_basis_before_strafe: Basis = _camera.global_basis
	await _step_player(["right"])
	var expected_right_direction: Vector3 = _player.global_basis * Vector3.RIGHT
	var expected_first_step: float = -deg_to_rad(TURN_SPEED_DEGREES_PER_SECOND) / float(Engine.physics_ticks_per_second)
	if not _expect(is_equal_approx(_facing_pivot.rotation.y, expected_first_step), "Strafing did not turn at the configured rate"):
		return
	if not _expect_camera_orientation(camera_basis_before_strafe, "pitched camera during strafing"):
		return
	var strafe_turn_frames: int = ceili(90.0 / TURN_SPEED_DEGREES_PER_SECOND * float(Engine.physics_ticks_per_second))
	for _frame_index: int in range(strafe_turn_frames - 1):
		await _step_player(["right"])
		if not _expect_camera_orientation(camera_basis_before_strafe, "pitched camera during the strafe turn"):
			return
	if not _expect_facing(expected_right_direction, "strafe after changing view yaw"):
		return
	if not _expect(is_equal_approx(_camera_modifier.extra_rotation_degrees.x, 0.0), "Camera modifier X rotation changed during yaw compensation"):
		return
	if not _expect(is_equal_approx(_camera_modifier.extra_rotation_degrees.z, 0.0), "Camera modifier Z rotation changed during yaw compensation"):
		return

	if not await _test_blocked_direction_fallback():
		return
	if not await _test_smooth_return_states():
		return

	_release_movement_actions()
	_test_viewport.queue_free()
	await process_frame
	print("TEST: PASS")
	quit(0)

# Lets the actual character scene complete a smooth turn, then checks its world-space travel direction.
func _expect_movement_facing(actions: Array[String], expected_local_direction: Vector3, description: String) -> bool:
	_player.global_position = Vector3.ZERO
	_player.global_position.y = 1.0
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_facing_pivot.rotation.y = 0.0
	_camera_modifier.extra_rotation_degrees.y = 0.0
	await _step_player(actions)
	var expected_world_direction: Vector3 = _player.global_basis * expected_local_direction.normalized()
	for _frame_index: int in range(25):
		var actual_forward: Vector3 = -_facing_pivot.global_basis.z.normalized()
		if actual_forward.dot(expected_world_direction.normalized()) >= FACING_DOT_THRESHOLD:
			break
		await _step_player(actions)
	if not _expect_facing(expected_world_direction, description):
		return false
	return _expect_spine_facing(description)

# Checks that a cardinal direction change advances at a bounded rate and keeps the camera orientation fixed.
func _test_smooth_direction_transition() -> bool:
	_player.global_position = Vector3(0.0, 1.0, 0.0)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_facing_pivot.rotation.y = 0.0
	_camera_modifier.extra_rotation_degrees.y = 0.0
	await _step_player([])
	var camera_basis_before_turn: Basis = _camera.global_basis
	await _step_player(["right"])
	var expected_first_step: float = -deg_to_rad(TURN_SPEED_DEGREES_PER_SECOND) / float(Engine.physics_ticks_per_second)
	if not _expect(is_equal_approx(_facing_pivot.rotation.y, expected_first_step), "Character facing did not advance by the configured turn-rate step"):
		return false
	if not _expect(not is_zero_approx(_facing_pivot.rotation.y) and absf(_facing_pivot.rotation.y) < PI * 0.5, "Character snapped to the strafe direction instead of turning gradually"):
		return false
	if not _expect_camera_orientation(camera_basis_before_turn, "camera during the initial turn step"):
		return false
	var turn_frame_count: int = ceili(90.0 / TURN_SPEED_DEGREES_PER_SECOND * float(Engine.physics_ticks_per_second))
	for _frame_index: int in range(turn_frame_count - 1):
		await _step_player(["right"])
		if not _expect_camera_orientation(camera_basis_before_turn, "camera during the smooth turn"):
			return false
	if not _expect_facing(Vector3.RIGHT, "completed smooth right turn"):
		return false
	return _expect_spine_facing("completed smooth right turn")

# Verifies a turn crossing the yaw wrap boundary takes the short positive arc rather than a full reverse rotation.
func _test_shortest_path_turn() -> bool:
	_player.global_position = Vector3(0.0, 1.0, 0.0)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_facing_pivot.rotation.y = deg_to_rad(179.0)
	_camera_modifier.extra_rotation_degrees.y = -179.0
	await process_frame
	await process_frame
	var camera_basis_before_turn: Basis = _camera.global_basis
	await _step_player(["backward", "right"])
	var expected_yaw: float = deg_to_rad(179.0) + deg_to_rad(TURN_SPEED_DEGREES_PER_SECOND) / float(Engine.physics_ticks_per_second)
	if not _expect(is_equal_approx(_facing_pivot.rotation.y, expected_yaw), "Turn across the yaw boundary did not follow the shortest path"):
		return false
	if not _expect_camera_orientation(camera_basis_before_turn, "camera during the wrapped turn"):
		return false
	_release_movement_actions()
	return true

# Keeps spine counter-yaw bounded through repeated clockwise and counterclockwise full turns.
func _test_spine_yaw_bounds() -> bool:
	_player.global_position = Vector3(0.0, 1.0, 0.0)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_facing_pivot.rotation.y = 0.0
	_camera_modifier.extra_rotation_degrees.y = 0.0
	await process_frame
	await process_frame
	var camera_basis_before_turn: Basis = _camera.global_basis
	var clockwise_actions: Array[String] = ["left", "backward", "right", "forward"]
	var counterclockwise_actions: Array[String] = ["right", "backward", "left", "forward"]
	var turn_frame_count: int = ceili(90.0 / TURN_SPEED_DEGREES_PER_SECOND * float(Engine.physics_ticks_per_second))
	for turn_count: int in range(3):
		for action_name: String in clockwise_actions:
			for _frame_index: int in range(turn_frame_count):
				await _step_player([action_name])
				if not _expect_camera_orientation(camera_basis_before_turn, "camera during repeated clockwise turns"):
					return false
		var expected_clockwise_yaw: float = deg_to_rad(360.0 * float(turn_count + 1))
		if not _expect(absf(_facing_pivot.rotation.y - expected_clockwise_yaw) < deg_to_rad(0.01), "Clockwise movement did not complete a full accumulated turn"):
			return false
		if not _expect_spine_facing("completed clockwise full turn"):
			return false
	for turn_count: int in range(3):
		for action_name: String in counterclockwise_actions:
			for _frame_index: int in range(turn_frame_count):
				await _step_player([action_name])
				if not _expect_camera_orientation(camera_basis_before_turn, "camera during repeated counterclockwise turns"):
					return false
		var expected_counterclockwise_yaw: float = deg_to_rad(360.0 * float(2 - turn_count))
		if not _expect(absf(_facing_pivot.rotation.y - expected_counterclockwise_yaw) < deg_to_rad(0.01), "Counterclockwise movement did not complete a full accumulated turn"):
			return false
		if not _expect_spine_facing("completed counterclockwise full turn"):
			return false
	return true

# Confirms releasing input and locking controls gradually restore view-facing without disturbing the camera.
func _test_smooth_return_states() -> bool:
	var camera_basis_before_idle: Basis = _camera.global_basis
	var yaw_before_idle: float = _facing_pivot.rotation.y
	await _step_player([])
	var yaw_after_idle_step: float = _facing_pivot.rotation.y
	if not _expect(absf(yaw_after_idle_step) > 0.0 and absf(yaw_after_idle_step) < absf(yaw_before_idle), "Releasing movement snapped instead of gradually returning to view-facing"):
		return false
	if not _expect_camera_orientation(camera_basis_before_idle, "camera while returning to view-facing"):
		return false
	for _frame_index: int in range(20):
		if is_zero_approx(_facing_pivot.rotation.y):
			break
		await _step_player([])
		if not _expect_camera_orientation(camera_basis_before_idle, "camera throughout the idle return"):
			return false
	if not _expect(is_zero_approx(_facing_pivot.rotation.y), "Releasing movement did not finish returning the model to view-facing"):
		return false
	if not await _expect_movement_facing(["right"], Vector3.RIGHT, "rightward movement before control lock"):
		return false
	var yaw_before_control_lock: float = _facing_pivot.rotation.y
	var camera_basis_before_control_lock: Basis = _camera.global_basis
	_player.control_enabled = false
	await _step_player(["left"])
	var yaw_after_control_lock_step: float = _facing_pivot.rotation.y
	if not _expect(absf(yaw_after_control_lock_step) > 0.0 and absf(yaw_after_control_lock_step) < absf(yaw_before_control_lock), "Control lock snapped instead of gradually returning to view-facing"):
		return false
	if not _expect_camera_orientation(camera_basis_before_control_lock, "camera while controls are locked"):
		return false
	for _frame_index: int in range(20):
		if is_zero_approx(_facing_pivot.rotation.y):
			break
		await _step_player(["left"])
		if not _expect_camera_orientation(camera_basis_before_control_lock, "camera throughout the control-lock return"):
			_player.control_enabled = true
			return false
	_player.control_enabled = true
	if not _expect(is_zero_approx(_facing_pivot.rotation.y), "Control lock did not finish returning the model to view-facing"):
		return false
	return true

# Advances the real player's physics callback and verifies bounded spine yaw and synchronized camera compensation.
func _step_player(actions: Array[String]) -> void:
	_release_movement_actions()
	for action_name: String in actions:
		Input.action_press(action_name)
	await physics_frame
	_player._physics_process(1.0 / float(Engine.physics_ticks_per_second))
	await process_frame
	await process_frame
	var spine_yaw_degrees: float = _spine_modifier.extra_rotation_degrees.y
	_expect(spine_yaw_degrees >= -180.0 and spine_yaw_degrees <= 180.0, "Spine modifier yaw exceeded the -180 to 180 degree range")
	_expect(is_equal_approx(spine_yaw_degrees, wrapf(-rad_to_deg(_facing_pivot.rotation.y), -180.0, 180.0)), "Spine modifier did not use the bounded counter-yaw for the facing pivot")
	_expect(is_equal_approx(_camera_modifier.extra_rotation_degrees.y, -rad_to_deg(_facing_pivot.rotation.y)), "Camera modifier did not counter-rotate the facing pivot yaw")

# Presses against a nearby wall and confirms the requested direction still controls facing after collision stops motion.
func _test_blocked_direction_fallback() -> bool:
	var wall_body: StaticBody3D = StaticBody3D.new()
	var wall_collision: CollisionShape3D = CollisionShape3D.new()
	var wall_shape: BoxShape3D = BoxShape3D.new()
	wall_shape.size = Vector3(0.2, 2.0, 2.0)
	wall_collision.shape = wall_shape
	wall_body.position = Vector3(0.8, 0.8, 0.0)
	wall_body.add_child(wall_collision)
	_test_viewport.add_child(wall_body)
	_player.global_position = Vector3(0.0, 1.0, 0.0)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	for _frame_index: int in range(20):
		await _step_player(["right"])
	if not _expect(absf(_player.velocity.x) < 0.1, "Wall did not block the player's sideways movement"):
		return false
	return _expect_facing(Vector3.RIGHT, "blocked rightward movement")

# Compares the visible character pivot's forward axis with the expected world-space movement direction.
func _expect_facing(expected_world_direction: Vector3, description: String) -> bool:
	var actual_forward: Vector3 = -_facing_pivot.global_basis.z.normalized()
	var expected_direction: Vector3 = expected_world_direction.normalized()
	return _expect(actual_forward.dot(expected_direction) >= FACING_DOT_THRESHOLD, "Character does not face " + description)

# Checks the processed spine bone keeps its world-space facing aligned with its neutral look direction.
func _expect_spine_facing(description: String) -> bool:
	var actual_forward: Vector3 = _processed_spine_forward
	var facing_dot: float = actual_forward.dot(_neutral_spine_forward)
	return _expect(facing_dot >= FACING_DOT_THRESHOLD, "Upper body does not face the view during " + description + "; facing dot: " + str(facing_dot) + ", actual: " + str(actual_forward) + ", neutral: " + str(_neutral_spine_forward))

# Samples the final spine pose after SkeletonModifier3D has applied its override.
func _on_spine_modifier_processed() -> void:
	_processed_spine_forward = _get_spine_world_forward()

# Reads the actual processed spine pose instead of inferring torso orientation from the modifier property.
func _get_spine_world_forward() -> Vector3:
	var spine_pose: Transform3D = _spine_skeleton.get_bone_global_pose(_spine_bone_index)
	var spine_world_basis: Basis = _spine_skeleton.global_basis * spine_pose.basis
	var spine_forward: Vector3 = -spine_world_basis.z
	spine_forward.y = 0.0
	return spine_forward.normalized()

# Confirms yaw compensation preserves the camera's full pitched orientation rather than only its forward vector.
func _expect_camera_orientation(expected_basis: Basis, description: String) -> bool:
	var actual_basis: Basis = _camera.global_basis
	if actual_basis.x.normalized().dot(expected_basis.x.normalized()) < FACING_DOT_THRESHOLD:
		return _expect(false, "Camera right axis changed during " + description)
	if actual_basis.y.normalized().dot(expected_basis.y.normalized()) < FACING_DOT_THRESHOLD:
		return _expect(false, "Camera up axis changed during " + description)
	return _expect(actual_basis.z.normalized().dot(expected_basis.z.normalized()) >= FACING_DOT_THRESHOLD, "Camera forward axis changed during " + description)

# Releases every movement action so each test case begins with deterministic input state.
func _release_movement_actions() -> void:
	Input.action_release("forward")
	Input.action_release("backward")
	Input.action_release("left")
	Input.action_release("right")

# Waits for real physics updates before the test disables automatic player processing.
func _wait_for_physics_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await physics_frame

# Reports a focused failure and exits the headless test when an expectation is violated.
func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
		return false
	return true