extends Node

class_name SoundController

const RAYTRACED_REVERB_BUS_NAME: StringName = &"RaytracedReverb"

const DEFAULT_ROOM_SIZE: float = 1.0
const DEFAULT_DAMPING: float = 0.5
const DEFAULT_SPREAD: float = 1.0
const DEFAULT_HIGH_PASS: float = 1.0
const DEFAULT_DRY: float = 1.0
const DEFAULT_WET: float = 0.5
const DEFAULT_PREDELAY_MSEC: float = 150.0
const DEFAULT_PREDELAY_FEEDBACK: float = 0.4

@export_group("Reverb Options")
@export var reverb_enabled: bool = false:
	set(value):
		reverb_enabled = value
		_update_sound_settings()
	
@export_range(0.0, 1.0) var room_size: float = DEFAULT_ROOM_SIZE:
	set(value):
		room_size = value
		_update_sound_settings()

@export_range(0.0, 1.0) var damping: float = DEFAULT_DAMPING:
	set(value):
		damping = value
		_update_sound_settings()

@export_range(0.0, 1.0) var spread: float = DEFAULT_SPREAD:
	set(value):
		spread = value
		_update_sound_settings()

@export_range(0.0, 1.0) var high_pass: float = DEFAULT_HIGH_PASS:
	set(value):
		high_pass = value
		_update_sound_settings()

@export_range(0.0, 1.0) var dry: float = DEFAULT_DRY:
	set(value):
		dry = value
		_update_sound_settings()

@export_range(0.0, 1.0) var wet: float = DEFAULT_WET:
	set(value):
		wet = value
		_update_sound_settings()

@export_range(0.0, 500.0) var predelay_msec: float = DEFAULT_PREDELAY_MSEC:
	set(value):
		predelay_msec = value
		_update_sound_settings()

@export_range(0.0, 1.0) var predelay_feedback: float = DEFAULT_PREDELAY_FEEDBACK:
	set(value):
		predelay_feedback = value
		_update_sound_settings()

var _is_ready: bool = false

func _ready() -> void:
	_is_ready = true
	print("Sound controller STARTED")
	_update_sound_settings()

func _exit_tree() -> void:
	_reset_to_defaults()
	print("Sound controller KILLED")

func _update_sound_settings() -> void:
	if not _is_ready:
		return
		
	if not is_inside_tree():
		return
		
	var bus_index := AudioServer.get_bus_index(RAYTRACED_REVERB_BUS_NAME)
	if bus_index == -1:
		push_error("AudioBus 'RaytracedReverb' not found.")
		return
	
	AudioServer.set_bus_effect_enabled(bus_index, 0, reverb_enabled)
	
	var effect := AudioServer.get_bus_effect(bus_index, 0)
	if effect == null:
		push_error("AudioEffect at index 0 on bus 'RaytracedReverb' is null.")
		return
	
	var reverb_effect := effect as AudioEffectReverb
	if reverb_effect == null:
		push_error("AudioEffect at index 0 on bus 'RaytracedReverb' is not an AudioEffectReverb.")
		return
		
	reverb_effect.room_size = room_size
	reverb_effect.damping = damping
	reverb_effect.spread = spread
	reverb_effect.hipass = high_pass
	reverb_effect.dry = dry
	reverb_effect.wet = wet
	reverb_effect.predelay_msec = predelay_msec
	reverb_effect.predelay_feedback = predelay_feedback

func _reset_to_defaults() -> void:
	var bus_index := AudioServer.get_bus_index(RAYTRACED_REVERB_BUS_NAME)
	if bus_index == -1:
		push_error("AudioBus 'RaytracedReverb' not found.")
		return
		
	AudioServer.set_bus_effect_enabled(bus_index, 0, false)
	
	var effect := AudioServer.get_bus_effect(bus_index, 0)
	if effect == null:
		push_error("AudioEffect at index 0 on bus 'RaytracedReverb' is null.")
		return
	
	var reverb_effect := effect as AudioEffectReverb
	if reverb_effect == null:
		push_error("AudioEffect at index 0 on bus 'RaytracedReverb' is not an AudioEffectReverb.")
		return
	
	# Godot default values for AudioEffectReverb
	reverb_effect.room_size = DEFAULT_ROOM_SIZE
	reverb_effect.damping = DEFAULT_DAMPING
	reverb_effect.spread = DEFAULT_SPREAD
	reverb_effect.hipass = DEFAULT_HIGH_PASS
	reverb_effect.dry = DEFAULT_DRY
	reverb_effect.wet = DEFAULT_WET
	reverb_effect.predelay_msec = DEFAULT_PREDELAY_MSEC
	reverb_effect.predelay_feedback = DEFAULT_PREDELAY_FEEDBACK
