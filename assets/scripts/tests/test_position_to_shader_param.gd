## [AI-DOC] Headless regression for position-driven shader parameters and the character hand opacity animation
## spec: docs/ai/systems/player.md
## status: complete

extends SceneTree

const CHARACTER_SCENE_PATH: String = "res://assets/models/character_main.tscn"
const LEGACY_HANDS_SCENE_PATH: String = "res://assets/models/hands.tscn"
const TEST_SHADER_CODE: String = """
shader_type spatial;
uniform vec3 local_position = vec3(0.0);
uniform vec3 global_position = vec3(0.0);
uniform float local_x = 0.0;
uniform float local_y = 0.0;
uniform float local_z = 0.0;

void fragment() {
	ALBEDO = local_position + global_position + vec3(local_x, local_y, local_z);
}
"""


# Runs isolated driver checks and then verifies the existing character animation feeds hand opacity through the same component.
func _initialize() -> void:
	call_deferred("_run_tests")


# Covers vector and scalar outputs, coordinate spaces, clamping, mesh material isolation, invalid setup, and the real animation track.
func _run_tests() -> void:
	var test_root: Node3D = Node3D.new()
	root.add_child(test_root)
	var test_material: ShaderMaterial = _create_test_material()
	if test_material == null:
		push_error("Failed to create a test ShaderMaterial")
		quit(1)
		return
	if not await _test_position_outputs(test_root, test_material):
		quit(1)
		return
	if not await _test_mesh_material_isolation(test_root, test_material):
		quit(1)
		return
	if not await _test_invalid_configuration(test_root, test_material):
		quit(1)
		return
	if not _test_legacy_hands_scene(test_root):
		quit(1)
		return
	if not await _test_character_hand_animation(test_root):
		quit(1)
		return

	print("TEST: PASS")
	quit(0)


# Builds a real shader with each output type so uniform validation uses Godot's shader reflection data.
func _create_test_material() -> ShaderMaterial:
	var test_shader: Shader = Shader.new()
	test_shader.code = TEST_SHADER_CODE
	var test_material: ShaderMaterial = ShaderMaterial.new()
	test_material.shader = test_shader
	return test_material


# Exercises local and global Vector3 values, each scalar axis, bounds clamping, and updates after the source moves.
func _test_position_outputs(test_root: Node3D, test_material: ShaderMaterial) -> bool:
	var local_vector_driver: PositionToShaderParam = _create_driver(test_root, test_material, &"local_position", PositionToShaderParam.PositionComponent.VECTOR3, PositionToShaderParam.PositionSpace.LOCAL, false)
	local_vector_driver.position = Vector3(-2.0, 3.5, 0.25)
	await _wait_for_driver_update()
	if not _expect_vector3(Vector3(-2.0, 3.5, 0.25), test_material.get_shader_parameter(&"local_position"), "local Vector3 output"):
		return false
	local_vector_driver.position = Vector3(4.0, -1.0, 7.0)
	await _wait_for_driver_update()
	if not _expect_vector3(Vector3(4.0, -1.0, 7.0), test_material.get_shader_parameter(&"local_position"), "updated local Vector3 output"):
		return false

	var global_parent: Node3D = Node3D.new()
	global_parent.position = Vector3(10.0, -5.0, 2.0)
	test_root.add_child(global_parent)
	var global_vector_driver: PositionToShaderParam = _create_driver(global_parent, test_material, &"global_position", PositionToShaderParam.PositionComponent.VECTOR3, PositionToShaderParam.PositionSpace.GLOBAL, false)
	global_vector_driver.position = Vector3(1.0, 2.0, -3.0)
	await _wait_for_driver_update()
	if not _expect_vector3(Vector3(11.0, -3.0, -1.0), test_material.get_shader_parameter(&"global_position"), "global Vector3 output"):
		return false

	var x_driver: PositionToShaderParam = _create_driver(test_root, test_material, &"local_x", PositionToShaderParam.PositionComponent.X, PositionToShaderParam.PositionSpace.LOCAL, false)
	x_driver.position = Vector3(4.5, 0.0, 0.0)
	var y_driver: PositionToShaderParam = _create_driver(test_root, test_material, &"local_y", PositionToShaderParam.PositionComponent.Y, PositionToShaderParam.PositionSpace.LOCAL, true)
	y_driver.position = Vector3(0.0, 1.5, 0.0)
	var z_driver: PositionToShaderParam = _create_driver(test_root, test_material, &"local_z", PositionToShaderParam.PositionComponent.Z, PositionToShaderParam.PositionSpace.LOCAL, true)
	z_driver.position = Vector3(0.0, 0.0, -2.0)
	await _wait_for_driver_update()
	if not _expect_float(4.5, test_material.get_shader_parameter(&"local_x"), "X scalar output"):
		return false
	if not _expect_float(1.0, test_material.get_shader_parameter(&"local_y"), "upper scalar clamp"):
		return false
	if not _expect_float(0.0, test_material.get_shader_parameter(&"local_z"), "lower scalar clamp"):
		return false
	return true


