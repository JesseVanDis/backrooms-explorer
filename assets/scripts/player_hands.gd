extends Node3D
class_name PlayerHands

var _node_opacity_controller: Node3D = null
var _hand_material: ShaderMaterial = null

func _ready() -> void:
		
	_node_opacity_controller = find_child("_setting_opacity", true, false)
	if _node_opacity_controller == null:
		push_error("_node_opacity_controller is null")
		
	var hand_3d: MeshInstance3D = find_child("Hand_3D", true, false)
	if hand_3d:
		_hand_material = hand_3d.get_surface_override_material(0)
		if _hand_material == null:
			push_error("_hand_material is null")
	else:
		push_error("Hand_3D not found")

func _process(_delta: float) -> void:
	if _node_opacity_controller and _hand_material:
		var opacity: float = clampf(_node_opacity_controller.transform.origin.y, 0.0, 1.0)
		print("opacity: " + str(opacity))
		_hand_material.set_shader_parameter("opacity", opacity)
