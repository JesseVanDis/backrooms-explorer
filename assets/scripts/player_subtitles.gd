extends Label
class_name PlayerSubtitles

var _subtitles: Array[Dictionary] = []
var _current_subtitle_index: int = 0
var _audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	set_process(false)

func setup(audio_player: AudioStreamPlayer3D) -> void:
	_audio_player = audio_player
	if _audio_player == null:
		push_error("_audio_player is null")

func play_subtitles(srt_path: String) -> void:
	_subtitles = _parse_srt(srt_path)
	_current_subtitle_index = 0
	text = ""
	
	if _subtitles.is_empty():
		set_process(false)
	else:
		set_process(true)

func stop_subtitles() -> void:
	_subtitles = []
	_current_subtitle_index = 0
	text = ""
	set_process(false)

func _process(_delta: float) -> void:
	if _audio_player == null or not _audio_player.playing or _subtitles.is_empty():
		text = ""
		set_process(false)
		return
	
	var current_time: float = _audio_player.get_playback_position()
	
	# Update subtitle text based on current time
	var found_sub: bool = false
	for i in range(_subtitles.size()):
		var sub: Dictionary = _subtitles[i]
		if current_time >= sub.start and current_time <= sub.end:
			text = sub.text
			found_sub = true
			_current_subtitle_index = i
			break
	
	if not found_sub:
		text = ""

func _parse_srt(path: String) -> Array[Dictionary]:
	var subs: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		# It's possible that the subtitle file doesn't exist for every voice line
		return subs
		
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open subtitle file: " + path)
		return subs
		
	var content: String = file.get_as_text()
	file.close()
	
	var regex: RegEx = RegEx.new()
	# SRT format:
	# index
	# start --> end
	# text
	# (empty line)
	regex.compile("(\\d+)\\n(\\d{2}:\\d{2}:\\d{2},\\d{3}) --> (\\d{2}:\\d{2}:\\d{2},\\d{3})\\n([\\s\\S]*?)(?=\\n\\d+\\n|\\Z)")
	
	var matches: Array[RegExMatch] = regex.search_all(content)
	for m in matches:
		var sub: Dictionary = {
			"start": _time_to_float(m.get_string(2)),
			"end": _time_to_float(m.get_string(3)),
			"text": m.get_string(4).strip_edges()
		}
		subs.append(sub)
		
	return subs

func _time_to_float(time_str: String) -> float:
	var parts: PackedStringArray = time_str.replace(",", ".").split(":")
	if parts.size() != 3:
		return 0.0
	var hours: float = parts[0].to_float()
	var minutes: float = parts[1].to_float()
	var seconds: float = parts[2].to_float()
	return hours * 3600.0 + minutes * 60.0 + seconds
