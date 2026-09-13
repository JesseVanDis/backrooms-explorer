extends Node3D


@onready var _node_moving_box_1: RigidBody3D = $MovingBox1
@onready var _node_moving_box_2: RigidBody3D = $MovingBox2
var _player: Player


func _ready() -> void:
	_player = Player.find_player(get_tree())


func _physics_process(_dt: float) -> void:
	if _player == null:
		return
	_update_player_speed()


func _update_player_speed() -> void:
	const DETECTION_DISTANCE: float = 2.0
	
	var is_near_box: bool = false
	
	if _player.global_position.distance_to(_node_moving_box_1.global_position) < DETECTION_DISTANCE:
		is_near_box = true
	elif _player.global_position.distance_to(_node_moving_box_2.global_position) < DETECTION_DISTANCE:
		is_near_box = true
		
	if is_near_box:
		_player.movement_state = Player.MovementState.PUSHING
	else:
		_player.movement_state = Player.MovementState.RUNNING
