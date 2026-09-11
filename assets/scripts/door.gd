extends MeshInstance3D

const OPEN_ANGLE: float = PI / 2.0
const CLOSE_ANGLE: float = 0.0
const DOOR_SPEED: float = 5.0
const DETECTION_RANGE: float = 2.0

@export var open_clockwise: bool = true
@export var detection_distance: float = DETECTION_RANGE

var _player: Player = null
var _initial_rotation_y: float = 0.0
var _target_angle: float = CLOSE_ANGLE

func _ready() -> void:
	_initial_rotation_y = rotation.y
	_target_angle = _initial_rotation_y
	get_player()

func get_player() -> Player:
	if not _player:
		_player = Player.find_player(get_tree())
	return _player

func _process(delta: float) -> void:
	var player: Player = get_player()
	if not player:
		return

	var distance: float = global_position.distance_to(player.global_position)
	
	if distance < detection_distance:
		var offset: float = -OPEN_ANGLE if open_clockwise else OPEN_ANGLE
		_target_angle = _initial_rotation_y + offset
	else:
		_target_angle = _initial_rotation_y
	
	rotation.y = lerp_angle(rotation.y, _target_angle, delta * DOOR_SPEED)
