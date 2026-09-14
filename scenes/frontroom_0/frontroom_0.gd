extends Node3D


@onready var _node_moving_box_1: RigidBody3D = $MovingBox1
@onready var _node_moving_box_2: RigidBody3D = $MovingBox2
var _player: Player


func _ready() -> void:
	_player = UtilsNode.find_player(get_tree())
	if _player == null:
		push_error("Player not found in scene tree")


func _physics_process(_dt: float) -> void:
	_update_player_speed()


func _update_player_speed() -> void:
	const DETECTION_DISTANCE: float = 0.8
	
	var push_node: Node3D = null
	
	if _player.global_position.distance_to(_node_moving_box_1.global_position) < DETECTION_DISTANCE:
		push_node = _node_moving_box_1
	elif _player.global_position.distance_to(_node_moving_box_2.global_position) < DETECTION_DISTANCE:
		push_node = _node_moving_box_2
		
	if push_node != null:
		_player.wieldable = Player.Wieldable.PUSH
		_player.wield_aim_target = push_node
	else:
		_player.wieldable = Player.Wieldable.NONE
		_player.wield_aim_target = null
