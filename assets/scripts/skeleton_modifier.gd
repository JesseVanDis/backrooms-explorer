@tool
class_name SkeletonModifier
extends SkeletonModifier3D

@export var bone_name: StringName = "CC_Base_Spine01"
@export var extra_rotation_degrees := Vector3.ZERO

var bone_index := -1

func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()

	if skeleton == null:
		return

	if bone_index == -1:
		bone_index = skeleton.find_bone(bone_name)

	if bone_index == -1:
		push_error("bone '" + bone_name + "' not found. cannot twist")
		return

	var animated_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index)

	var manual_rotation: Quaternion = Quaternion.from_euler(
		Vector3(
			deg_to_rad(extra_rotation_degrees.x),
			deg_to_rad(extra_rotation_degrees.y),
			deg_to_rad(extra_rotation_degrees.z)
		)
	)

	skeleton.set_bone_pose_rotation(
		bone_index,
		animated_rotation * manual_rotation
	)
