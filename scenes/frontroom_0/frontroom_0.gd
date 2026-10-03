extends Node3D


@onready var _node_moving_box_1: RigidBody3D = $MovingBox1
@onready var _node_moving_box_2: RigidBody3D = $MovingBox2
@onready var _node_moving_box_3: RigidBody3D = $MovingBox_kitchen_big
@onready var _node_moving_box_4: RigidBody3D = $MovingBox_kitchen_big2
@onready var _node_world_environment: WorldEnvironment = $WorldEnvironment
var _player: Player
var _level_transition: LevelTransition
const LVL_0_PATH: String = "res://scenes/lvl_0/lvl_0.tscn"
const MENU_INTRO_PATH: String = "res://scenes/menu_intro/menu_intro.tscn"


func _ready() -> void:
	_player = UtilsNode.find_player(get_tree())
	if _player == null:
		push_error("Player not found in scene tree")
	else:
		_player.control_enabled = false
	
	_level_transition = LevelTransition.new(get_tree())
	_level_transition.preload_level(LVL_0_PATH)
	
	await _show_intro()

func _show_intro() -> void:
	const INTRO_WAIT_TIME: float = 0.0
	const FADE_OUT_DURATION: float = 2.0
	
	var intro_scene: PackedScene = load(MENU_INTRO_PATH)
	if intro_scene == null:
		push_error("Failed to load intro scene: " + MENU_INTRO_PATH)
		if _player != null:
			_player.control_enabled = true
		return
		
	var intro_node: Node = intro_scene.instantiate()
	if intro_node == null:
		push_error("Failed to instantiate intro scene")
		if _player != null:
			_player.control_enabled = true
		return
	
	get_tree().root.add_child.call_deferred(intro_node)
	
	await get_tree().create_timer(INTRO_WAIT_TIME).timeout
	
	if _player != null:
		_player.control_enabled = true
	
	UtilsScreen.fade_out(intro_node, FADE_OUT_DURATION, intro_node.queue_free)

func _physics_process(_dt: float) -> void:
	_update_player_speed()
	_update_environment_effects()
	_handle_level_transition()
	await _level_transition.update()

# When falling trough the tunnel towards lvl_0 of the backrooms
const Y_START: float = -5.0
const Y_END: float = -10.0
const FOG_DENSITY_START: float = 0.0
const FOG_DENSITY_END: float = 0.1
const SKY_AFFECT_START: float = 0.0
const SKY_AFFECT_END: float = 1.0
const OPEN_LVL_0_TRIGGER_Y: float = -15.0

func _update_environment_effects() -> void:
	if _player == null:
		push_error("Player is null")
		return
	
	if _node_world_environment.environment == null:
		push_error("WorldEnvironment environment is null")
		return
		
	var t: float = clampf(remap(_player.global_position.y, Y_START, Y_END, 0.0, 1.0), 0.0, 1.0)
	_node_world_environment.environment.fog_density = lerpf(FOG_DENSITY_START, FOG_DENSITY_END, t)
	_node_world_environment.environment.fog_sky_affect = lerpf(SKY_AFFECT_START, SKY_AFFECT_END, t)


func _update_player_speed() -> void:
	const DETECTION_DISTANCE: float = 1.0
	
	var push_node: Node3D = null
	
	if _player.global_position.distance_to(_node_moving_box_1.global_position) < DETECTION_DISTANCE:
		push_node = _node_moving_box_1
	elif _player.global_position.distance_to(_node_moving_box_2.global_position) < DETECTION_DISTANCE:
		push_node = _node_moving_box_2
	elif _player.global_position.distance_to(_node_moving_box_3.global_position) < DETECTION_DISTANCE:
		push_node = _node_moving_box_3
	elif _player.global_position.distance_to(_node_moving_box_4.global_position) < DETECTION_DISTANCE:
		push_node = _node_moving_box_4

	if push_node != null:
		_player.active_wieldable = "wield_push"
		_player.wield_target = push_node
	else:
		_player.active_wieldable = ""
		_player.wield_target = null


func _handle_level_transition() -> void:
	if _player == null:
		return
	
	if _player.global_position.y < OPEN_LVL_0_TRIGGER_Y:
		_level_transition.switch_to_level(LVL_0_PATH)
