extends Node3D


@onready var _node_moving_box_1: RigidBody3D = $MovingBox1
@onready var _node_moving_box_2: RigidBody3D = $MovingBox2
@onready var _node_world_environment: WorldEnvironment = $WorldEnvironment
var _player: Player
const LVL_0_PATH: String = "res://scenes/lvl_0/lvl_0.tscn"
var _loading_lvl_0_state: int = 1
var _lvl_0: Node = null
var _loading_screen: Node = null
var _fade_in_complete: bool = false


func _ready() -> void:
	_player = UtilsNode.find_player(get_tree())
	if _player == null:
		push_error("Player not found in scene tree")


func _physics_process(_dt: float) -> void:
	_update_player_speed()
	_update_environment_effects()
	_handle_loading_lvl_0()
	_handle_level_transition()

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
		return
	
	if _node_world_environment.environment == null:
		push_error("WorldEnvironment environment is null")
		return
		
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
	else:
		_player.wieldable = Player.Wieldable.NONE


func _handle_loading_lvl_0() -> void:
	match _loading_lvl_0_state:
		1:
			var err: Error = ResourceLoader.load_threaded_request(LVL_0_PATH)
			if err != OK:
				push_error("Failed to start asynchronous loading of lvl_0: " + str(err))
				return
			_loading_lvl_0_state = 2
			
		2:
			var progress: Array[float] = []
			var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(LVL_0_PATH, progress)
			
			match status:
				ResourceLoader.THREAD_LOAD_LOADED:
					var packed_scene: PackedScene = ResourceLoader.load_threaded_get(LVL_0_PATH) as PackedScene
					if packed_scene == null:
						push_error("Loaded resource is not a PackedScene")
						return
					_lvl_0 = packed_scene.instantiate()
					print("Initializing lvl_0...")
					_lvl_0.initialize_async()
					_loading_lvl_0_state = 3

				ResourceLoader.THREAD_LOAD_FAILED:
					push_error("Failed to load lvl_0 asynchronously")
					_loading_lvl_0_state = 1 # Allow retry if possible, or just log error
				ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
					push_error("Invalid resource path for lvl_0")
					_loading_lvl_0_state = 1
		3:
			if _lvl_0.initialized():
				print("Initializing lvl_0... done")
				_loading_lvl_0_state = 4
				

func _handle_level_transition() -> void:
	if _player == null:
		return
	
	if _player.global_position.y < OPEN_LVL_0_TRIGGER_Y:
		if _loading_screen == null:
			_loading_screen = UtilsScreen.fade_in_screen(get_tree(), "res://scenes/frontroom_0/transition_frontrooms_lvl_0.tscn", func() -> void: _fade_in_complete = true)
		if _loading_lvl_0_state == 0:
			_loading_lvl_0_state = 1
		if _loading_lvl_0_state == 4 and _fade_in_complete:
			print("Switching to lvl_0")
			get_tree().current_scene.queue_free()
			# Note: _loading_screen is already a child of root, so it stays when current_scene is freed
			get_tree().root.add_child(_lvl_0)
			get_tree().current_scene = _lvl_0
