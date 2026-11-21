## [AI-DOC] Headless integration regression for delayed freefall activation and landing cleanup
## spec: docs/ai/systems/player.md
## status: partial

extends SceneTree

const PLAYER_SCENE_PATH: String = "res://assets/models/player.tscn"
const FLOOR_SHAPE_SIZE: Vector3 = Vector3(30.0, 0.5, 30.0)
const AIRBORNE_POSITION: Vector3 = Vector3(0.0, 4.0, 0.0)
const BEFORE_FREEFALL_DELAY_SECONDS: float = 0.35
const AFTER_FREEFALL_DELAY_SECONDS: float = 0.2

var _player: Player = null
var _animation_tree: AnimationTree = null
var _test_viewport: SubViewport = null

# Builds a real player and collision floor so timing and landing checks exercise CharacterBody3D physics.
func _initialize() -> void:
	_test_viewport = SubViewport.new()
	_test_viewport.size = Vector2i(640, 480)
	root.add_child(_test_viewport)

	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_collision: CollisionShape3D = CollisionShape3D.new()
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = FLOOR_SHAPE_SIZE
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.25
	floor_body.add_child(floor_collision)
	_test_viewport.add_child(floor_body)

	var user_interface_scene: PackedScene = load("res://scenes/menu_ui/menu_ui.tscn")
	if user_interface_scene == null:
		push_error("Failed to load menu_ui.tscn")
		quit(1)
		return
	var user_interface_node: Node = user_interface_scene.instantiate()
	if user_interface_node == null:
		push_error("Failed to instantiate menu_ui.tscn")
		quit(1)
		return
	_test_viewport.add_child(user_interface_node)

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
	_player.position = Vector3(0.0, 2.0, 0.0)
	_test_viewport.add_child(_player)
	call_deferred("_run_freefall_tests")

