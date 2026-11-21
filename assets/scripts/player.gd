## [AI-DOC] First-person CharacterBody3D controller handling movement, delayed freefall and other AnimationTree behaviours, gated camera offsets, head bob, push-target hand yaw, asymmetric pivot-based mouse look, audio, and debug freecam
## spec: docs/ai/systems/player.md
## status: partial
## notes: resolves the named head-pitch and perspective-hands modifiers separately; hand yaw follows active push targets without changing other rotation axes

extends CharacterBody3D

class_name Player

const JUMP_VELOCITY: float = 3.5
const FREECAM_FLY_SPEED: float = 10.0
const FREECAM_FAST_SPEED_MULTIPLIER: float = 3.0
const FREECAM_MOUSE_SENSITIVITY: float = 0.003
const FREEFALL_ACTIVATION_DELAY: float = 0.5
const MAX_LOOK_UP_DEGREES: float = 90.0
const MAX_LOOK_DOWN_DEGREES: float = 80.0
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

@onready var _audio_player_voice: AudioStreamPlayer3D = null
@onready var _audio_player_foot: AudioStreamPlayer3D = null
@onready var _node_camera : Camera3D = null
@onready var _node_camera_pitch_pivot : Node3D = null
#@onready var _node_hands_yaw : Node3D = null
var _ingame_ui: IngameUI = null
var _num_frames_since_ready: int = 0

var _spine_pitch: float = 0.0
var _skeleton_modifier_headpitch: SkeletonModifier = null
var _skeleton_modifier_perspective_hands: SkeletonModifier = null

#var active_voice_sequence: Array[AudioStream] = []:
#	set(value):
#		active_voice_sequence = value
#		_on_active_voice_sequence_changed()

var _remaining_voice_sequence: Array[AudioStream] = []
var behaviour_target: Node3D = null


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

var _behaviour: PlayerBehaviour = PlayerBehaviour.new(self)
var control_enabled: bool = true
var _freefall_air_time: float = 0.0

#var active_behaviourable: String:
	#get:        return _behaviour.active_behaviourable
	#set(value): _behaviour.active_behaviourable = value

var _flags: Dictionary = {}
var _started: bool = false
var started: bool: 
	get: return _started

# Animations
var _camera_default_position: Vector3 = Vector3.ZERO
var _camera_offset: Vector3 = Vector3.ZERO
var _camera_offset_speed: float = 1.0
var _camera_bob_offset: Vector3 = Vector3.ZERO
var _bob_phase: float = 0.0
var _is_moving: bool = false

# cheats
var _cheat_gravity_disabled: bool = false
var _cheat_fast_mode: bool = false
var _cheat_vars: Dictionary = {}

# Debug freecam
var _debug_cam: Camera3D = null
var _is_debug_cam_active: bool = false
var _debug_cam_yaw: float = 0.0
var _debug_cam_pitch: float = 0.0

var forward_2d: Vector2:
	get(): return UtilsMath.xz_normal(-transform.basis.z)

var moving_direction_2d: Vector2:
	get(): return UtilsMath.xz_normal(global_position - _old_global_pos)

# Lets levels register an AnimationTree behaviour together with its player restrictions.
func add_behaviour(unique_name: String, p_animation_tree_parameter: StringName = "", p_additional_settings: Dictionary = {}) -> void:
	_behaviour.add(unique_name, p_animation_tree_parameter, p_additional_settings)

# Refreshes restrictions now so activation affects input before the next physics update.
func activate_behaviour(unique_name: String) -> void:
	_behaviour.activate(unique_name)
	_behaviour.refresh_active_settings()
	
# Rebuilds effective restrictions immediately so they follow the changed animation state.
func deactivate_behaviour(unique_name: String) -> void:
	_behaviour.deactivate(unique_name)
	_behaviour.refresh_active_settings()

# Exposes a behaviour's current AnimationTree lifecycle phase to player callers.
func get_behaviour_status(unique_name: String) -> PlayerBehaviour.BehaviourStatus:
	return _behaviour.get_behaviour_status(unique_name)

# returns false if it already was triggered
# use for anything really. will be saved in player savegame as well.
func set_flag(id: String) -> bool:
	if _flags.has(id):
		return false
	_flags[id] = true
	print("Player flag '" + id + "' set")
	return true

func is_flag_set(id: String) -> bool:
	return _flags.has(id)