# Creates one driver with all inspector-like settings assigned before it enters the scene tree.
func _create_driver(parent_node: Node, target_shader_material: ShaderMaterial, parameter_name: StringName, component: PositionToShaderParam.PositionComponent, position_space: PositionToShaderParam.PositionSpace, clamp_output: bool) -> PositionToShaderParam:
	var driver: PositionToShaderParam = PositionToShaderParam.new()
	driver.target_material = target_shader_material
	driver.shader_parameter_name = parameter_name
	driver.position_component = component
	driver.position_space = position_space
	driver.clamp_scalar_output = clamp_output
	parent_node.add_child(driver)
	return driver


# Allows both the node's process callback and the rendering resource update to observe a full frame.
func _wait_for_driver_update() -> void:
	await process_frame
	await process_frame


# Confirms mesh-targeted updates duplicate the active surface material instead of changing a shared resource.
func _test_mesh_material_isolation(test_root: Node3D, source_material: ShaderMaterial) -> bool:
	var shared_material: ShaderMaterial = source_material.duplicate() as ShaderMaterial
	if shared_material == null:
		push_error("Failed to duplicate test material for mesh isolation")
		return false
	shared_material.set_shader_parameter(&"local_x", 0.0)
	var target_mesh: MeshInstance3D = MeshInstance3D.new()
	target_mesh.mesh = BoxMesh.new()
	target_mesh.material_override = shared_material
	test_root.add_child(target_mesh)

	var driver: PositionToShaderParam = PositionToShaderParam.new()
	driver.target_mesh = target_mesh
	driver.shader_parameter_name = &"local_x"
	driver.position_component = PositionToShaderParam.PositionComponent.X
	driver.position = Vector3(0.75, 0.0, 0.0)
	test_root.add_child(driver)
	await _wait_for_driver_update()

	var unique_material: ShaderMaterial = target_mesh.get_active_material(0) as ShaderMaterial
	if unique_material == null or unique_material == shared_material:
		push_error("Mesh target did not receive a unique ShaderMaterial")
		return false
	if not _expect_float(0.75, unique_material.get_shader_parameter(&"local_x"), "mesh target scalar output"):
		return false
	if not _expect_float(0.0, shared_material.get_shader_parameter(&"local_x"), "shared mesh material override remains unchanged"):
		return false

	var surface_shared_material: ShaderMaterial = source_material.duplicate() as ShaderMaterial
	if surface_shared_material == null:
		push_error("Failed to duplicate test material for surface isolation")
		return false
	surface_shared_material.set_shader_parameter(&"local_z", 0.0)
	var surface_mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.surface_set_material(0, surface_shared_material)
	surface_mesh.mesh = box_mesh
	test_root.add_child(surface_mesh)
	var surface_driver: PositionToShaderParam = PositionToShaderParam.new()
	surface_driver.target_mesh = surface_mesh
	surface_driver.shader_parameter_name = &"local_z"
	surface_driver.position_component = PositionToShaderParam.PositionComponent.Z
	surface_driver.position = Vector3(0.0, 0.0, 0.4)
	test_root.add_child(surface_driver)
	await _wait_for_driver_update()
	var unique_surface_material: ShaderMaterial = surface_mesh.get_active_material(0) as ShaderMaterial
	if unique_surface_material == null or unique_surface_material == surface_shared_material:
		push_error("Mesh surface did not receive a unique ShaderMaterial")
		return false
	if not _expect_float(0.4, unique_surface_material.get_shader_parameter(&"local_z"), "mesh surface target scalar output"):
		return false
	return _expect_float(0.0, surface_shared_material.get_shader_parameter(&"local_z"), "shared surface material remains unchanged")


