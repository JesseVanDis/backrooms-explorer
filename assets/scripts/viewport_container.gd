extends SubViewportContainer

@onready var viewport: SubViewport = $_viewport

func _ready() -> void:
	pass
	#resized.connect(_on_resized)
	#_on_resized()

#func _on_resized() -> void:
	#var new_size := Vector2i(size)
	#if viewport.size != new_size:
	#	viewport.size = new_size
	
	#print("Window: ", get_window().size)
	#print("Container: ", size)
	#print("Viewport: ", viewport.size)
