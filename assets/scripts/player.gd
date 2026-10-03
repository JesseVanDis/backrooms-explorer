extends CharacterBody3D
class_name Player

const JUMP_VELOCITY: float = 3.5
var FOOTSTEP_INTERVAL: SpeedScale = SpeedScale.new(0.8, 0.36)
var BOB_VERTICAL_AMPLITUDE: SpeedScale = SpeedScale.new(0.02, 0.08)
var BOB_HORIZONTAL_AMPLITUDE: SpeedScale = SpeedScale.new(0.005, 0.02)
var MOVEMENT_LOWERING: SpeedScale = SpeedScale.new(0.02, 0.15)
var HANDS_APPEAR_DURATION: float = 0.1
var PUSH_FORCE: float = 0.5

class SpeedScale:
	var at_speed_1: float
	var at_speed_3: float
	
	func _init(a_at_speed_1: float, a_at_speed_3: float) -> void:
		at_speed_1 = a_at_speed_1
		at_speed_3 = a_at_speed_3
	
	func at(speed: float) -> float:
		var speed_perc: float = (speed - 1.0) / (3.0 - 1.0)
		return at_speed_1 + speed_perc * (at_speed_3 - at_speed_1)

@export var max_speed: float = 3.0
@export var max_fall_speed: float = 0.0
@export var initial_velocity: Vector3 = Vector3.ZERO
@export var initial_yaw: float = 0.0
@export var initial_pitch: float = 0.0

@export var active_voice_sequence: Array[AudioStream] = []:
	set(value):
		active_voice_sequence = value
		_on_active_voice_sequence_changed()
@onready var _audio_player_voice: AudioStreamPlayer3D = $_RaytracedAudioPlayer3D_Voice
@onready var _node_camera : Camera3D = null
@onready var _node_hands_yaw : Node3D = null
@onready var _node_subtitles : PlayerSubtitles = $_UI/_Subtitles
@onready var _audio_player: AudioStreamPlayer3D = $_RaytracedAudioPlayer3D

var _remaining_voice_sequence: Array[AudioStream] = []
var wield_target: Node3D = null


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
var _old_global_pos: Vector3 = Vector3(0,0,0)

#RaytracedAudioPlayer3D_Footsteps

var _wield: PlayerWield = PlayerWield.new(self)
var control_enabled: bool = true
var active_wieldable: String:
	get:        return _wield.active_wieldable
	set(value): _wield.active_wieldable = value

# Animations
var _camera_default_position: Vector3 = Vector3.ZERO
var _bob_phase: float = 0.0
var _is_moving: bool = false

var forward_2d: Vector2:
	get(): return UtilsMath.xz_normal(-transform.basis.z)

var moving_direction_2d: Vector2:
	get(): return UtilsMath.xz_normal(global_position - _old_global_pos)


func _ready() -> void:
	UtilsScreen.fade_out_screen(get_tree())
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
	_camera_default_position = _node_camera.position
	
	_wield.add_wieldable("")
	_wield.add_wieldable("wield_push",    true,  false, {"max_movement_speed_to_target": 0.15})
	_wield.add_wieldable("lvl_0_landing", false, true,  {"max_look_freedom_degrees_v": 10.0, "max_look_freedom_degrees_h": 0.0, "movement_multiplier": 0.0})

	_ensure_sound_controller()
	_node_subtitles.setup(_audio_player_voice)
	_audio_player_voice.finished.connect(_on_voice_finished)


func _on_active_voice_sequence_changed() -> void:
	if _audio_player_voice == null:
		return
		
	_audio_player_voice.stop()
	_node_subtitles.stop_subtitles()
	_remaining_voice_sequence = active_voice_sequence.duplicate()
	_play_next_voice()

func get_subtitle_path(path_to_voice_ogg: String) -> String:
	var base := path_to_voice_ogg.get_basename()
	var filename := path_to_voice_ogg.get_file().get_basename()
	var dir := path_to_voice_ogg.get_base_dir()
	
	if dir.ends_with("/gen") or dir.ends_with("\\gen"):
		return dir.get_base_dir() + "/" + filename + "_sub_en.srt"
		
	return base + "_sub_en.srt"

func _on_voice_finished() -> void:
	_node_subtitles.stop_subtitles()
	_play_next_voice()

func _play_next_voice() -> void:
	if _remaining_voice_sequence.is_empty():
		return
	
	var next_stream: AudioStream = _remaining_voice_sequence.pop_front()
	if next_stream == null:
		push_error("AudioStream is null in voice sequence")
		_play_next_voice()
		return
	
	var subtitle_path: String = get_subtitle_path(next_stream.resource_path)
	print("Playing subtitle: " + subtitle_path)
	
	_audio_player_voice.stream = next_stream
	_audio_player_voice.play()
	_node_subtitles.play_subtitles(subtitle_path)

func _ensure_sound_controller() -> void:
	if not is_inside_tree():
		return
		
	# Check if a SoundController already exists in the scene
	var root := get_tree().current_scene
	if root == null:
		# Fallback if current_scene is not set (e.g. running a scene independently)
		root = get_tree().root
		
	var existing_controllers := root.find_children("*", "SoundController", true, false)
	if existing_controllers.is_empty():
		# SoundController is not in the scene, add one to the player
		var sound_controller_script := load("res://assets/scripts/sound_controller.gd")
		if sound_controller_script == null:
			push_error("Could not load sound_controller.gd")
			return
			
		var sound_controller := Node.new()
		sound_controller.name = "SoundController"
		sound_controller.set_script(sound_controller_script)
		add_child(sound_controller)
		print("Scene foes not contain a sound controller. Sound controller has been automatically added by the player node")


