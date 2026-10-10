extends CanvasLayer
class_name IngameUI

var _viewport: SubViewport
var _subtitles: PlayerSubtitles
@onready var _3d_display: Sprite2D = $_3d_display

func _get_subtitles() -> PlayerSubtitles:
	if _subtitles == null:
		_subtitles = $_subtitles
	return _subtitles

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_get_subtitles()
	if _viewport == null:
		_viewport = _find_viewport()
	if _viewport == null:
		push_error("Failed to find viewport.")
	_3d_display.texture = _viewport.get_texture()

func setup(audio_player: AudioStreamPlayer3D) -> void:
	_get_subtitles().setup(audio_player)

func play_subtitles(srt_path: String) -> void:
	_get_subtitles().play_subtitles(srt_path)

func stop_subtitles() -> void:
	_get_subtitles().stop_subtitles()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _find_viewport() -> SubViewport:
	var current: Node = self
	while current != null:
		if current is SubViewport:
			return current as SubViewport
		for node in current.find_children("*", "Viewport", true, false):
			if node is SubViewport:
				return node as SubViewport
		current = current.get_parent()
	push_error("Viewport not found!")
	return null
