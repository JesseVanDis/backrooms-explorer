extends RigidBody3D
class_name PhysicsSounds

const SLIDE_DEFAULT: AudioStream = preload("res://assets/sounds/slide_1.wav")
const BONK_DEFAULT: AudioStream = preload("res://assets/sounds/bonk_1.wav")
const SLIDE_SOUND_VELOCITY_THRESHOLD: float = 0.3
const SLIDE_SOUND_FADE_IN_SPEED: float = 0.5
const SLIDE_SOUND_FADE_OUT_SPEED: float = 0.1
const MIN_IMPULSE_FOR_BONK: float = 0.5

@export var slide_sound: AudioStreamWAV = SLIDE_DEFAULT
@export var slide_volume_db: float = 0.0
@export var slide_pitch_scale: float = 1.0
@export var bonk_sound: AudioStreamWAV = BONK_DEFAULT
@export var bonk_volume_db: float = 0.0
@export var bonk_pitch_scale: float = 1.0

var _audio_slide: AudioStreamPlayer3D = null
var _audio_bonk: AudioStreamPlayer3D = null
var _startup_timer: float = 2.0
var _sliding_volume: float = 0.0

# var _seconds_since_slide_state_change: float = 0.0

func _ready() -> void:
	# Setup slide audio player
	_audio_slide = AudioStreamPlayer3D.new()
	_audio_slide.stream = slide_sound
	_audio_slide.autoplay = false
	_audio_slide.volume_db = slide_volume_db
	_audio_slide.pitch_scale = slide_pitch_scale	
	add_child(_audio_slide)

	# Setup bonk audio player
	_audio_bonk = AudioStreamPlayer3D.new()
	_audio_bonk.stream = bonk_sound
	_audio_bonk.autoplay = false
	_audio_bonk.volume_db = bonk_volume_db
	_audio_bonk.pitch_scale = bonk_pitch_scale
	add_child(_audio_bonk)

	# Ensure RigidBody3D is set up for contact monitoring
	contact_monitor = true
	if max_contacts_reported < 3:
		max_contacts_reported = 3
	
	body_entered.connect(_on_body_entered)

func _physics_process(dt: float) -> void:
	if _startup_timer > 0.0:
		_startup_timer -= dt
		return
	
	var velocity: float = linear_velocity.length()
	
	if is_boxshape_laying_float(5.0) && velocity > SLIDE_SOUND_VELOCITY_THRESHOLD:
		var fraction: float = min(1.0, SLIDE_SOUND_FADE_IN_SPEED * dt)
		_sliding_volume = _sliding_volume * (1.0 - fraction) + 1.0 * fraction
	else:
		var fraction: float = min(1.0, SLIDE_SOUND_FADE_OUT_SPEED * dt)
		_sliding_volume = _sliding_volume * (1.0 - fraction)
	
	if _sliding_volume > 0.0:
		print("sliding_volume: " + str(_sliding_volume))
	
	_audio_slide.volume_linear = _sliding_volume
	if _sliding_volume > 0.001 && not _audio_slide.playing:
		_audio_slide.play()
		print("PLAY!")
	elif _sliding_volume <= 0.001 && _audio_slide.playing:
		_audio_slide.stop()
		print("STOP!")
	

func _on_body_entered(body: Node) -> void:
	if _startup_timer > 0.0:
		return
		
	if body is Player:
		return
		
	# Play bonk sound
	if not _audio_bonk.playing or _audio_bonk.get_playback_position() > 0.1:
		_audio_bonk.pitch_scale = bonk_pitch_scale * randf_range(0.9, 1.1)
		_audio_bonk.play()


func is_boxshape_laying_float(tollerance_degrees: float) -> bool:
	const UP: Vector3 = Vector3.UP
	var _basis: Basis = global_transform.basis
	var _tolerance_radians: float = deg_to_rad(tollerance_degrees)

	# Check local X axis
	var _x_angle: float = _basis.x.angle_to(UP)
	if _x_angle < _tolerance_radians or abs(_x_angle - PI) < _tolerance_radians:
		return true

	# Check local Y axis
	var _y_angle: float = _basis.y.angle_to(UP)
	if _y_angle < _tolerance_radians or abs(_y_angle - PI) < _tolerance_radians:
		return true

	# Check local Z axis
	var _z_angle: float = _basis.z.angle_to(UP)
	if _z_angle < _tolerance_radians or abs(_z_angle - PI) < _tolerance_radians:
		return true

	return false