func apply_footsteps(sounds: Array[AudioStream]) -> void:
	_footstep_sounds = sounds

func apply_footstep_start_sound(sound: AudioStream) -> void:
	_footstep_start_sound = sound

func apply_jump_sounds(sounds: Array[AudioStream]) -> void:
	_jump_sounds = sounds
	
func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if not control_enabled:
		velocity.x = move_toward(velocity.x, 0, max_speed)
		velocity.z = move_toward(velocity.z, 0, max_speed)
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return
	
	#_update_speed_cap(delta)
	
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
		velocity.x = direction.x * _current_speed(Vector2(direction.x, direction.z))
		velocity.z = direction.z * _current_speed(Vector2(direction.x, direction.z))
	else:
		velocity.x = move_toward(velocity.x, 0, max_speed)
		velocity.z = move_toward(velocity.z, 0, max_speed)
	
	move_and_slide()
	
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is RigidBody3D:
			collider.apply_central_impulse(-collision.get_normal() * PUSH_FORCE)
	
	if was_in_air and is_on_floor():
		_play_landing_sound()
	
	_wield.update(delta)
	_handle_hands_aim(delta)
	_handle_camera_limits(delta)
	_handle_head_bob(delta)
	_handle_footsteps(delta)
	_old_global_pos = global_position

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
			if control_enabled:
				rotate_y(-event_mouse_motion.relative.x * motion_speed)
				_node_camera.rotate_x(-event_mouse_motion.relative.y * motion_speed)
				if not is_rotating_limited:
					_handle_camera_limits(9999.0)

func _current_speed(direction: Vector2) -> float:
	var dir: Vector2 = direction
	if !dir.is_normalized():
		dir = UtilsMath.xz_normal(-transform.basis.z) # fallback
	var speed_target_multiplier: float = 1.0
	var speed_limit: float = max_speed
	var active_wieldable_data := _wield.active_wieldable_data
	if active_wieldable_data:
		speed_target_multiplier = active_wieldable_data.movement_multiplier
		speed_limit = min(speed_limit, active_wieldable_data.max_movement_speed)
		if wield_target && active_wieldable_data.max_movement_speed_to_target < max_speed:
			var direction_to_target: Vector2 = UtilsMath.xz_normal(wield_target.global_position - global_position)
			var factor: float = direction_to_target.distance_to(dir)
			factor = factor * 0.5
			factor = factor*factor
			var new_max_speed: float = lerp(active_wieldable_data.max_movement_speed_to_target, max_speed, min(1.0, factor))
			#print("max speed: " + str(new_max_speed))
			speed_limit = min(new_max_speed, speed_limit)
	speed_target_multiplier = min(speed_target_multiplier, speed_limit / max_speed)
	return speed_target_multiplier * max_speed

func _handle_head_bob(delta: float) -> void:
	var vertical_offset: float = 0.0
	var horizontal_offset: float = 0.0
	var lowering_offset: float = 0.0
	
	var actual_speed: float = _current_speed(moving_direction_2d)
	
	if is_on_floor() and velocity.length() > 0.1:
		_bob_phase += delta * (PI / (FOOTSTEP_INTERVAL.at(actual_speed)))
		_bob_phase = fmod(_bob_phase, PI * 2.0)
		vertical_offset = BOB_VERTICAL_AMPLITUDE.at(actual_speed) * abs(sin(_bob_phase))
		horizontal_offset = BOB_HORIZONTAL_AMPLITUDE.at(actual_speed) * sin(_bob_phase)
		lowering_offset = -MOVEMENT_LOWERING.at(actual_speed)
	
	_node_camera.position.y = lerp(_node_camera.position.y, _camera_default_position.y + lowering_offset + vertical_offset, delta * 15.0)
	_node_camera.position.x = lerp(_node_camera.position.x, _camera_default_position.x + horizontal_offset, delta * 15.0)

func _handle_footsteps(delta: float) -> void:
	var actual_speed: float = _current_speed(moving_direction_2d)

	if is_on_floor() and velocity.length() > 0.1:
		if not _is_moving:
			_is_moving = true
			_play_footstep_start_sound()
			_footstep_timer = 0.0
			_bob_phase = 0.0
			return

		_footstep_timer += delta
		if _footstep_timer >= (FOOTSTEP_INTERVAL.at(actual_speed)):
			_play_footstep()
			_footstep_timer = 0.0
			_bob_phase = fmod(roundf(_bob_phase / PI) * PI, PI * 2.0)
	else:
		_is_moving = false
		_footstep_timer = 0.0

func _handle_hands_aim(dt: float) -> void:
	var target_yaw: float = 0.0
	if active_wieldable == "wield_push" and wield_target != null:
		var direction_to_target: Vector3 = (wield_target.global_position - global_position).normalized()
		var local_direction: Vector3 = (transform.basis.inverse() * direction_to_target).normalized()
		target_yaw = atan2(-local_direction.x, -local_direction.z)
	
	_node_hands_yaw.rotation.y = lerp_angle(_node_hands_yaw.rotation.y, target_yaw, minf(1.0, dt * 30.0))