# Ensures a missing uniform is reported once and never receives an unintended update.
func _test_invalid_configuration(test_root: Node3D, source_material: ShaderMaterial) -> bool:
	var invalid_material: ShaderMaterial = source_material.duplicate() as ShaderMaterial
	if invalid_material == null:
		push_error("Failed to duplicate test material for invalid configuration")
		return false
	invalid_material.set_shader_parameter(&"local_x", 0.6)
	var invalid_driver: PositionToShaderParam = PositionToShaderParam.new()
	invalid_driver.target_material = invalid_material
	invalid_driver.shader_parameter_name = &"missing_parameter"
	invalid_driver.position_component = PositionToShaderParam.PositionComponent.X
	invalid_driver.position = Vector3(9.0, 0.0, 0.0)
	test_root.add_child(invalid_driver)
	await _wait_for_driver_update()
	if invalid_driver._is_ready_for_updates:
		push_error("Invalid configuration continued processing")
		return false
	if not _expect_float(0.6, invalid_material.get_shader_parameter(&"local_x"), "invalid uniform leaves material unchanged"):
		return false

	var mismatched_driver: PositionToShaderParam = PositionToShaderParam.new()
	mismatched_driver.target_material = invalid_material
	mismatched_driver.shader_parameter_name = &"local_x"
	mismatched_driver.position_component = PositionToShaderParam.PositionComponent.VECTOR3
	mismatched_driver.position = Vector3(3.0, 4.0, 5.0)
	test_root.add_child(mismatched_driver)
	await _wait_for_driver_update()
	if mismatched_driver._is_ready_for_updates:
		push_error("Mismatched uniform type continued processing")
		return false
	return _expect_float(0.6, invalid_material.get_shader_parameter(&"local_x"), "mismatched type leaves material unchanged")


# Confirms the unused legacy wrapper still loads without the removed hands-specific root script.
func _test_legacy_hands_scene(test_root: Node3D) -> bool:
	var hands_scene: PackedScene = load(LEGACY_HANDS_SCENE_PATH)
	if hands_scene == null:
		push_error("Failed to load legacy hands.tscn")
		return false
	var hands: Node = hands_scene.instantiate()
	if hands == null:
		push_error("Failed to instantiate legacy hands.tscn")
		return false
	test_root.add_child(hands)
	if hands.get_script() != null:
		push_error("Legacy hands scene still has a root script")
		return false
	if hands.find_child("Hand_3D", true, false) == null:
		push_error("Legacy hands scene no longer contains its imported hand mesh")
		return false
	return true


