extends CharacterBody3D
class_name Player


enum MovementState {
	RUNNING,
	PUSHING
}

const SPEED: float = 3.0
const JUMP_VELOCITY: float = 3.5
const FOOTSTEP_INTERVAL: float = 0.36
const BOB_VERTICAL_AMPLITUDE: float = 0.08
const BOB_HORIZONTAL_AMPLITUDE: float = 0.02
const MOVEMENT_LOWERING: float = 0.15
const HANDS_APPEAR_DURATION: float = 0.5

@onready var _node_camera : Node3D = $_Neck/Camera3D
@onready var _node_hands : Node3D = $_Hands
@onready var _node_hands_center : Node3D = $_HandsAppearStartingPos
@onready var _node_animation_player : AnimationPlayer = $_Hands/AnimationPlayer

const FOOTSTEP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/footstep_1.wav"),
	preload("res://assets/sounds/footstep_2.wav"),
	preload("res://assets/sounds/footstep_3.wav"),
	preload("res://assets/sounds/footstep_4.wav"),
	preload("res://assets/sounds/footstep_5.wav")
]
const FOOTSTEP_START_SOUND: AudioStream = preload("res://assets/sounds/footstep_start.wav")
const JUMP_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/jump_start_1.wav")
]
const LANDING_SOUNDS: Array[AudioStream] = [
	preload("res://assets/sounds/jump_end_1.wav"),
	preload("res://assets/sounds/jump_end_2.wav")
]

var movement_state: MovementState = MovementState.RUNNING:
	set(value):
		if movement_state != value:
			movement_state = value
			_on_movement_state_changed()

# Sounds
var _footstep_sounds: Array[AudioStream] = FOOTSTEP_SOUNDS
var _footstep_start_sound: AudioStream = FOOTSTEP_START_SOUND
var _jump_sounds: Array[AudioStream] = JUMP_SOUNDS
var _landing_sounds: Array[AudioStream] = LANDING_SOUNDS
var _footstep_timer: float = 0.0
var _audio_player: AudioStreamPlayer3D

# Animations
var _default_camera_y: float = 0.0
var _default_camera_x: float = 0.0
var _bob_phase: float = 0.0
var _is_moving: bool = false
var _hands_tween: Tween
var _hands_default_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	_default_camera_y = _node_camera.position.y
	_default_camera_x = _node_camera.position.x
	_hands_default_position = _node_hands.position

static func find_player(tree: SceneTree) -> Player:
	# Try to find the player in the scene tree via group
	var player: Player = tree.get_first_node_in_group("player")
	if player:
		return player
	
	# Fallback: search by class if group is not set
	var players: Array[Node] = tree.get_nodes_in_group("player")
	if not players.is_empty():
		return players[0] as Player
		
	# Last resort: deep search
	for node in tree.get_root().find_children("*", "CharacterBody3D", true, false):
		if node is Player:
			return node as Player
			
	return null

func apply_footsteps(sounds: Array[AudioStream]) -> void:
	_footstep_sounds = sounds

func apply_footstep_start_sound(sound: AudioStream) -> void:
	_footstep_start_sound = sound

func apply_jump_sounds(sounds: Array[AudioStream]) -> void:
	_jump_sounds = sounds

func _on_movement_state_changed() -> void:
	if _node_hands == null or _node_animation_player == null:
		return
		
	var anim_list: PackedStringArray = _node_animation_player.get_animation_list()
	if anim_list.is_empty():
		return
	var ANIM_NAME: String = anim_list[0]
	const FPS: float = 30.0
	const FRAME_10_TIME: float = 10.0 / FPS
	
	if _hands_tween:
		_hands_tween.kill()
	_hands_tween = null
	
	if movement_state == MovementState.PUSHING:
		_node_hands.visible = true
		_hands_tween = create_tween()
		_hands_tween.set_parallel(true)
		_hands_tween.tween_property(_node_hands, "position", _hands_default_position, HANDS_APPEAR_DURATION).from(_node_hands_center.position)
		_hands_tween.tween_property(_get_hands_material(), "shader_parameter/opacity", 1.0, HANDS_APPEAR_DURATION).from(0.0)
		_node_animation_player.play(ANIM_NAME)
		_node_animation_player.seek(0.0, true)
	else:
		_hands_tween = create_tween()
		_hands_tween.set_parallel(true)
		_hands_tween.tween_property(_node_hands, "position", _node_hands_center.position, HANDS_APPEAR_DURATION)
		_hands_tween.tween_property(_get_hands_material(), "shader_parameter/opacity", 0.0, HANDS_APPEAR_DURATION)
		_hands_tween.set_parallel(false)
		_hands_tween.tween_callback(func(): _node_hands.visible = false)
		_node_animation_player.play(ANIM_NAME, -1, -1.0, true)
		_node_animation_player.seek(FRAME_10_TIME, true)

