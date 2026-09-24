extends Node3D

enum LightMode {
	ON,
	BLINKING,
	OFF
}

@export var mode: LightMode = LightMode.ON

@onready var _emission_node: Node3D = $_base/_emission
@onready var _light_node: Node3D = $OmniLight3D
@onready var _casing_node: Node3D = $_base/_casing

const BLINK_INTERVAL_MIN: float = 0.05
const BLINK_INTERVAL_MAX: float = 0.5

var _blinking_timer: float = 0.0
var _is_on: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if _emission_node == null:
		push_error("_emission_node is null")
	if _light_node == null:
		push_error("_light_node is null")
	if _casing_node == null:
		push_error("_casing_node is null")
	
	_update_light_state()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(dt: float) -> void:
	if mode == LightMode.BLINKING:
		_blinking_timer -= dt
		if _blinking_timer <= 0.0:
			_is_on = not _is_on
			_apply_visibility(_is_on)
			_blinking_timer = randf_range(BLINK_INTERVAL_MIN, BLINK_INTERVAL_MAX)
	elif mode == LightMode.ON:
		if not _is_on:
			_is_on = true
			_apply_visibility(true)
	elif mode == LightMode.OFF:
		if _is_on:
			_is_on = false
			_apply_visibility(false)

func _update_light_state() -> void:
	match mode:
		LightMode.ON:
			_is_on = true
		LightMode.OFF:
			_is_on = false
		LightMode.BLINKING:
			_is_on = randf() > 0.5
			_blinking_timer = randf_range(BLINK_INTERVAL_MIN, BLINK_INTERVAL_MAX)
	
	_apply_visibility(_is_on)

func _apply_visibility(should_be_on: bool) -> void:
	if _emission_node != null:
		_emission_node.visible = should_be_on
	if _light_node != null:
		_light_node.visible = should_be_on
	if _casing_node != null:
		_casing_node.visible = not should_be_on
