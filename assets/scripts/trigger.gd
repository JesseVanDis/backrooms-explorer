extends Area3D
class_name Trigger

enum Mode {
	None,
	PlayerVoice_Replace,
	PlayerVoice_PushBack,
	PlayerVoice_PushFront,
}

enum Condition {
	None,
	PlayerLookAtNode,
}


@export var mode: Mode = Mode.None
## If empty, it will use the player as default.
@export var trigger_object: Node3D = null
@export var sounds: Array[AudioStream] = []
@export var trigger_delay_ms: int = 0

@export_group("Condition")
@export var condition: Condition = Condition.None
@export var condition_arg_node: Node3D = null

var _has_triggered: bool = false
var _audio_player: AudioStreamPlayer3D = null
var _player: Player = null
var _is_target_inside: bool = false

func get_player() -> Player:
	if _player == null:
		_player = UtilsNode.find_player(get_tree())
	if _player == null:
		push_error("Player not found in trigger.gd")
	return _player

func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	if condition == Condition.PlayerLookAtNode && condition_arg_node == null:
		push_error("condition Condition.PlayerLookAtNode requires a valid condition_arg_node")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_exited(body: Node3D) -> void:
	var target_trigger: Node3D = trigger_object
	if target_trigger == null:
		target_trigger = get_player()
	if body == target_trigger:
		_is_target_inside = false

func _on_body_entered(body: Node3D) -> void:
	var target_trigger: Node3D = trigger_object
	if target_trigger == null:
		target_trigger = get_player()
	if body == target_trigger:
		_is_target_inside = true

func _process(_delta: float) -> void:
	if _has_triggered:
		return
	
	var trigger: bool = false
	
	match condition:
		Condition.None:
			if _is_target_inside:
				trigger = true
		
		Condition.PlayerLookAtNode:
			if _is_target_inside:
				var camera: Camera3D = UtilsNode.find_camera_recursive(get_player())
				var to_node: Vector3 = (condition_arg_node.global_position - camera.global_position).normalized()
				var forward: Vector3 = -camera.global_basis.z
				var dot: float = forward.dot(to_node)
				if dot > 0.85: # Approximately 30 degrees
					trigger = true
	
	if trigger:
		_has_triggered = true
		await _trigger()


func _trigger() -> void:
	if trigger_delay_ms > 0:
		await get_tree().create_timer(trigger_delay_ms / 1000.0).timeout

	match mode:
		Mode.None:
			if sounds.size() == 0:
				pass
			elif sounds.size() == 1:
				var target_player: AudioStreamPlayer3D = _audio_player
				_audio_player.stream = sounds.front()
				target_player.play()
			else:
				push_error("Non-voice sound sequence not implemented yet.")
		
		Mode.PlayerVoice_Replace:
			get_player().replace_voice(sounds)
		
		Mode.PlayerVoice_PushBack:
			get_player().push_back_voice(sounds)
				
		Mode.PlayerVoice_PushFront:
			get_player().push_front_voice(sounds)
	
	
