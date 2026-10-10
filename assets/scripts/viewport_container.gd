extends SubViewportContainer

@onready var viewport: SubViewport = $_viewport

func _ready() -> void:
	resized.connect(_on_resized)
	_on_resized()

func _on_resized() -> void:
	viewport.size = Vector2i(size)