func _get_hands_material() -> ShaderMaterial:
	var hand_mesh: MeshInstance3D = UtilsMesh.find_mesh_recursive(_node_hands)
	return hand_mesh.get_surface_override_material(0) as ShaderMaterial

func _process(_delta: float) -> void:
	if _node_animation_player == null or not _node_animation_player.is_playing():
		return
		
	var current_anim: String = _node_animation_player.current_animation
	if current_anim == "":
		return
		
	const FPS: float = 30.0
	const FRAME_10_TIME: float = 10.0 / FPS
	var CURRENT_TIME: float = _node_animation_player.current_animation_position
	
	if movement_state == MovementState.PUSHING:
		if CURRENT_TIME >= FRAME_10_TIME:
			_node_animation_player.pause()
			_node_animation_player.seek(FRAME_10_TIME, true)
	else:
		if CURRENT_TIME <= 0.0:
			_node_animation_player.stop()
			_node_hands.visible = false

func _play_footstep() -> void:
	if _footstep_sounds.is_empty():
		return
	_audio_player.stream = _footstep_sounds.pick_random()
	_audio_player.pitch_scale = randf_range(0.9, 1.3)
	_audio_player.volume_db = -20.0;
	_audio_player.play()

func _play_footstep_start_sound() -> void:
	if _footstep_start_sound == null:
		_play_footstep()
		return
	_audio_player.stream = _footstep_start_sound
	_audio_player.pitch_scale = randf_range(0.9, 1.3)
	_audio_player.volume_db = -20.0;
	_audio_player.play()

func _play_jump_sound() -> void:
	if _jump_sounds.is_empty():
		return
	_audio_player.stream = _jump_sounds.pick_random()
	_audio_player.pitch_scale = randf_range(0.9, 1.0)
	_audio_player.play()

func _play_landing_sound() -> void:
	if _landing_sounds.is_empty():
		return
	_audio_player.stream = _landing_sounds.pick_random()
	# Pitch variation for landing sounds
	_audio_player.pitch_scale = randf_range(0.8, 1.1)
	# _audio_player.volume_db = 10.0;
	_audio_player.play()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * 0.01)
			_node_camera.rotate_x(-event.relative.y * 0.01)
			_node_camera.rotation.x = clamp(_node_camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _get_movement_speed_multiplier() -> float:
	match movement_state:
		MovementState.PUSHING:
			return 0.2
		_:
			return 1.0

func _get_animation_speed_multiplier() -> float:
	match movement_state:
		MovementState.PUSHING:
			return 0.7
		_:
			return 1.0

func _physics_process(delta: float) -> void:
	var was_in_air: bool = not is_on_floor()
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_play_jump_sound()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED * _get_movement_speed_multiplier()
		velocity.z = direction.z * SPEED * _get_movement_speed_multiplier()
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	if was_in_air and is_on_floor():
		_play_landing_sound()
	
	_handle_head_bob(delta)
	_handle_footsteps(delta)

func _handle_head_bob(delta: float) -> void:
	var vertical_offset: float = 0.0
	var horizontal_offset: float = 0.0
	var lowering_offset: float = 0.0
	
	var multiplier: float = _get_animation_speed_multiplier()
	
	if is_on_floor() and velocity.length() > 0.1:
		_bob_phase += delta * (PI / FOOTSTEP_INTERVAL) * multiplier
		_bob_phase = fmod(_bob_phase, PI * 2.0)
		vertical_offset = BOB_VERTICAL_AMPLITUDE * abs(sin(_bob_phase)) * multiplier
		horizontal_offset = BOB_HORIZONTAL_AMPLITUDE * sin(_bob_phase) * multiplier
		lowering_offset = -MOVEMENT_LOWERING
	
	_node_camera.position.y = lerp(_node_camera.position.y, _default_camera_y + lowering_offset + vertical_offset, delta * 15.0)
	_node_camera.position.x = lerp(_node_camera.position.x, _default_camera_x + horizontal_offset, delta * 15.0)

func _handle_footsteps(delta: float) -> void:
	if is_on_floor() and velocity.length() > 0.1:
		if not _is_moving:
			_is_moving = true
			_play_footstep_start_sound()
			_footstep_timer = 0.0
			_bob_phase = 0.0
			return

		_footstep_timer += delta
		if _footstep_timer >= (FOOTSTEP_INTERVAL / _get_animation_speed_multiplier()):
			_play_footstep()
			_footstep_timer = 0.0
			_bob_phase = fmod(round(_bob_phase / PI) * PI, PI * 2.0)
	else:
		_is_moving = false
		_footstep_timer = 0.0
