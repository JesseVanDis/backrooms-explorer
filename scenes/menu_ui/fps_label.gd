## [AI-DOC] Label that displays the current engine frame rate in the in-game UI
## spec: docs/ai/systems/ui_subtitles.md
## status: implemented

extends Label

const FPS_PREFIX: String = "FPS: "


# Keeps the displayed frame rate current while the in-game UI is visible.
func _process(_delta: float) -> void:
	text = FPS_PREFIX + str(Engine.get_frames_per_second())