# Initializes camera framing and exported pitch after default behaviours register, before the first physics frame.
func _ready() -> void:
	_num_frames_since_ready = 0
	_audio_player_voice = UtilsNode.find_node_with_name_recursive(self, "RaytracedAudioPlayer3D_Voice")
	_audio_player_foot = UtilsNode.find_node_with_name_recursive(self, "RaytracedAudioPlayer3D_Foot")
	_node_camera = UtilsNode.find_camera_recursive(self)
	_skeleton_modifier_headpitch = UtilsNode.find_node_with_name_recursive(self, "_skeleton_modifier_headpitch") as SkeletonModifier
	_skeleton_modifier_perspective_hands = UtilsNode.find_node_with_name_recursive(self, "_skeleton_modifier_perspective_hands") as SkeletonModifier
	_node_camera_pitch_pivot = UtilsNode.find_node_with_name_recursive(self, "_cam_pitch_pivot")

	_ingame_ui = _find_ingame_ui()
	
	if _node_camera == null:
		push_error("_node_camera is null")
		return
		
	if _node_camera_pitch_pivot == null:
		push_error("_node_camera_pitch_pivot is null")
		return

	if _audio_player_voice == null:
		push_error("_audio_player_voice is null")
		return

	if _audio_player_foot == null:
		push_error("_audio_player_foot is null")
		return
	
	if _skeleton_modifier_headpitch == null:
		push_error("_skeleton_modifier_headpitch is null")
		return

	if _skeleton_modifier_perspective_hands == null:
		push_error("_skeleton_modifier_perspective_hands is null")
		return
		
		
	#if _node_hands_yaw == null:
	#	push_error("_node_hands is null")
	

	rotation.y = deg_to_rad(initial_yaw)
	_spine_pitch = deg_to_rad(initial_pitch)
	_camera_default_position = _node_camera.position

	# Register default behaviours with restrictions keyed by their player property names.
	add_behaviour("")
	add_behaviour("run",  "parameters/run/blend_amount", {
		"anim_activation_speed": 4.0, 
		"anim_deactivation_speed": 4.0, 
		"player_camera_offset": Vector3(0.0, 0.0, -0.10),
		"player_camera_offset_speed": 2.0
	})
	
	add_behaviour("push", "parameters/push/blend_amount", {
		"anim_activation_speed": 3.0, 
		"anim_deactivation_speed": 2.0, 
		"player_max_movement_speed_to_target": 0.15
	})
	
	add_behaviour("freefall",  "parameters/freefall/blend_amount", {
		"anim_activation_speed": 4.0, 
		"anim_deactivation_speed": 4.0
	})
	
	_handle_camera_limits(0.0)

	_ensure_sound_controller()
	if _ingame_ui != null:
		_ingame_ui.setup(_audio_player_voice)
	else:
		push_error("_ingame_ui is null")
	_audio_player_voice.finished.connect(_on_voice_finished)
	_setup_debug_camera()

func _start() -> void:
	UtilsScreen.fade_out_screen(get_tree())
	velocity = initial_velocity
	_started = true

func replace_voice(sequence: Array[AudioStream]) -> void:
	if _audio_player_voice == null:
		return
		
	_audio_player_voice.stop()
	_ingame_ui.stop_subtitles()
	_remaining_voice_sequence = sequence.duplicate()
	_play_next_voice()

func push_back_voice(sequence: Array[AudioStream]) -> void:
	if _audio_player_voice == null:
		return
		
	var is_playing: bool = _audio_player_voice.playing or not _remaining_voice_sequence.is_empty()
	
	_remaining_voice_sequence.append_array(sequence)
	
	if not is_playing:
		_play_next_voice()

func push_front_voice(sequence: Array[AudioStream]) -> void:
	if _audio_player_voice == null:
		return
		
	if not _audio_player_voice.playing:
		replace_voice(sequence)
		return
	
	# If something is playing, we want to play this AFTER the current item finishes.
	# So we insert it at the beginning of the remaining sequence.
	var new_sequence: Array[AudioStream] = sequence.duplicate()
	new_sequence.append_array(_remaining_voice_sequence)
	_remaining_voice_sequence = new_sequence

#func _on_active_voice_sequence_changed() -> void:
#	interrupt_voice(active_voice_sequence)

func get_subtitle_path(path_to_voice_ogg: String) -> String:
	var base := path_to_voice_ogg.get_basename()
	var filename := path_to_voice_ogg.get_file().get_basename()
	var dir := path_to_voice_ogg.get_base_dir()
	
	if dir.ends_with("/gen") or dir.ends_with("\\gen"):
		return dir.get_base_dir() + "/" + filename + "_sub_en.srt"
		
	return base + "_sub_en.srt"

