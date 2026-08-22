extends Node

class_name MapGenerator

class MapSettings:
	var room_iterations: int = 50
	var room_min_size: int = 3
	var room_max_size: int = 7
	var hallway_min_width: int = 1
	var hallway_max_width: int = 1
	var room_margin: int = 1
	var dead_end_ratio: float = 0.5 # 0.0 = all rooms connected in a loop/dense, 1.0 = tree (max dead ends)
	var fill_ratio: float = 0.1
	var connection_distance: int = 4
	var connection_chance: float = 0.5

	func _init(_room_iterations: int = 50, _room_min_size: int = 3, _room_max_size: int = 7, _hallway_min_width: int = 1, _hallway_max_width: int = 1, _room_margin: int = 1, _dead_end_ratio: float = 0.5, _fill_ratio: float = 0.1, _connection_distance: int = 4, _connection_chance: float = 0.5):
		room_iterations = _room_iterations
		room_min_size = _room_min_size
		room_max_size = _room_max_size
		hallway_min_width = _hallway_min_width
		hallway_max_width = _hallway_max_width
		room_margin = _room_margin
		dead_end_ratio = _dead_end_ratio
		fill_ratio = _fill_ratio
		connection_distance = _connection_distance
		connection_chance = _connection_chance

## Generates a black & white maze PNG.
## black background (0.0), white pixels = walls (1.0)
## Wait, the user wants white background and black lines.
## "i want to see more white than black"
## So: White background (1.0), Black pixels = walls (0.0)
func generate_map(width: int, height: int, map_seed: int, debug_png_filename: String, settings: MapSettings = MapSettings.new()) -> void:
	seed(map_seed)
	# Create image
	var image := Image.create(width, height, false, Image.FORMAT_L8)
	image.fill(Color.WHITE) # Start with all white canvas

	for x in range(width):
		for y in range(height):
			if randf() < settings.fill_ratio:
				# Check for diagonal neighbors
				# Diagonals are (x-1, y-1), (x+1, y-1), (x-1, y+1), (x+1, y+1)
				# Since we are iterating from (0,0) to (width, height), we only need to check
				# (x-1, y-1) and (x+1, y-1) because (x-1, y+1) and (x+1, y+1) haven't been processed yet.
				# If we find a diagonal, we 'merge' them by adding a pixel to any of left, right, up, bottom
				
				image.set_pixel(x, y, Color.BLACK)
				
				if x > 0 and y > 0 and image.get_pixel(x - 1, y - 1).r < 0.5:
					# Diagonal conflict with (x-1, y-1)
					# Orthogonal neighbors between (x,y) and (x-1, y-1) are (x-1, y) and (x, y-1)
					if randi() % 2 == 0:
						image.set_pixel(x - 1, y, Color.BLACK)
					else:
						image.set_pixel(x, y - 1, Color.BLACK)
				
				if x < width - 1 and y > 0 and image.get_pixel(x + 1, y - 1).r < 0.5:
					# Diagonal conflict with (x+1, y-1)
					# Orthogonal neighbors between (x,y) and (x+1, y-1) are (x+1, y) and (x, y-1)
					if randi() % 2 == 0:
						image.set_pixel(x + 1, y, Color.BLACK)
					else:
						image.set_pixel(x, y - 1, Color.BLACK)

	# 2. Connect pixels distance away
	var dist = settings.connection_distance
	if dist > 0:
		for x in range(width):
			for y in range(height):
				if image.get_pixel(x, y).r < 0.5:
					# Try to connect Right
					if x + dist < width and image.get_pixel(x + dist, y).r < 0.5:
						if randf() < settings.connection_chance:
							for dx in range(1, dist):
								image.set_pixel(x + dx, y, Color.BLACK)
					
					# Try to connect Down
					if y + dist < height and image.get_pixel(x, y + dist).r < 0.5:
						if randf() < settings.connection_chance:
							for dy in range(1, dist):
								image.set_pixel(x, y + dy, Color.BLACK)

	# Save image
	var err := image.save_png(debug_png_filename)
	if err != OK:
		push_error("Failed to save maze image: " + str(err))

func _connect_rooms(image: Image, r1: Rect2i, r2: Rect2i, settings: MapSettings) -> void:
	var p1 = r1.get_center()
	var p2 = r2.get_center()

	var h_width = settings.hallway_min_width
	if settings.hallway_max_width > settings.hallway_min_width:
		h_width = (randi() % (settings.hallway_max_width - settings.hallway_min_width + 1)) + settings.hallway_min_width

	_carve_hallway(image, p1, p2, h_width)

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
				image.set_pixel(x, y, Color.BLACK)
