extends RigidBody3D
class_name PhysicsSounds

const SLIDE_DEFAULT: AudioStream = preload("res://assets/sounds/slide_1.wav")
const BONK_DEFAULT: AudioStream = preload("res://assets/sounds/bonk_1.wav")
const VELOCITY_THRESHOLD: float = 0.1
const MIN_IMPULSE_FOR_BONK: float = 0.5

@export var slide_sound: AudioStreamWAV = SLIDE_DEFAULT
@export var bonk_sound: AudioStreamWAV = BONK_DEFAULT

var _audio_slide: AudioStreamPlayer3D = null
var _audio_bonk: AudioStreamPlayer3D = null

func _ready() -> void:
	# Setup slide audio player
	_audio_slide = AudioStreamPlayer3D.new()
	_audio_slide.stream = slide_sound
	_audio_slide.autoplay = false
	_audio_slide.bus = &"Master" # Or a specific SFX bus if available
	# parameters/looping
	# _audio_slide.parameters_looping = true
	# For older Godot 4 or if parameters/looping is used:
	slide_sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	add_child(_audio_slide)

	# Setup bonk audio player
	_audio_bonk = AudioStreamPlayer3D.new()
	_audio_bonk.stream = bonk_sound
	_audio_bonk.autoplay = false
	add_child(_audio_bonk)

	# Ensure RigidBody3D is set up for contact monitoring
	contact_monitor = true
	if max_contacts_reported < 3:
		max_contacts_reported = 3
	
	body_entered.connect(_on_body_entered)

func _physics_process(_dt: float) -> void:
		
	var velocity: float = linear_velocity.length()
	
	if velocity > VELOCITY_THRESHOLD:
		if not _audio_slide.playing:
			_audio_slide.play()
		# Adjust volume or pitch based on velocity if desired
		_audio_slide.unit_size = clampf(velocity * 2.0, 1.0, 5.0)
	else:
		if _audio_slide.playing:
			_audio_slide.stop()

func _on_body_entered(body: Node) -> void:
	if body is Player:
		return
		
	# Play bonk sound
	if not _audio_bonk.playing or _audio_bonk.get_playback_position() > 0.1:
		_audio_bonk.pitch_scale = randf_range(0.9, 1.1)
		_audio_bonk.play()
