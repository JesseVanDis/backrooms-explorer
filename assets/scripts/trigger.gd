extends Area3D
class_name Trigger

enum Mode {
	None,
	PlayerVoice_Replace,
	PlayerVoice_PushBack,
	PlayerVoice_PushFront,
}

@export var mode: Mode = Mode.None
## If empty, it will use the player as default.
@export var trigger_object: Node3D = null
@export var sounds: Array[AudioStream] = []
@export var play_once: bool = true
@export var trigger_delay_ms: int = 0

var _has_played: bool = false
var _audio_player: AudioStreamPlayer3D = null
var _player: Player = null

func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if play_once and _has_played:
		return
	
	var target_trigger: Node3D = trigger_object
	if target_trigger == null:
		if _player == null:
			_player = UtilsNode.find_player(get_tree())
		
		if _player == null:
			push_error("Player not found in trigger.gd")
			return
		
		target_trigger = _player
		
	if body != target_trigger:
		return
		
	print("Body entered: " + body.name + ". ")

	if play_once:
		_has_played = true

	if trigger_delay_ms > 0:
		await get_tree().create_timer(trigger_delay_ms / 1000.0).timeout
	
	_trigger()

func _trigger() -> void:
	if _player == null:
		_player = UtilsNode.find_player(get_tree())
	
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
			_player.replace_voice(sounds)
		
		Mode.PlayerVoice_PushBack:
			_player.push_back_voice(sounds)
				
		Mode.PlayerVoice_PushFront:
			_player.push_front_voice(sounds)
	
	
