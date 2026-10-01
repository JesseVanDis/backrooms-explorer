extends Area3D

enum Mode {
	None,
	PlayerVoice,
}

@export var mode: Mode = Mode.None
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
	
	if _player == null:
		_player = UtilsNode.find_player(get_tree())
	
	if _player == null:
		push_error("Player not found in trigger_sfx.gd")
		return
		
	if body != _player:
		return
	
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
			_player.active_voice_sequence = sounds.duplicate()
				
	_has_played = true
	
	
