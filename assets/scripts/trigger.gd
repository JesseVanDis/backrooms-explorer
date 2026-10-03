extends Area3D
class_name Trigger

enum Mode {
	None,
	PlayerVoice,
}

@export var mode: Mode = Mode.None
## If empty, it will use the player as default.
@export var trigger_object: Node3D = null
@export var sounds: Array[AudioStream] = []
@export var play_once: bool = true

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
			push_error("Player not found in trigger_sfx.gd")
			return
		
		target_trigger = _player
		
	if body != target_trigger:
		return
		
	print("Body entered: " + body.name + ". ")
	
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
		
		Mode.PlayerVoice:
			if _player == null:
				_player = UtilsNode.find_player(get_tree())
			
			if _player != null:
				_player.active_voice_sequence = sounds.duplicate()
			else:
				push_error("Player not found for PlayerVoice mode in trigger_sfx.gd")
				
	_has_played = true
	
	
