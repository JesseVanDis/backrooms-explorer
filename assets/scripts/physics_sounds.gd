extends RigidBody3D
class_name PhysicsSounds

const SLIDE_DEFAULT: AudioStream = preload("res://assets/sounds/slide_1.wav")
const BONK_DEFAULT: AudioStream = preload("res://assets/sounds/bonk_1.wav")
const VELOCITY_THRESHOLD: float = 0.3
const ANGULAR_VELOCITY_THRESHOLD: float = 1.0
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
var _seconds_since_slide_state_change: float = 0.0

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
	
	_seconds_since_slide_state_change += dt
	
	var velocity: float = linear_velocity.length()
	var angular_vel: float = angular_velocity.length()
		
	if velocity > VELOCITY_THRESHOLD and angular_vel < ANGULAR_VELOCITY_THRESHOLD:
		if not _audio_slide.playing:
			print("Playing slide!: " + str(_audio_slide.playing))
			_audio_slide.play()
			_seconds_since_slide_state_change = 0.0
			print("Playing slide!: " + str(_audio_slide.playing))
		var volume: float = min(1.0, _seconds_since_slide_state_change * 3.0)
		# Adjust volume based on velocity if desired
		_audio_slide.volume_linear = volume
		# _audio_slide.unit_size = volume# clampf(velocity * 2.0, 1.0, 5.0)
	else:
		if _audio_slide.playing:
			print("Stopping slide")
			_seconds_since_slide_state_change = 0.0
			_audio_slide.stop()

func _on_body_entered(body: Node) -> void:
	if _startup_timer > 0.0:
		return
		
	if body is Player:
		return
		
	# Play bonk sound
	if not _audio_bonk.playing or _audio_bonk.get_playback_position() > 0.1:
		_audio_bonk.pitch_scale = bonk_pitch_scale * randf_range(0.9, 1.1)
		_audio_bonk.play()
