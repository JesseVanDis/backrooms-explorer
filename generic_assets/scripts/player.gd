extends CharacterBody3D
class_name Player


const SPEED: float = 3.0
const JUMP_VELOCITY: float = 3.5
const FOOTSTEP_INTERVAL: float = 0.36
const BOB_VERTICAL_AMPLITUDE: float = 0.08
const BOB_HORIZONTAL_AMPLITUDE: float = 0.02
const MOVEMENT_LOWERING: float = 0.15

@onready var camera_node : Node3D = $Neck/Camera3D

var _footstep_sounds: Array[AudioStream] = []
var _jump_sounds: Array[AudioStream] = []
var _landing_sounds: Array[AudioStream] = []
var _footstep_timer: float = 0.0
var _audio_player: AudioStreamPlayer3D
var _default_camera_y: float = 0.0
var _default_camera_x: float = 0.0
var _bob_phase: float = 0.0

func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	_default_camera_y = camera_node.position.y
	_default_camera_x = camera_node.position.x

func apply_footsteps(sounds: Array[AudioStream]) -> void:
	_footstep_sounds = sounds

func apply_jump_sounds(sounds: Array[AudioStream]) -> void:
	_jump_sounds = sounds

func apply_landing_sounds(sounds: Array[AudioStream]) -> void:
	_landing_sounds = sounds

func _play_footstep() -> void:
	if _footstep_sounds.is_empty():
		return
	_audio_player.stream = _footstep_sounds.pick_random()
	_audio_player.pitch_scale = randf_range(0.9, 1.3)
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
	_audio_player.volume_db = 10.0;
	_audio_player.play()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * 0.01)
			camera_node.rotate_x(-event.relative.y * 0.01)
			camera_node.rotation.x = clamp(camera_node.rotation.x, deg_to_rad(-90), deg_to_rad(90))

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
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
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
	
	if is_on_floor() and velocity.length() > 0.1:
		_bob_phase += delta * (PI / FOOTSTEP_INTERVAL)
		_bob_phase = fmod(_bob_phase, PI * 2.0)
		vertical_offset = BOB_VERTICAL_AMPLITUDE * abs(sin(_bob_phase))
		horizontal_offset = BOB_HORIZONTAL_AMPLITUDE * sin(_bob_phase)
		lowering_offset = -MOVEMENT_LOWERING
	
	camera_node.position.y = lerp(camera_node.position.y, _default_camera_y + lowering_offset + vertical_offset, delta * 15.0)
	camera_node.position.x = lerp(camera_node.position.x, _default_camera_x + horizontal_offset, delta * 15.0)

func _handle_footsteps(delta: float) -> void:
	if is_on_floor() and velocity.length() > 0.1:
		_footstep_timer += delta
		if _footstep_timer >= FOOTSTEP_INTERVAL:
			_play_footstep()
			_footstep_timer = 0.0
			_bob_phase = fmod(round(_bob_phase / PI) * PI, PI * 2.0)
	else:
		_footstep_timer = FOOTSTEP_INTERVAL # Play footstep immediately when starting to move
