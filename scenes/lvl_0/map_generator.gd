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
	var lights_grid_size: int = 5
	var lights_offset_chance: float = 0.1
	var lights_offsets: Array[int] = [-2, -1, 1, 2]

	class BiomeSettings:
		var count_min: int = 5
		var count_max: int = 10
		var radius_min: int = 20
		var radius_max: int = 80
		var color: Color = Color.KHAKI

		func _init(_color: Color = Color.KHAKI, _c_min: int = 5, _c_max: int = 10, _r_min: int = 20, _r_max: int = 80):
			color = _color
			count_min = _c_min
			count_max = _c_max
			radius_min = _r_min
			radius_max = _r_max

	var biomes: Array = [
		BiomeSettings.new(Color.KHAKI),
		BiomeSettings.new(Color.PALE_GOLDENROD)
	]

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

static func is_wall(image: Image, x: int, y: int):
	return image.get_pixel(x, y).b < 0.1

static func is_light(image: Image, x: int, y: int):
	return image.get_pixel(x, y).g > 0.9

func _mod_plot_random_black_pixels(image: Image, fill_ratio: float):
	var height: int = image.get_height();
	var width:  int = image.get_width();
	for y in range(height):
		for x in range(width):
			if randf() < fill_ratio:
				image.set_pixel(x, y, Color.BLACK)

func _mod_connect_diagonal_black_pixels(image: Image):
	var height: int = image.get_height();
	var width:  int = image.get_width();
	for y in range(1, height-1):
		for x in range(1, width-1):
			if ! is_wall(image, x, y):
				var wall_up:    bool = is_wall(image, x, y+1)
				var wall_down:  bool = is_wall(image, x, y-1)
				var wall_left:  bool = is_wall(image, x-1, y)
				var wall_right: bool = is_wall(image, x+1, y)
				
				if (wall_up && wall_left) || (wall_up && wall_right) || (wall_down && wall_left) || (wall_down && wall_right):
					image.set_pixel(x, y, Color.BLACK)

func _mod_draw_black_border(image: Image):
	var height: int = image.get_height();
	var width:  int = image.get_width();
	for x in range(width):
		image.set_pixel(x, 0,        Color.BLACK)
		image.set_pixel(x, height-1, Color.BLACK)
	for y in range(height):
		image.set_pixel(0,       y,  Color.BLACK)
		image.set_pixel(width-1, y,  Color.BLACK)

func _mod_connect_black_pixels(image: Image, connection_distance: int, chance: float):
	var height: int = image.get_height();
	var width:  int = image.get_width();
	if connection_distance > 0:
		for x in range(width):
			for y in range(height):
				if is_wall(image, x, y):
					if x + connection_distance < width and is_wall(image, x + connection_distance, y):
						if randf() < chance:
							for dx in range(1, connection_distance):
								image.set_pixel(x + dx, y, Color.BLACK)					
					if y + connection_distance < height and is_wall(image, x, y + connection_distance):
						if randf() < chance:
							for dy in range(1, connection_distance):
								image.set_pixel(x, y + dy, Color.BLACK)

func _mod_draw_biomes(image: Image, biomes):
	var height: int = image.get_height();
	var width:  int = image.get_width();
	for biome in biomes:
		var count_range = biome.count_max - biome.count_min
		var num_circles = biome.count_min + (randi() % (count_range + 1) if count_range > 0 else 0)
		for i in range(num_circles):
			var size_range = biome.radius_max - biome.radius_min
			var radius = biome.radius_min + (randi() % (size_range + 1) if size_range > 0 else 0)
			var center_x = randi() % width
			var center_y = randi() % height
			_draw_filled_circle(image, center_x, center_y, radius, biome.color)

func _mod_place_lights(image: Image, lights_grid_size: int, lights_offset_chance: float, lights_offsets: Array[int]):
	var height: int = image.get_height()
	var width:  int = image.get_width()
	
	for y in range(lights_grid_size >> 1, height, lights_grid_size):
		for x in range(lights_grid_size >> 1, width, lights_grid_size):
			var lx: int = x
			var ly: int = y
			if randf() < lights_offset_chance:
				lx += lights_offsets[randi() % lights_offsets.size()]
				ly += lights_offsets[randi() % lights_offsets.size()]
			lx = clampi(lx, 0, width - 1)
			ly = clampi(ly, 0, height - 1)
			if not is_wall(image, lx, ly):
				image.set_pixel(lx, ly, Color(0,1,1))


func _mod_ensure_no_enclaves(image: Image):
	var width: int = image.get_width()
	var height: int = image.get_height()
	var visited: Array = []
	for x in range(width):
		var column: Array = []
		column.resize(height)
		column.fill(false)
		visited.append(column)
	var components: Array = []
	for y in range(height):
		for x in range(width):
			if not is_wall(image, x, y) and not visited[x][y]:
				var component: Array = []
				var queue: Array = [Vector2i(x, y)]
				visited[x][y] = true
				while queue.size() > 0:
					var p: Vector2i = queue.pop_front()
					component.append(p)
					for dir in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
						var nx: int = p.x + dir.x
						var ny: int = p.y + dir.y
						if nx >= 0 and nx < width and ny >= 0 and ny < height:
							if not is_wall(image, nx, ny) and not visited[nx][ny]:
								visited[nx][ny] = true
								queue.push_back(Vector2i(nx, ny))
				components.append(component)
	if components.size() <= 1:
		return
	
	# Find the largest component
	var largest_component_idx: int = 0
	var max_size: int = 0
	for i in range(components.size()):
		if components[i].size() > max_size:
			max_size = components[i].size()
			largest_component_idx = i
	
	# Fill all other components with black
	for i in range(components.size()):
		if i == largest_component_idx:
			continue
		for p in components[i]:
			image.set_pixel(p.x, p.y, Color.BLACK)

## Generates a black & white maze image.
## White pixels = empty space, Black pixels = walls
func generate_map_image(width: int, height: int, map_seed: int, settings: MapSettings = MapSettings.new()) -> Image:
	seed(map_seed)
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color(0,0,1)) # Start with all white canvas
	_mod_plot_random_black_pixels(image, settings.fill_ratio)
	_mod_connect_diagonal_black_pixels(image)
	_mod_connect_black_pixels(image, settings.connection_distance, settings.connection_chance)
	_mod_draw_black_border(image);
	_mod_ensure_no_enclaves(image)
	_mod_place_lights(image, settings.lights_grid_size, settings.lights_offset_chance, settings.lights_offsets)
	return image

func generate_map(width: int, height: int, map_seed: int, debug_png_filename: String, settings: MapSettings = MapSettings.new()) -> void:
	var image = generate_map_image(width, height, map_seed, settings)
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
	
	var offset = line_width >> 1

	for x in range(x_start - offset, x_end + (line_width - offset)):
		for y in range(y_start - offset, y_end + (line_width - offset)):
			if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
				image.set_pixel(x, y, Color.BLACK)

func _draw_filled_circle(image: Image, center_x: int, center_y: int, radius: int, color: Color) -> void:
	var r2 = radius * radius
	for x in range(center_x - radius, center_x + radius + 1):
		for y in range(center_y - radius, center_y + radius + 1):
			if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
				var dx = x - center_x
				var dy = y - center_y
				if dx * dx + dy * dy <= r2:
					image.set_pixel(x, y, color)