func _on_voice_finished() -> void:
	_ingame_ui.stop_subtitles()
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
	_ingame_ui.play_subtitles(subtitle_path)

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
	
# Updates free-flight debug camera movement when freecam mode is active.
func _process(real_delta: float) -> void:
	if _is_debug_cam_active:
		_process_freecam_movement(real_delta)
		
	if _num_frames_since_ready == 2:
		_start() # add some delay to start, as some stuff in the scene still desires 1 or 2 frames for it to be complete
	_num_frames_since_ready = _num_frames_since_ready + 1

# Keeps movement and delayed freefall behavior consistent while controls are enabled or disabled.
func _physics_process(real_delta: float) -> void:
	if _is_debug_cam_active:
		velocity = Vector3.ZERO
		return

	var is_fast_mode: bool = _is_fast_mode()
	var is_gravity_disabled: bool = _is_gravity_disabled()
	var delta: float = real_delta
	if is_fast_mode:
		delta = 0.1
	_behaviour.update(delta)
	_handle_hands_aim(delta)
		
	if not control_enabled:
		_update_camera_behavior_offsets(delta)
		velocity.x = move_toward(velocity.x, 0, max_speed)
		velocity.z = move_toward(velocity.z, 0, max_speed)
		if not is_on_floor() and not is_gravity_disabled:
			velocity += get_gravity() * delta
		move_and_slide()
		_update_freefall_behaviour(real_delta)
		return
	
	#_update_speed_cap(delta)
	
	var was_in_air: bool = not is_on_floor()
	# Add the gravity.
	if not is_on_floor() and not is_gravity_disabled and _started:
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
	
	if input_dir == Vector2.ZERO:
		deactivate_behaviour("run")
	else:
		activate_behaviour("run")
	_update_camera_behavior_offsets(delta)
	
	if direction:
		velocity.x = direction.x * _current_speed(Vector2(direction.x, direction.z))
		velocity.z = direction.z * _current_speed(Vector2(direction.x, direction.z))
		if is_fast_mode:
			velocity *= 10.0
	else:
		if is_fast_mode:
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			velocity.x = move_toward(velocity.x, 0, max_speed)
			velocity.z = move_toward(velocity.z, 0, max_speed)
	
	move_and_slide()
	_update_freefall_behaviour(real_delta)
	
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is RigidBody3D:
			var collider_rigid_body := collider as RigidBody3D
			collider_rigid_body.apply_central_impulse(-collision.get_normal() * PUSH_FORCE)
	
	if was_in_air and is_on_floor():
		_play_landing_sound()
	
	_handle_camera_limits(delta)
	_apply_spine_pitch()
	_handle_head_bob(delta)
	_handle_footsteps(delta)
	_old_global_pos = global_position

# Triggers the freefall animation only after sustained airtime and clears it on every landing.
func _update_freefall_behaviour(real_delta: float) -> void:
	var freefall_status: PlayerBehaviour.BehaviourStatus = _behaviour.get_behaviour_status("freefall")
	if is_on_floor():
		_freefall_air_time = 0.0
		if freefall_status == PlayerBehaviour.BehaviourStatus.ENABLING or freefall_status == PlayerBehaviour.BehaviourStatus.ACTIVE:
			deactivate_behaviour("freefall")
		return

	_freefall_air_time += real_delta
	if _freefall_air_time > FREEFALL_ACTIVATION_DELAY and (freefall_status == PlayerBehaviour.BehaviourStatus.IDLE or freefall_status == PlayerBehaviour.BehaviourStatus.DISABLING):
		activate_behaviour("freefall")

func _play_footstep() -> void:
	if _footstep_sounds.is_empty():
		return
	_audio_player_foot.stream = _footstep_sounds.pick_random()
	_audio_player_foot.pitch_scale = randf_range(0.9, 1.3)
	_audio_player_foot.volume_db = -20.0;
	_audio_player_foot.play()

func _play_footstep_start_sound() -> void:
	if _footstep_start_sound == null:
		_play_footstep()
		return
	_audio_player_foot.stream = _footstep_start_sound
	_audio_player_foot.pitch_scale = randf_range(0.9, 1.3)
	_audio_player_foot.volume_db = -20.0;
	_audio_player_foot.play()