# Verifies threshold timing, independent animation blending, landing resets, repeat falls, and disabled controls.
func _run_freefall_tests() -> void:
	_animation_tree = UtilsNode.find_animation_tree_recursive(_player)
	if _animation_tree == null:
		push_error("Player AnimationTree is null")
		quit(1)
		return
	_animation_tree.active = true
	if not await _wait_for_floor(120):
		push_error("Player did not settle on the test floor")
		quit(1)
		return

	_player._cheat_fast_mode = true
	_player.set_cheat_disable_gravity(true)
	_player.global_position = AIRBORNE_POSITION
	_player.velocity = Vector3.ZERO
	if not await _wait_for_airborne(10):
		push_error("Player did not leave the floor for the first fall")
		quit(1)
		return
	await _wait_for_physics_frames(_frames_for_duration(BEFORE_FREEFALL_DELAY_SECONDS))
	if not _expect(_player.get_behaviour_status("freefall") == PlayerBehaviour.BehaviourStatus.IDLE, "Freefall activated before the half-second threshold"):
		return
	await _wait_for_physics_frames(_frames_for_duration(AFTER_FREEFALL_DELAY_SECONDS))
	if not _expect(_player._behaviour.is_behaviour_active("freefall"), "Freefall did not activate after sustained airtime"):
		return
	var freefall_blend_amount: float = _get_blend_amount(_animation_tree["parameters/freefall/blend_amount"])
	if not _expect(freefall_blend_amount > 0.0, "Freefall animation blend did not advance"):
		return
	var run_blend_amount: float = _get_blend_amount(_animation_tree["parameters/run/blend_amount"])
	if not _expect(is_zero_approx(run_blend_amount), "Freefall activation changed the run animation blend"):
		return

	_player._cheat_fast_mode = false
	_player.set_cheat_disable_gravity(false)
	_player.velocity.y = -8.0
	if not await _wait_for_floor(120):
		push_error("Player did not land after the first freefall")
		quit(1)
		return
	if not await _wait_for_freefall_idle(60):
		push_error("Freefall blend did not deactivate after landing")
		quit(1)
		return
	if not _expect(is_zero_approx(_player._freefall_air_time), "Landing did not reset the accumulated airborne time"):
		return

	_player.set_cheat_disable_gravity(true)
	_player.global_position = AIRBORNE_POSITION
	_player.velocity = Vector3.ZERO
	if not await _wait_for_airborne(10):
		push_error("Player did not leave the floor for the repeated fall")
		quit(1)
		return
	await _wait_for_physics_frames(_frames_for_duration(BEFORE_FREEFALL_DELAY_SECONDS))
	if not _expect(_player.get_behaviour_status("freefall") == PlayerBehaviour.BehaviourStatus.IDLE, "Repeated fall reused the previous airborne timer"):
		return
	await _wait_for_physics_frames(_frames_for_duration(AFTER_FREEFALL_DELAY_SECONDS))
	if not _expect(_player._behaviour.is_behaviour_active("freefall"), "Freefall did not reactivate on a repeated fall"):
		return
	_player.set_cheat_disable_gravity(false)
	_player.velocity.y = -8.0
	if not await _wait_for_floor(120):
		push_error("Player did not land after the repeated freefall")
		quit(1)
		return
	if not await _wait_for_freefall_idle(60):
		push_error("Repeated freefall blend did not deactivate after landing")
		quit(1)
		return

	_player.control_enabled = false
	_player.set_cheat_disable_gravity(true)
	_player.global_position = AIRBORNE_POSITION
	_player.velocity = Vector3.ZERO
	if not await _wait_for_airborne(10):
		push_error("Player did not leave the floor with controls disabled")
		quit(1)
		return
	await _wait_for_physics_frames(_frames_for_duration(BEFORE_FREEFALL_DELAY_SECONDS))
	if not _expect(_player.get_behaviour_status("freefall") == PlayerBehaviour.BehaviourStatus.IDLE, "Disabled-controls freefall activated before the threshold"):
		return
	await _wait_for_physics_frames(_frames_for_duration(AFTER_FREEFALL_DELAY_SECONDS))
	if not _expect(_player._behaviour.is_behaviour_active("freefall"), "Freefall did not activate while controls were disabled"):
		return
	_player.set_cheat_disable_gravity(false)
	_player.velocity.y = -8.0
	if not await _wait_for_floor(120):
		push_error("Player did not land with controls disabled")
		quit(1)
		return
	if not await _wait_for_freefall_idle(60):
		push_error("Disabled-controls freefall blend did not deactivate after landing")
		quit(1)
		return
	if not _expect(is_zero_approx(_player._freefall_air_time), "Disabled-controls landing did not reset the airborne timer"):
		return

	print("TEST: PASS")
	_test_viewport.queue_free()
	await process_frame
	quit(0)

# Reads AnimationTree's dynamically typed parameter while keeping the test's blend assertions statically typed.
func _get_blend_amount(parameter_value: Variant) -> float:
	if parameter_value is float:
		return parameter_value
	push_error("AnimationTree blend parameter is not a float")
	return -1.0

# Converts short timing windows into deterministic physics-frame counts for the configured tick rate.
func _frames_for_duration(seconds: float) -> int:
	return maxi(1, ceili(seconds * Engine.physics_ticks_per_second))

# Waits for the requested number of physics updates before inspecting a behaviour transition.
func _wait_for_physics_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await physics_frame

# Waits for real collision response to place the player on the floor, failing after a bounded number of frames.
func _wait_for_floor(max_physics_frames: int) -> bool:
	for _frame_index: int in range(max_physics_frames):
		await physics_frame
		if _player.is_on_floor():
			return true
	return false

# Waits until a teleport or fall is reflected in the player's collision state.
func _wait_for_airborne(max_physics_frames: int) -> bool:
	for _frame_index: int in range(max_physics_frames):
		await physics_frame
		if not _player.is_on_floor():
			return true
	return false

# Waits for the blend-out after floor contact so repeated falls start from a clean animation state.
func _wait_for_freefall_idle(max_physics_frames: int) -> bool:
	for _frame_index: int in range(max_physics_frames):
		if _player.get_behaviour_status("freefall") == PlayerBehaviour.BehaviourStatus.IDLE:
			return true
		await physics_frame
	return _player.get_behaviour_status("freefall") == PlayerBehaviour.BehaviourStatus.IDLE

# Reports a focused failure and exits the headless test when a freefall expectation is violated.
func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
		return false
	return true