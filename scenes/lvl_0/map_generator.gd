extends Node

class_name MapGenerator

class MapSettings:
	var room_iterations: int = 50
	var room_min_size: int = 3
	var room_max_size: int = 7
	var hallway_min_width: int = 1
	var hallway_max_width: int = 1
	var room_margin: int = 1

	func _init(_room_iterations: int = 50, _room_min_size: int = 3, _room_max_size: int = 7, _hallway_min_width: int = 1, _hallway_max_width: int = 1, _room_margin: int = 1):
		room_iterations = _room_iterations
		room_min_size = _room_min_size
		room_max_size = _room_max_size
		hallway_min_width = _hallway_min_width
		hallway_max_width = _hallway_max_width
		room_margin = _room_margin

## Generates a black & white maze PNG.
## white background (1.0), black pixels = walls (0.0)
func generate_map(width: int, height: int, map_seed: int, debug_png_filename: String, settings: MapSettings = MapSettings.new()) -> void:
	seed(map_seed)

	# Create image
	var image := Image.create(width, height, false, Image.FORMAT_L8)
	image.fill(Color.BLACK) # Start with all walls

	# We use a grid system. Cell size is 2 pixels (1 for floor, 1 for wall)
	# To support wider hallways and rooms, we can either:
	# 1. Increase cell size.
	# 2. Use a 1px = 1 unit grid and handle wall thickness differently.

	# Let's go with 1px = 1 unit for more flexibility with room sizes and hallway widths.
	# But the user said "black pixels = walls".

	var rooms: Array[Rect2i] = []

	# 1. Place rooms
	for i in range(settings.room_iterations):
		var w = (randi() % (settings.room_max_size - settings.room_min_size + 1)) + settings.room_min_size
		var h = (randi() % (settings.room_max_size - settings.room_min_size + 1)) + settings.room_min_size
		var x = randi() % (width - w - 2) + 1
		var y = randi() % (height - h - 2) + 1

		var new_room = Rect2i(x, y, w, h)

		var intersects = false
		for other_room in rooms:
			if new_room.grow(settings.room_margin).intersects(other_room):
				intersects = true
				break

		if not intersects:
			rooms.append(new_room)
			# Carve room
			for rx in range(new_room.position.x, new_room.end.x):
				for ry in range(new_room.position.y, new_room.end.y):
					image.set_pixel(rx, ry, Color.WHITE)

	# 2. Connect rooms
	for i in range(rooms.size() - 1):
		var r1 = rooms[i]
		var r2 = rooms[i+1]

		var p1 = r1.get_center()
		var p2 = r2.get_center()

		var h_width = settings.hallway_min_width
		if settings.hallway_max_width > settings.hallway_min_width:
			h_width = (randi() % (settings.hallway_max_width - settings.hallway_min_width + 1)) + settings.hallway_min_width

		_carve_hallway(image, p1, p2, h_width)

	# Save image
	var err := image.save_png(debug_png_filename)
	if err != OK:
		push_error("Failed to save maze image: " + str(err))

func _carve_hallway(image: Image, p1: Vector2i, p2: Vector2i, width: int) -> void:
	var current = p1

	# Horizontal then vertical or vice versa
	if randi() % 2 == 0:
		_carve_line(image, Vector2i(p1.x, p1.y), Vector2i(p2.x, p1.y), width)
		_carve_line(image, Vector2i(p2.x, p1.y), Vector2i(p2.x, p2.y), width)
	else:
		_carve_line(image, Vector2i(p1.x, p1.y), Vector2i(p1.x, p2.y), width)
		_carve_line(image, Vector2i(p1.x, p2.y), Vector2i(p2.x, p2.y), width)

func _carve_line(image: Image, start: Vector2i, end: Vector2i, line_width: int) -> void:
	var x_start = min(start.x, end.x)
	var x_end = max(start.x, end.x)
	var y_start = min(start.y, end.y)
	var y_end = max(start.y, end.y)

	var offset = line_width / 2

	for x in range(x_start - offset, x_end + (line_width - offset)):
		for y in range(y_start - offset, y_end + (line_width - offset)):
			if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
				image.set_pixel(x, y, Color.WHITE)
