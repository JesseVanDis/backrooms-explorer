extends MeshInstance3D

const OPEN_ANGLE: float = PI / 2.0
const CLOSE_ANGLE: float = 0.0
const DOOR_SPEED: float = 5.0
const DETECTION_RANGE: float = 1.5
const OPENING_SIDE_DETECTION_RANGE: float = 2.5

@export var open_clockwise: bool = true
@export var detection_distance: float = DETECTION_RANGE
@export var opening_side_detection_distance: float = OPENING_SIDE_DETECTION_RANGE
@export var mesh_rotation_degrees: float = 0.0

var _player: Player = null
var _initial_rotation_y: float = 0.0
var _target_angle: float = CLOSE_ANGLE

func _ready() -> void:
	_initial_rotation_y = rotation.y
	_target_angle = _initial_rotation_y
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
	else:
		_target_angle = _initial_rotation_y
	
	rotation.y = lerp_angle(rotation.y, _target_angle, delta * DOOR_SPEED)

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
