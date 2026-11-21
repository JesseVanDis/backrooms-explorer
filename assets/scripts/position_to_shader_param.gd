## [AI-DOC] Copies this Node3D's local or global position into a selected ShaderMaterial parameter
## spec: docs/ai/systems/player.md
## status: implemented
## notes: supports Vector3 and X/Y/Z float output; mesh targets receive a unique surface material while direct material targets are shared explicitly

class_name PositionToShaderParam
extends Node3D

enum PositionComponent { VECTOR3, X, Y, Z }
enum PositionSpace { LOCAL, GLOBAL }

@export var target_mesh: MeshInstance3D = null
@export var target_material: ShaderMaterial = null
@export var target_surface_index: int = 0
@export var shader_parameter_name: StringName = &""
@export var position_component: PositionComponent = PositionComponent.VECTOR3
@export var position_space: PositionSpace = PositionSpace.LOCAL
@export var clamp_scalar_output: bool = false
@export var scalar_clamp_range: Vector2 = Vector2(0.0, 1.0)

var _resolved_material: ShaderMaterial = null
var _is_ready_for_updates: bool = false


# Resolves and validates the selected shader target once so configuration errors do not repeat every frame.
func _ready() -> void:
	if not _configure_target():
		set_process(false)
		return
	_is_ready_for_updates = true


# Keeps the shader parameter synchronized with the position this component is attached to.
func _process(_delta: float) -> void:
	if not _is_ready_for_updates:
		return
	if _resolved_material == null:
		_configuration_error("Resolved ShaderMaterial became null")
		return

	var source_position: Vector3 = position
	if position_space == PositionSpace.GLOBAL:
		source_position = global_position

	var parameter_value: Variant
	match position_component:
		PositionComponent.VECTOR3:
			parameter_value = source_position
		PositionComponent.X:
			parameter_value = _clamp_scalar(source_position.x)
		PositionComponent.Y:
			parameter_value = _clamp_scalar(source_position.y)
		PositionComponent.Z:
			parameter_value = _clamp_scalar(source_position.z)
		_:
			_configuration_error("Position component is not a supported value")
			return

	_resolved_material.set_shader_parameter(shader_parameter_name, parameter_value)


# Selects a unique mesh surface material or the explicitly shared ShaderMaterial and validates its uniform.
func _configure_target() -> bool:
	if position_space != PositionSpace.LOCAL and position_space != PositionSpace.GLOBAL:
		return _configuration_error("Position space is not a supported value")
	if position_component != PositionComponent.VECTOR3 and position_component != PositionComponent.X and position_component != PositionComponent.Y and position_component != PositionComponent.Z:
		return _configuration_error("Position component is not a supported value")
	if target_mesh != null and target_material != null:
		return _configuration_error("Set either target_mesh or target_material, not both")

	if target_material != null:
		_resolved_material = target_material
	else:
		if target_mesh == null:
			return _configuration_error("A target_mesh or target_material is required")
		if target_mesh.mesh == null:
			return _configuration_error("Target mesh has no Mesh resource")
		if target_surface_index < 0 or target_surface_index >= target_mesh.mesh.get_surface_count():
			return _configuration_error("Target surface index is outside the mesh surface range")

		var active_material: Material = target_mesh.get_active_material(target_surface_index)
		if active_material == null:
			return _configuration_error("Target mesh surface has no active material")
		var uses_mesh_material_override: bool = target_mesh.material_override != null
		_resolved_material = active_material as ShaderMaterial
		if _resolved_material == null:
			return _configuration_error("Target mesh surface material is not a ShaderMaterial")

		_resolved_material = _resolved_material.duplicate() as ShaderMaterial
		if _resolved_material == null:
			return _configuration_error("Failed to duplicate target mesh ShaderMaterial")
		if uses_mesh_material_override:
			target_mesh.material_override = _resolved_material
		else:
			target_mesh.set_surface_override_material(target_surface_index, _resolved_material)

	if _resolved_material.shader == null:
		return _configuration_error("Target ShaderMaterial has no Shader")
	if shader_parameter_name.is_empty():
		return _configuration_error("Shader parameter name cannot be empty")
	if position_component == PositionComponent.VECTOR3 and clamp_scalar_output:
		return _configuration_error("Scalar clamping cannot be enabled for Vector3 output")
	if clamp_scalar_output and scalar_clamp_range.x > scalar_clamp_range.y:
		return _configuration_error("Scalar clamp minimum cannot be greater than its maximum")

	var parameter_type: int = _find_shader_parameter_type()
	if parameter_type == TYPE_NIL:
		return _configuration_error("Shader parameter '" + String(shader_parameter_name) + "' does not exist")
	var expected_type: int = TYPE_VECTOR3 if position_component == PositionComponent.VECTOR3 else TYPE_FLOAT
	if parameter_type != expected_type:
		return _configuration_error("Shader parameter type does not match the selected position output")
	return true


# Finds the declared uniform type, including parameters that have no material override value yet.
func _find_shader_parameter_type() -> Variant:
	for uniform_info: Dictionary in _resolved_material.shader.get_shader_uniform_list():
		if uniform_info.get("name") == shader_parameter_name:
			return uniform_info.get("type", TYPE_NIL)
	return TYPE_NIL


# Applies the optional range only to scalar outputs, keeping vector uniforms untouched.
func _clamp_scalar(value: float) -> float:
	if not clamp_scalar_output:
		return value
	return clampf(value, scalar_clamp_range.x, scalar_clamp_range.y)


# Stops processing after reporting one invalid setup instead of emitting the same error every frame.
func _configuration_error(error_message: String) -> bool:
	push_error(error_message)
	_is_ready_for_updates = false
	set_process(false)
	return false
