extends Node3D


@onready var _node_moving_box_1: RigidBody3D = $MovingBox1
@onready var _node_moving_box_2: RigidBody3D = $MovingBox2
@onready var _node_world_environment: WorldEnvironment = $WorldEnvironment
var _player: Player


func _ready() -> void:
	_player = UtilsNode.find_player(get_tree())
	if _player == null:
		push_error("Player not found in scene tree")


func _physics_process(_dt: float) -> void:
	_update_player_speed()
	_update_environment_effects()


func _update_environment_effects() -> void:
	if _player == null:
		return
	
	if _node_world_environment.environment == null:
		push_error("WorldEnvironment environment is null")
		return
	
	# When falling trough the tunnel towards lvl_0 of the backrooms
	const Y_START: float = -10.0
	const Y_END: float = -230.0
	const FOG_DENSITY_START: float = 0.0
	const FOG_DENSITY_END: float = 0.1
	const SKY_AFFECT_START: float = 0.0
	const SKY_AFFECT_END: float = 1.0
	
	var t: float = clampf(remap(_player.global_position.y, Y_START, Y_END, 0.0, 1.0), 0.0, 1.0)
	_node_world_environment.environment.fog_density = lerpf(FOG_DENSITY_START, FOG_DENSITY_END, t)
	_node_world_environment.environment.fog_sky_affect = lerpf(SKY_AFFECT_START, SKY_AFFECT_END, t)


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
