extends MeshInstance3D

enum DoorState {
	CLOSED,
	OPENING,
	OPEN,
	CLOSING
}

const OPEN_ANGLE: float = PI / 2.0
const CLOSE_ANGLE: float = 0.0
const DOOR_SPEED: float = 5.0
const DETECTION_RANGE: float = 1.5
const OPENING_SIDE_DETECTION_RANGE: float = 2.5

@export var open_clockwise: bool = true
@export var detection_distance: float = DETECTION_RANGE
@export var opening_side_detection_distance: float = OPENING_SIDE_DETECTION_RANGE
@export var mesh_rotation_degrees: float = 0.0
@export var sound_open: AudioStream = load("res://assets/sounds/door_open_1.wav")
@export var sound_close: AudioStream = load("res://assets/sounds/door_close_1.wav")

var _player: Player = null
var _initial_rotation_y: float = 0.0
var _target_angle: float = CLOSE_ANGLE
var _state: DoorState = DoorState.CLOSED
var _audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	_initial_rotation_y = rotation.y
	_target_angle = _initial_rotation_y
	_state = DoorState.CLOSED
	
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	
	get_player()

func get_player() -> Player:
	if not _player:
		_player = UtilsNode.find_player(get_tree())
	return _player

func _process(delta: float) -> void:
	var player: Player = get_player()
	if not player:
		return

	var distance: float = global_position.distance_to(player.global_position)
	var current_detection_range: float = _get_detection_distance(player)
	
	if distance < current_detection_range:
		var offset: float = -OPEN_ANGLE if open_clockwise else OPEN_ANGLE
		_target_angle = _initial_rotation_y + offset
		
		if _state == DoorState.CLOSED or _state == DoorState.CLOSING:
			_state = DoorState.OPENING
			_play_sound(sound_open)
	else:
		_target_angle = _initial_rotation_y
		
		if _state == DoorState.OPEN or _state == DoorState.OPENING:
			_state = DoorState.CLOSING
	
	rotation.y = lerp_angle(rotation.y, _target_angle, delta * DOOR_SPEED)
	
	# Check if we reached the target
	if abs(angle_difference(rotation.y, _target_angle)) < 0.01:
		if _state == DoorState.OPENING:
			_state = DoorState.OPEN
		elif _state == DoorState.CLOSING:
			_state = DoorState.CLOSED
			_play_sound(sound_close)

func _play_sound(stream: AudioStream) -> void:
	if not stream:
		return
	
	if not _audio_player:
		push_error("AudioStreamPlayer3D is null in door.gd")
		return
		
	_audio_player.stream = stream
	_audio_player.play()

func _get_detection_distance(player: Player) -> float:
	# Determine if the player is on the side the door opens towards.
	# We use 2D normals and dot product to determine which side of the door the player is on.
	var door_normal: Vector2 = Vector2(0, 1).rotated((-_initial_rotation_y) - rad_to_deg(mesh_rotation_degrees))
	var dir_to_player_3d: Vector3 = player.global_position - global_position
	var dir_to_player_2d: Vector2 = Vector2(dir_to_player_3d.x, dir_to_player_3d.z).normalized()
	
	var dot: float = door_normal.dot(dir_to_player_2d)
	var is_on_opening_side: bool = dot > 0.0
	
	# If the door opens clockwise, the 'opening side' is inverted.
	if open_clockwise:
		is_on_opening_side = dot < 0.0
	
	if is_on_opening_side:
		return opening_side_detection_distance
	
	return detection_distance