func _play_jump_sound() -> void:
	if _jump_sounds.is_empty():
		return
	_audio_player_foot.stream = _jump_sounds.pick_random()
	_audio_player_foot.pitch_scale = randf_range(0.9, 1.0)
	_audio_player_foot.play()

func _play_landing_sound() -> void:
	if _landing_sounds.is_empty():
		return
	_audio_player_foot.stream = _landing_sounds.pick_random()
	# Pitch variation for landing sounds
	_audio_player_foot.pitch_scale = randf_range(0.8, 1.1)
	# _audio_player.volume_db = 10.0;
	_audio_player_foot.play()

# Clamps up/down pitch independently within absolute and behaviour limits, then synchronizes the camera pivot.
func _handle_camera_limits(_dt: float) -> void:
	
	#var adjustement_speed := 10.0 + _behaviour.seconds_since_equiping_start * 40.0
	#var adjustement_step := minf(1.0, adjustement_speed * dt)
	var adjustement_step: float = 1.0
	#var active_behaviourable_data := _behaviour.active_behaviourable_data
	
	var max_look_freedom_h: float = _behaviour.active_settings.player_max_look_freedom_degrees_h
	var max_look_freedom_v: float = _behaviour.active_settings.player_max_look_freedom_degrees_v
	
	var maximum_upward_pitch_degrees: float = MAX_LOOK_UP_DEGREES
	var maximum_downward_pitch_degrees: float = MAX_LOOK_DOWN_DEGREES
	var yaw_limit_deg := 360.0
	if max_look_freedom_h < 360.0:
		yaw_limit_deg = max_look_freedom_h * 0.5
	if max_look_freedom_v < 360.0:
		var behaviour_pitch_limit_degrees: float = max_look_freedom_v * 0.5
		maximum_upward_pitch_degrees = minf(maximum_upward_pitch_degrees, behaviour_pitch_limit_degrees)
		maximum_downward_pitch_degrees = minf(maximum_downward_pitch_degrees, behaviour_pitch_limit_degrees)

	var target_pitch := clampf(_spine_pitch, deg_to_rad(-maximum_upward_pitch_degrees), deg_to_rad(maximum_downward_pitch_degrees))
	if target_pitch != _spine_pitch:
		_spine_pitch = (_spine_pitch * (1.0 - adjustement_step)) + (target_pitch * adjustement_step)
	else:
		_spine_pitch = target_pitch
	_node_camera_pitch_pivot.rotation.x = -_spine_pitch
	
	if yaw_limit_deg < 360.0:
		var target_y := clampf(self.rotation.y, deg_to_rad(-yaw_limit_deg), deg_to_rad(yaw_limit_deg))
		if self.rotation.y != target_y:
			self.rotation.y = (self.rotation.y * (1.0 - adjustement_step)) + (target_y * adjustement_step)
	_apply_camera_position()


# Moves toward offsets from behaviours in Enabling or Active, so Disabling starts camera return before animation completion.
func _update_camera_behavior_offsets(dt: float) -> void:
	var active_settings: Dictionary = _behaviour.active_settings.additional_settings
	var target_offset: Vector3 = _behaviour.active_settings.player_camera_offset
	if active_settings.has("player_camera_offset_speed"):
		_camera_offset_speed = _behaviour.active_settings.player_camera_offset_speed
	var offset_step: float = maxf(0.0, _camera_offset_speed) * dt
	_camera_offset.x = move_toward(_camera_offset.x, target_offset.x, offset_step)
	_camera_offset.y = move_toward(_camera_offset.y, target_offset.y, offset_step)
	_camera_offset.z = move_toward(_camera_offset.z, target_offset.z, offset_step)
	_apply_camera_position()


# Combines root-relative behavior displacement with local bob so each camera effect remains independent.
func _apply_camera_position() -> void:
	var camera_parent: Node3D = _node_camera.get_parent() as Node3D
	if camera_parent == null:
		push_error("Player camera parent is null")
		return
	var offset_in_camera_parent_space: Vector3 = camera_parent.global_transform.basis.inverse() * global_transform.basis * _camera_offset
	_node_camera.position = _camera_default_position + _camera_bob_offset + offset_in_camera_parent_space