# Confirms the hand bone's imported animation position drives the real hand material opacity through the generic script.
func _test_character_hand_animation(test_root: Node3D) -> bool:
	var character_scene: PackedScene = load(CHARACTER_SCENE_PATH)
	if character_scene == null:
		push_error("Failed to load character_main.tscn")
		return false
	var character: Node = character_scene.instantiate()
	if character == null:
		push_error("Failed to instantiate character_main.tscn")
		return false
	test_root.add_child(character)

	var hand_driver: PositionToShaderParam = character.find_child("_bone_attachement_hand_opacity", true, false) as PositionToShaderParam
	if hand_driver == null:
		push_error("Hand-opacity BoneAttachment3D has no PositionToShaderParam script")
		return false
	if hand_driver.target_material == null:
		push_error("Hand-opacity driver has no target ShaderMaterial")
		return false
	var hand_mesh: MeshInstance3D = character.find_child("shape_perspective_hands", true, false) as MeshInstance3D
	if hand_mesh == null:
		push_error("Perspective hand mesh is missing from character_main.tscn")
		return false
	if hand_mesh.get_active_material(0) != hand_driver.target_material:
		push_error("Hand-opacity driver does not target the perspective hand mesh material")
		return false
	if hand_driver.shader_parameter_name != &"opacity" or hand_driver.position_component != PositionToShaderParam.PositionComponent.Y or not hand_driver.clamp_scalar_output:
		push_error("Hand-opacity driver does not preserve the animated local-Y opacity mapping")
		return false

	for animation_tree_node: Node in character.find_children("*", "AnimationTree", true, false):
		var animation_tree: AnimationTree = animation_tree_node as AnimationTree
		animation_tree.active = false
	var animation_players: Array[Node] = character.find_children("*", "AnimationPlayer", true, false)
	if animation_players.is_empty():
		push_error("No AnimationPlayer found in character_main.tscn")
		return false
	var animation_player: AnimationPlayer = animation_players[0] as AnimationPlayer
	var pushing_animation: Animation = animation_player.get_animation(&"pushing")
	if pushing_animation == null:
		push_error("Imported pushing animation is unavailable")
		return false
	var opacity_track_index: int = _find_hand_opacity_track(pushing_animation)
	if opacity_track_index < 0 or pushing_animation.track_get_key_count(opacity_track_index) == 0:
		push_error("Pushing animation has no hand-opacity position track")
		return false
	var pushing_position: Vector3 = pushing_animation.track_get_key_value(opacity_track_index, 0)
	if not _expect_float(1.0, pushing_position.y, "pushing track sets hand opacity position to one"):
		return false

	animation_player.play(&"pushing")
	animation_player.seek(0.0, true)
	animation_player.advance(0.0)
	await _wait_for_driver_update()
	if not _expect_float(1.0, hand_driver.position.y, "bone attachment follows pushing position track"):
		return false
	if not _expect_float(1.0, hand_driver.target_material.get_shader_parameter(&"opacity"), "pushing animation drives hand shader opacity"):
		return false

	animation_player.play(&"idle")
	animation_player.seek(0.0, true)
	animation_player.advance(0.0)
	await _wait_for_driver_update()
	if not _expect_float(0.0, hand_driver.position.y, "idle track clears hand opacity position"):
		return false
	return _expect_float(0.0, hand_driver.target_material.get_shader_parameter(&"opacity"), "idle animation clears hand shader opacity")


# Locates the imported skeleton position track responsible for the opacity controller bone.
func _find_hand_opacity_track(animation: Animation) -> int:
	for track_index: int in range(animation.get_track_count()):
		if "_setting_hands_opacity" in str(animation.track_get_path(track_index)):
			return track_index
	return -1


# Reports numeric mismatches with context while keeping the main test runner responsible for the exit status.
func _expect_float(expected_value: float, actual_value: Variant, description: String) -> bool:
	if not actual_value is float:
		push_error(description + ": expected " + str(expected_value) + ", got " + str(actual_value))
		return false
	var actual_float: float = actual_value
	if not is_equal_approx(expected_value, actual_float):
		push_error(description + ": expected " + str(expected_value) + ", got " + str(actual_value))
		return false
	return true


# Reports vector mismatches without relying on a rendering comparison or visual test.
func _expect_vector3(expected_value: Vector3, actual_value: Variant, description: String) -> bool:
	if not actual_value is Vector3:
		push_error(description + ": expected " + str(expected_value) + ", got " + str(actual_value))
		return false
	var actual_vector: Vector3 = actual_value
	if not expected_value.is_equal_approx(actual_vector):
		push_error(description + ": expected " + str(expected_value) + ", got " + str(actual_value))
		return false
	return true