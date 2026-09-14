extends CharacterBody3D
class_name Player


const SPEED: float = 3.0
const JUMP_VELOCITY: float = 3.5
const FOOTSTEP_INTERVAL: float = 0.36
const BOB_VERTICAL_AMPLITUDE: float = 0.08
const BOB_HORIZONTAL_AMPLITUDE: float = 0.02
const MOVEMENT_LOWERING: float = 0.15
const HANDS_APPEAR_DURATION: float = 0.1

@onready var _node_camera : Node3D = $_Neck/Camera3D

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

static func _frame_index_to_time(index: int) -> float:
	const ANIMATION_FRAMES_PER_SECOND: float = 24
	return float(index) / ANIMATION_FRAMES_PER_SECOND

class AnimationRange:
	var from: int = 0
	var to: int = 0
	var speed: float = 0
	func _init(p_from: int, p_to: int, p_speed: float = 1.0):
		from = p_from
		to = p_to
		speed = p_speed

class Animations:
	var equip: AnimationRange = AnimationRange.new(0,0)
	var dequip: AnimationRange = AnimationRange.new(0,0)

class WieldableData:
	var node: Node3D = null
	var animations: Animations = Animations.new()
	var animation_player: AnimationPlayer = null
	var _animation_name: String = ""

	func _init(p_wield_node: Node3D, p_equip: AnimationRange, p_dequip: AnimationRange) -> void:
		node = p_wield_node
		animations.equip = p_equip
		animations.dequip = p_dequip
		if p_wield_node:
			p_wield_node.visible = false
			animation_player = UtilsNode.find_animation_player_recursive(p_wield_node)
			var anim_list: PackedStringArray = animation_player.get_animation_list()
			_animation_name = anim_list[0]
	
	func play_animation(range: AnimationRange) -> bool:
		if animation_player:
			if range.from <= range.to:
				animation_player.play_section(_animation_name, Player._frame_index_to_time(range.from), Player._frame_index_to_time(range.to), -1,  range.speed, false)
			else:
				animation_player.play_section(_animation_name, Player._frame_index_to_time(range.from), Player._frame_index_to_time(range.to), -1, -range.speed, true)
			return true
		return false
	
	func is_playing_animation() -> bool:
		if animation_player:
			return animation_player.is_playing()
		else:
			return false


enum Wieldable {NONE, PUSH}

@onready var _wieldables: Dictionary = {
	Wieldable.NONE: WieldableData.new(null, 			AnimationRange.new(0,0,1), 		AnimationRange.new(0,0,1)),
	Wieldable.PUSH: WieldableData.new($_Wield/_Push, 	AnimationRange.new(0,40,1), 	AnimationRange.new(40,0,1))
}

# Sounds
var _footstep_sounds: Array[AudioStream] = FOOTSTEP_SOUNDS
var _footstep_start_sound: AudioStream = FOOTSTEP_START_SOUND
var _jump_sounds: Array[AudioStream] = JUMP_SOUNDS
var _landing_sounds: Array[AudioStream] = LANDING_SOUNDS
var _footstep_timer: float = 0.0
var _audio_player: AudioStreamPlayer3D

# Animations
var _camera_default_position: Vector3 = Vector3.ZERO
var _bob_phase: float = 0.0
var _is_moving: bool = false

var wieldable: Wieldable = Wieldable.NONE
var _wieldable_old: Wieldable = Wieldable.NONE

func _ready() -> void:
	if _node_camera == null:
		push_error("_node_camera is null")
		return
		
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	_camera_default_position = _node_camera.position

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
	
	_handle_wieldable()
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
	match wieldable:
		Wieldable.PUSH:
			return 0.2
		_:
			return 1.0

func _get_animation_speed_multiplier() -> float:
	match wieldable:
		Wieldable.PUSH:
			return 0.7
		_:
			return 1.0

enum WieldState {NONE, DEQUIPING, EQUIPING_START, EQUIPING}

var _wield_state: WieldState = WieldState.NONE
func _handle_wieldable() -> void:
		
	match _wield_state:
		WieldState.NONE:
			if _wieldable_old != wieldable:
				var old_wieldable: WieldableData = _wieldables[_wieldable_old]
				if old_wieldable.play_animation(old_wieldable.animations.dequip):
					_wield_state = WieldState.DEQUIPING
				else:
					if old_wieldable.node:
						old_wieldable.node.visible = false
					_wield_state = WieldState.EQUIPING_START
					
		WieldState.DEQUIPING:
			var old_wieldable: WieldableData = _wieldables[_wieldable_old]
			if !old_wieldable.is_playing_animation():
				if old_wieldable.node:
					old_wieldable.node.visible = false
				_wield_state = WieldState.EQUIPING_START
				
		WieldState.EQUIPING_START:		
			var new_wieldable: WieldableData = _wieldables[wieldable]
			if new_wieldable.node:
				new_wieldable.node.visible = true
			if new_wieldable.play_animation(new_wieldable.animations.equip):
				_wield_state = WieldState.EQUIPING
			else:
				_wield_state = WieldState.NONE
			_wieldable_old = wieldable
			
		WieldState.EQUIPING:
			var new_wieldable: WieldableData = _wieldables[wieldable]
			if !new_wieldable.is_playing_animation():
				_wield_state = WieldState.NONE
	

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
			_bob_phase = fmod(round(_bob_phase / PI) * PI, PI * 2.0)
	else:
		_is_moving = false
		_footstep_timer = 0.0