# Handles player input and applies clamped mouse pitch through the pivot; headless motion remains available for regression tests.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event == null:
			push_error("key_event is null")
			return
		if key_event.pressed and not key_event.echo:
			if key_event.physical_keycode == KEY_C or key_event.keycode == KEY_C:
				_toggle_debug_cam()
				return

	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if _is_debug_cam_active:
		if event is InputEventMouseMotion and (Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"):
			var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
			if mouse_motion == null:
				push_error("mouse_motion is null")
				return
			_handle_freecam_look(mouse_motion)
		return

	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless":
		var event_mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		if event_mouse_motion:
			_behaviour.refresh_active_settings()
			var motion_speed := 0.01
			# var active_behaviourable_data := _behaviour.active_behaviourable_data
			var is_rotating_limited: bool = (_behaviour.active_settings.player_max_look_freedom_degrees_h < 360.0 or _behaviour.active_settings.player_max_look_freedom_degrees_v < 360.0)
			if is_rotating_limited:
				motion_speed = 0.0005
			if control_enabled:
				rotate_y(-event_mouse_motion.relative.x * motion_speed)
				# print("rotating limited: " + str(is_rotating_limited) + ", motionspeed: " + str(motion_speed))
				_spine_pitch += event_mouse_motion.relative.y * motion_speed
				_handle_camera_limits(0.0)

func _current_speed(direction: Vector2) -> float:
	var dir: Vector2 = direction
	if !dir.is_normalized():
		dir = UtilsMath.xz_normal(-transform.basis.z) # fallback
	var speed_limit: float = max_speed
	# var active_behaviourable_data := _behaviour.active_behaviourable_data
	#if active_behaviourable_data:
	var speed_target_multiplier: float = _behaviour.active_settings.player_movement_multiplier
	speed_limit = min(speed_limit, _behaviour.active_settings.player_max_movement_speed)
	if behaviour_target && _behaviour.active_settings.player_max_movement_speed_to_target < max_speed:
		var direction_to_target: Vector2 = UtilsMath.xz_normal(behaviour_target.global_position - global_position)
		var factor: float = direction_to_target.distance_to(dir)
		factor = factor * 0.5
		factor = factor*factor
		var new_max_speed: float = lerp(_behaviour.active_settings.player_max_movement_speed_to_target, max_speed, min(1.0, factor))
		#print("max speed: " + str(new_max_speed))
		speed_limit = min(new_max_speed, speed_limit)
	speed_target_multiplier = min(speed_target_multiplier, speed_limit / max_speed)
	return speed_target_multiplier * max_speed

#func _handle_standard_animations(delta: float) -> void:
	#pass

# Keeps smoothed bob and movement lowering separate from behavior offsets applied to the camera.
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
	
	_camera_bob_offset.y = lerp(_camera_bob_offset.y, lowering_offset + vertical_offset, delta * 15.0)
	_camera_bob_offset.x = lerp(_camera_bob_offset.x, horizontal_offset, delta * 15.0)
	_apply_camera_position()

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

# Applies the accumulated spine pitch rotation to the skeleton bone each physics frame so the head and camera follow.
# The skeleton is retrieved each frame to avoid storing a reference that might become invalid.
func _apply_spine_pitch() -> void:
	_skeleton_modifier_headpitch.extra_rotation_degrees = Vector3(rad_to_deg(_spine_pitch), 0.0, 0.0)


# Aims the perspective hands at the push target and eases them back as the push blend fades out.
func _handle_hands_aim(dt: float) -> void:
	var target_yaw: float = 0.0
	if _behaviour.is_behaviour_active("push") and behaviour_target != null:
		var direction_to_target: Vector3 = behaviour_target.global_position - global_position
		direction_to_target.y = 0.0
		if direction_to_target.length_squared() > 0.0:
			var local_direction: Vector3 = (global_transform.basis.inverse() * direction_to_target).normalized()
			target_yaw = atan2(-local_direction.x, -local_direction.z)

	var current_yaw: float = deg_to_rad(_skeleton_modifier_perspective_hands.extra_rotation_degrees.y)
	var next_yaw: float = lerp_angle(current_yaw, target_yaw, minf(1.0, dt * 30.0))
	_skeleton_modifier_perspective_hands.extra_rotation_degrees.y = rad_to_deg(next_yaw)

# Allows development tools, cheats, and testing routines to toggle gravity simulation off or on for free movement and debugging.
func set_cheat_disable_gravity(enabled: bool) -> void:
	_cheat_gravity_disabled = enabled

# Checks whether anti-gravity cheat mode is currently active either via persistent cheat flag or holding the Shift key.
func _is_gravity_disabled() -> bool:
	return _cheat_gravity_disabled or Input.is_key_pressed(KEY_SHIFT)

# Checks whether fast mode is currently enabled either via persistent cheat flag or holding the Shift key.
func _is_fast_mode() -> bool:
	return _cheat_fast_mode or Input.is_key_pressed(KEY_SHIFT)

# Enables or disables fast movement cheat mode for faster level traversal and testing.
func set_cheat_fast_mode(enabled: bool) -> void:
	_cheat_fast_mode = enabled

# Enables or disables collision detection masks for testing, debugging, and unrestricted exploration while preserving original mask values for restoration.
func set_cheat_collisions_disabled(enabled: bool) -> void:
	if enabled:
		if not _cheat_vars.has("cheat_collisions_disabled"):
			_cheat_vars["cheat_collisions_disabled"] = {"collision_mask": collision_mask}
		collision_mask = 0
	else:
		if _cheat_vars.has("cheat_collisions_disabled"):
			var original_values: Dictionary = _cheat_vars["cheat_collisions_disabled"]
			if original_values.has("collision_mask"):
				collision_mask = original_values["collision_mask"]
			_cheat_vars.erase("cheat_collisions_disabled")
	
	
# Traverses up the scene tree to locate the IngameUI layer for forwarding voice subtitles and UI state.
func _find_ingame_ui() -> IngameUI:
	var current: Node = self
	while current != null:
		if current is IngameUI:
			return current as IngameUI
		for node in current.find_children("*", "Node", true, false):
			if node is IngameUI:
				return node as IngameUI
		current = current.get_parent()
	push_error("IngameUI not found!")
	return null

# Creates and attaches an auxiliary top-level Camera3D to the player node for free-flight debugging.
func _setup_debug_camera() -> void:
	_debug_cam = Camera3D.new()
	_debug_cam.name = "DebugCamera"
	_debug_cam.top_level = true
	add_child(_debug_cam)

# Rotates the debug camera based on mouse motion while clamping pitch to prevent gimbal inversion.
func _handle_freecam_look(mouse_motion: InputEventMouseMotion) -> void:
	if _debug_cam == null:
		push_error("_debug_camera is null in _handle_freecam_look")
		return

	_debug_cam_yaw -= mouse_motion.relative.x * FREECAM_MOUSE_SENSITIVITY
	_debug_cam_pitch = clampf(
		_debug_cam_pitch - mouse_motion.relative.y * FREECAM_MOUSE_SENSITIVITY,
		deg_to_rad(-89.9),
		deg_to_rad(89.9)
	)
	_debug_cam.global_rotation = Vector3(_debug_cam_pitch, _debug_cam_yaw, 0.0)

# Translates the debug camera in 3D space according to directional keyboard inputs and speed modifiers.
func _process_freecam_movement(delta: float) -> void:
	if _debug_cam == null:
		push_error("_debug_camera is null in _process_freecam_movement")
		return

	var movement_vector: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		movement_vector -= _debug_cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		movement_vector += _debug_cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		movement_vector -= _debug_cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		movement_vector += _debug_cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		movement_vector += Vector3.UP
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		movement_vector += Vector3.DOWN

	var fly_speed: float = FREECAM_FLY_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		fly_speed *= FREECAM_FAST_SPEED_MULTIPLIER

	if movement_vector.length_squared() > 0.0001:
		_debug_cam.global_position += movement_vector.normalized() * fly_speed * delta

# Toggles between normal player control and free-flight debug camera mode for level inspection.
func _toggle_debug_cam() -> void:
	set_freecam(!_is_debug_cam_active)

# Activates or deactivates free-flight debug camera mode and manages active camera switching.
func set_freecam(enabled: bool) -> void:
	_is_debug_cam_active = enabled
	if _is_debug_cam_active:
		if _debug_cam == null:
			push_error("_debug_cam is null when activating freecam")
			return
		if _node_camera == null:
			push_error("_node_camera is null when activating freecam")
			return
		_debug_cam.global_transform = _node_camera.global_transform
		var camera_rotation: Vector3 = _node_camera.global_rotation
		_debug_cam_yaw = camera_rotation.y
		_debug_cam_pitch = camera_rotation.x
		_debug_cam.global_rotation = Vector3(_debug_cam_pitch, _debug_cam_yaw, 0.0)
		_debug_cam.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		if _debug_cam != null:
			_debug_cam.current = false
		if _node_camera == null:
			push_error("_node_camera is null when deactivating freecam")
			return
		_node_camera.make_current()
