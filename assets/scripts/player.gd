extends CharacterBody3D
class_name Player

const SPEED: float = 3.0
const JUMP_VELOCITY: float = 3.5
const FOOTSTEP_INTERVAL: float = 0.36
const BOB_VERTICAL_AMPLITUDE: float = 0.08
const BOB_HORIZONTAL_AMPLITUDE: float = 0.02
const MOVEMENT_LOWERING: float = 0.15
const HANDS_APPEAR_DURATION: float = 0.1

enum Wieldable {NONE, PUSH, LVL_0_HITGROUND}

@onready var _node_camera : Camera3D = null
@onready var _node_hands_yaw : Node3D = null
var push_target: Node3D = null

@export var max_fall_speed: float = 0.0
@export var initial_velocity: Vector3 = Vector3.ZERO
@export var initial_yaw: float = 0.0
@export var initial_pitch: float = 0.0

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

# Sounds
var _footstep_sounds: Array[AudioStream] = FOOTSTEP_SOUNDS
var _footstep_start_sound: AudioStream = FOOTSTEP_START_SOUND
var _jump_sounds: Array[AudioStream] = JUMP_SOUNDS
var _landing_sounds: Array[AudioStream] = LANDING_SOUNDS
var _footstep_timer: float = 0.0
var _audio_player: AudioStreamPlayer3D

var _wield: PlayerWield = PlayerWield.new(self)
var active_wieldable: Wieldable:
	get:        return _wield.active_wieldable as Wieldable
	set(value): _wield.active_wieldable = value

# Animations
var _camera_default_position: Vector3 = Vector3.ZERO
var _bob_phase: float = 0.0
var _is_moving: bool = false

func _ready() -> void:
	_node_camera = UtilsNode.find_camera_recursive(self)
	if _node_camera == null:
		push_error("_node_camera is null")
		return
		
	_node_hands_yaw = $_Hands/_hands
	if _node_hands_yaw == null:
		push_error("_node_hands is null")

	rotation.y = deg_to_rad(initial_yaw)
	_node_camera.rotation.x = deg_to_rad(initial_pitch)
	velocity = initial_velocity
	
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	_camera_default_position = _node_camera.position
	
	_wield.add_wieldable(Wieldable.NONE,             "")
	_wield.add_wieldable(Wieldable.PUSH,             "wield_push", true, false, {"movement_multiplier": 0.2})
	_wield.add_wieldable(Wieldable.LVL_0_HITGROUND,  "lvl_0_landing", false, true, {"max_look_freedom_degrees_v": 10.0, "max_look_freedom_degrees_h": 0.0, "movement_multiplier": 0.0})


func apply_footsteps(sounds: Array[AudioStream]) -> void:
	_footstep_sounds = sounds

func apply_footstep_start_sound(sound: AudioStream) -> void:
	_footstep_start_sound = sound

func apply_jump_sounds(sounds: Array[AudioStream]) -> void:
	_jump_sounds = sounds
	
func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	var was_in_air: bool = not is_on_floor()
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		if max_fall_speed > 0.0:
			velocity.y = max(velocity.y, -max_fall_speed)

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
	
	_wield.update(delta)
	_handle_hands_aim(delta)
	_handle_camera_limits(delta)
	_handle_head_bob(delta)
	_handle_footsteps(delta)

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

func _handle_camera_limits(dt: float) -> void:
	var adjustement_speed := 10.0 + _wield.seconds_since_equiping_start * 40.0
	var adjustement_step := minf(1.0, adjustement_speed * dt)
	var active_wieldable_data := _wield.active_wieldable_data
	
	var max_look_freedom_h: float = 360.0
	var max_look_freedom_v: float = 360.0
	if active_wieldable_data:
		max_look_freedom_h = active_wieldable_data.max_look_freedom_degrees_h
		max_look_freedom_v = active_wieldable_data.max_look_freedom_degrees_v
	
	var pitch_limit_deg := 90.0
	var yaw_limit_deg := 360.0
	if max_look_freedom_h < 360.0:
		yaw_limit_deg = max_look_freedom_h * 0.5
	if max_look_freedom_v < 360.0:
		pitch_limit_deg = max_look_freedom_v * 0.5
	
	var target_x := clampf(_node_camera.rotation.x, deg_to_rad(-pitch_limit_deg), deg_to_rad(pitch_limit_deg))
	if target_x != _node_camera.rotation.x:
		_node_camera.rotation.x = (_node_camera.rotation.x * (1.0 - adjustement_step)) + (target_x * adjustement_step)
	else:
		_node_camera.rotation.x = target_x
	
	if yaw_limit_deg < 360.0:
		var target_y := clampf(self.rotation.y, deg_to_rad(-yaw_limit_deg), deg_to_rad(yaw_limit_deg))
		if self.rotation.y != target_y:
			self.rotation.y = (self.rotation.y * (1.0 - adjustement_step)) + (target_y * adjustement_step)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var event_mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if event_mouse_motion:
			var motion_speed := 0.01
			var active_wieldable_data := _wield.active_wieldable_data
			var is_rotating_limited: bool = active_wieldable_data and (active_wieldable_data.max_look_freedom_degrees_h < 360.0 or active_wieldable_data.max_look_freedom_degrees_v < 360.0)
			if is_rotating_limited:
				motion_speed = 0.0005
			rotate_y(-event_mouse_motion.relative.x * motion_speed)
			_node_camera.rotate_x(-event_mouse_motion.relative.y * motion_speed)
			if not is_rotating_limited:
				_handle_camera_limits(9999.0)

func _get_movement_speed_multiplier() -> float:
	var active_wieldable_data := _wield.active_wieldable_data
	if active_wieldable_data:
		return active_wieldable_data.movement_multiplier
	return 1.0

func _get_animation_speed_multiplier() -> float:
	match active_wieldable:
		Wieldable.PUSH:
			return 0.7
		_:
			return 1.0

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
	
	_node_camera.position.y = lerp(_node_camera.position.y, _camera_default_position.y + lowering_offset + vertical_offset, delta * 15.0)
	_node_camera.position.x = lerp(_node_camera.position.x, _camera_default_position.x + horizontal_offset, delta * 15.0)

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
			_bob_phase = fmod(roundf(_bob_phase / PI) * PI, PI * 2.0)
	else:
		_is_moving = false
		_footstep_timer = 0.0

func _handle_hands_aim(dt: float) -> void:
	var target_yaw: float = 0.0
	if active_wieldable == Wieldable.PUSH and push_target != null:
		var direction_to_target: Vector3 = (push_target.global_position - global_position).normalized()
		var local_direction: Vector3 = (transform.basis.inverse() * direction_to_target).normalized()
		target_yaw = atan2(-local_direction.x, -local_direction.z)
	
	_node_hands_yaw.rotation.y = lerp_angle(_node_hands_yaw.rotation.y, target_yaw, minf(1.0, dt * 30.0))
