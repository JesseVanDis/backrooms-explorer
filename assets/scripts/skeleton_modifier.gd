@tool
class_name SkeletonModifier
extends SkeletonModifier3D

@export var bone_names: Array[StringName] = []
@export var bone_weights: Array[float] = []

@export var extra_rotation_degrees := Vector3.ZERO

var _bone_indices: Array[int] = []
var _bone_weights: Array[float] = []

#var bone_index := -1

func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()

	if skeleton == null:
		return

	if bone_names.size() != _bone_indices.size():
		_bone_indices = []
		_bone_weights = []
		for index in range(0, bone_names.size()):
			var bone_name: StringName = bone_names[index]
			var bone_index: int = skeleton.find_bone(bone_name)
			if bone_index == -1:
				push_error("bone '" + bone_name + "' not found.")
				continue
			_bone_indices.append(bone_index)
			if bone_weights.size() <= index:
				_bone_weights.append(1.0)
			
	
	var total_weight: float = 0
	for v in _bone_weights:
		total_weight = total_weight + v
	
	if total_weight <= 0.0:
		total_weight = 1.0
	
	for index in range(0, _bone_indices.size()):
		var bone_index: int = _bone_indices[index]
		var weight: float = _bone_weights[index]
		var perc: float = min(1.0, weight / total_weight)
		
		var animated_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index)

		var manual_rotation: Quaternion = Quaternion.from_euler(
			Vector3(
				deg_to_rad(extra_rotation_degrees.x * perc),
				deg_to_rad(extra_rotation_degrees.y * perc),
				deg_to_rad(extra_rotation_degrees.z * perc)
			)
		)

		skeleton.set_bone_pose_rotation(
			bone_index,
			animated_rotation * manual_rotation
		)
		
