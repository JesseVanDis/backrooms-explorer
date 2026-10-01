extends Area3D

enum Mode {
	None,
	PlayerVoice,
}

@export var mode: Mode = Mode.None
@export var sound: AudioStream = null
@export var play_once: bool = true

var _has_played: bool = false
var _audio_player: AudioStreamPlayer3D = null
var _player: Player = null

func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	_audio_player.stream = sound
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if play_once and _has_played:
		return
	
	if _player == null:
		_player = UtilsNode.find_player(get_tree())
	
	if _player == null:
		push_error("Player not found in trigger_sfx.gd")
		return
		
	if body == _player:
		if _audio_player == null:
			push_error("_audio_player is null in trigger_sfx.gd")
			return
		
		var target_player: AudioStreamPlayer3D = _audio_player
		if mode == Mode.PlayerVoice:
			target_player = _player.audio_player_voice
			if target_player == null:
				push_error("Player audio_player is null in trigger_sfx.gd")
				return
			
			if target_player.playing:
				target_player.stop()
			
		target_player.stream = sound
		target_player.play()
		_has_played = true
