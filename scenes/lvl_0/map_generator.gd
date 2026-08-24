extends Node

class_name MapGenerator

class Bounds:
	var x0: int
	var y0: int
	var x1: int
	var y1: int

	func _init(_x0: int, _y0: int, _x1: int, _y1: int) -> void:
		x0 = _x0
		y0 = _y0
		x1 = _x1
		y1 = _y1

	func get_width() -> int:
		return maxi(0, x1 - x0)

	func get_height() -> int:
		return maxi(0, y1 - y0)

	func contains(x: int, y: int) -> bool:
		return x >= x0 and x < x1 and y >= y0 and y < y1

class PlotData:
	var x: int
	var y: int
	var color: Color

	func _init(_x: int, _y: int, _color: Color) -> void:
		x = _x
		y = _y
		color = _color

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

static func is_wall(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).b < 0.1

static func is_light(image: Image, x: int, y: int) -> bool:
	return image.get_pixel(x, y).g > 0.9

func _mod_plot_random_black_pixels(bounds: Bounds, cb: Callable, fill_ratio: float) -> void:
	for y: int in range(bounds.y0, bounds.y1):
		for x: int in range(bounds.x0, bounds.x1):
			if randf() < fill_ratio:
				cb.call(PlotData.new(x, y, Color.BLACK))

func _mod_connect_diagonal_black_pixels(bounds: Bounds, cb: Callable, is_wall_callback: Callable) -> void:
	for y: int in range(bounds.y0 + 1, bounds.y1 - 1):
		for x: int in range(bounds.x0 + 1, bounds.x1 - 1):
			if not is_wall_callback.call(x, y):
				var wall_up: bool = is_wall_callback.call(x, y + 1)
				var wall_down: bool = is_wall_callback.call(x, y - 1)
				var wall_left: bool = is_wall_callback.call(x - 1, y)
				var wall_right: bool = is_wall_callback.call(x + 1, y)
				
				if (wall_up && wall_left) || (wall_up && wall_right) || (wall_down && wall_left) || (wall_down && wall_right):
					cb.call(PlotData.new(x, y, Color.BLACK))

func _mod_draw_black_border(bounds: Bounds, cb: Callable) -> void:
	if bounds.get_width() == 0 or bounds.get_height() == 0:
		return
	for x: int in range(bounds.x0, bounds.x1):
		cb.call(PlotData.new(x, bounds.y0, Color.BLACK))
		cb.call(PlotData.new(x, bounds.y1 - 1, Color.BLACK))
	for y: int in range(bounds.y0, bounds.y1):
		cb.call(PlotData.new(bounds.x0, y, Color.BLACK))
		cb.call(PlotData.new(bounds.x1 - 1, y, Color.BLACK))

func _mod_connect_black_pixels(bounds: Bounds, cb: Callable, is_wall_callback: Callable, connection_distance: int, chance: float) -> void:
	if connection_distance > 0:
		for x: int in range(bounds.x0, bounds.x1):
			for y: int in range(bounds.y0, bounds.y1):
				if is_wall_callback.call(x, y):
					if x + connection_distance < bounds.x1 and is_wall_callback.call(x + connection_distance, y):
						if randf() < chance:
							for dx: int in range(1, connection_distance):
								cb.call(PlotData.new(x + dx, y, Color.BLACK))
					if y + connection_distance < bounds.y1 and is_wall_callback.call(x, y + connection_distance):
						if randf() < chance:
							for dy: int in range(1, connection_distance):
								cb.call(PlotData.new(x, y + dy, Color.BLACK))

func _mod_draw_biomes(bounds: Bounds, cb: Callable, biomes: Array) -> void:
	if bounds.get_width() == 0 or bounds.get_height() == 0:
		return
	for biome: MapSettings.BiomeSettings in biomes:
		var count_range: int = biome.count_max - biome.count_min
		var num_circles: int = biome.count_min + (randi() % (count_range + 1) if count_range > 0 else 0)
		for _i: int in range(num_circles):
			var size_range: int = biome.radius_max - biome.radius_min
			var radius: int = biome.radius_min + (randi() % (size_range + 1) if size_range > 0 else 0)
			var center_x: int = bounds.x0 + randi() % bounds.get_width()
			var center_y: int = bounds.y0 + randi() % bounds.get_height()
			_draw_filled_circle(bounds, cb, center_x, center_y, radius, biome.color)

func _mod_place_lights(bounds: Bounds, cb: Callable, is_wall_callback: Callable, lights_grid_size: int, lights_offset_chance: float, lights_offsets: Array[int]) -> void:
	if lights_grid_size <= 0 or bounds.get_width() == 0 or bounds.get_height() == 0:
		return
	for y: int in range(bounds.y0 + (lights_grid_size >> 1), bounds.y1, lights_grid_size):
		for x: int in range(bounds.x0 + (lights_grid_size >> 1), bounds.x1, lights_grid_size):
			var lx: int = x
			var ly: int = y
			if not lights_offsets.is_empty() and randf() < lights_offset_chance:
				lx += lights_offsets[randi() % lights_offsets.size()]
				ly += lights_offsets[randi() % lights_offsets.size()]
			lx = clampi(lx, bounds.x0, bounds.x1 - 1)
			ly = clampi(ly, bounds.y0, bounds.y1 - 1)
			if not is_wall_callback.call(lx, ly):
				cb.call(PlotData.new(lx, ly, Color(0, 1, 1)))


func _mod_ensure_no_enclaves(bounds: Bounds, cb: Callable, is_wall_callback: Callable) -> void:
	var width: int = bounds.get_width()
	var height: int = bounds.get_height()
	var visited: Array = []
	for _x: int in range(width):
		var column: Array = []
		column.resize(height)
		column.fill(false)
		visited.append(column)
	var components: Array = []
	for y: int in range(bounds.y0, bounds.y1):
		for x: int in range(bounds.x0, bounds.x1):
			if not is_wall_callback.call(x, y) and not visited[x - bounds.x0][y - bounds.y0]:
				var component: Array = []
				var queue: Array = [Vector2i(x, y)]
				visited[x - bounds.x0][y - bounds.y0] = true
				while queue.size() > 0:
					var p: Vector2i = queue.pop_front()
					component.append(p)
					for dir: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
						var nx: int = p.x + dir.x
						var ny: int = p.y + dir.y
						if bounds.contains(nx, ny):
							if not is_wall_callback.call(nx, ny) and not visited[nx - bounds.x0][ny - bounds.y0]:
								visited[nx - bounds.x0][ny - bounds.y0] = true
								queue.push_back(Vector2i(nx, ny))
				components.append(component)
	if components.size() <= 1:
		return
	
	# Find the largest component
	var largest_component_idx: int = 0
	var max_size: int = 0
	for i: int in range(components.size()):
		if components[i].size() > max_size:
			max_size = components[i].size()
			largest_component_idx = i
	
	# Fill all other components with black
	for i: int in range(components.size()):
		if i == largest_component_idx:
			continue
		for p: Vector2i in components[i]:
			cb.call(PlotData.new(p.x, p.y, Color.BLACK))

## Generates a black & white maze image.
## White pixels = empty space, Black pixels = walls
func generate_map_image(width: int, height: int, map_seed: int, settings: MapSettings = MapSettings.new()) -> Image:
	seed(map_seed)
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGB8)
	image.fill(Color(0, 0, 1)) # Start with all white canvas
	var bounds: Bounds = Bounds.new(0, 0, width, height)
	var cb: Callable = func(data: PlotData) -> void:
		image.set_pixel(data.x, data.y, data.color)
	var is_wall_callback: Callable = func(x: int, y: int) -> bool:
		return is_wall(image, x, y)
	_mod_plot_random_black_pixels(bounds, cb, settings.fill_ratio)
	_mod_connect_diagonal_black_pixels(bounds, cb, is_wall_callback)
	_mod_connect_black_pixels(bounds, cb, is_wall_callback, settings.connection_distance, settings.connection_chance)
	_mod_draw_black_border(bounds, cb)
	_mod_ensure_no_enclaves(bounds, cb, is_wall_callback)
	_mod_place_lights(bounds, cb, is_wall_callback, settings.lights_grid_size, settings.lights_offset_chance, settings.lights_offsets)
	return image

func generate_map(width: int, height: int, map_seed: int, debug_png_filename: String, settings: MapSettings = MapSettings.new()) -> void:
	var image: Image = generate_map_image(width, height, map_seed, settings)
	# Save image
	var err := image.save_png(debug_png_filename)
	if err != OK:
		push_error("Failed to save maze image: " + str(err))

func _connect_rooms(bounds: Bounds, cb: Callable, r1: Rect2i, r2: Rect2i, settings: MapSettings) -> void:
	var p1: Vector2i = r1.get_center()
	var p2: Vector2i = r2.get_center()

	var h_width: int = settings.hallway_min_width
	if settings.hallway_max_width > settings.hallway_min_width:
		h_width = (randi() % (settings.hallway_max_width - settings.hallway_min_width + 1)) + settings.hallway_min_width

	_carve_hallway(bounds, cb, p1, p2, h_width)

func _carve_hallway(bounds: Bounds, cb: Callable, p1: Vector2i, p2: Vector2i, width: int) -> void:
	# Horizontal then vertical or vice versa
	if randi() % 2 == 0:
		_carve_line(bounds, cb, Vector2i(p1.x, p1.y), Vector2i(p2.x, p1.y), width)
		_carve_line(bounds, cb, Vector2i(p2.x, p1.y), Vector2i(p2.x, p2.y), width)
	else:
		_carve_line(bounds, cb, Vector2i(p1.x, p1.y), Vector2i(p1.x, p2.y), width)
		_carve_line(bounds, cb, Vector2i(p1.x, p2.y), Vector2i(p2.x, p2.y), width)

func _carve_line(bounds: Bounds, cb: Callable, start: Vector2i, end: Vector2i, line_width: int) -> void:
	var x_start: int = mini(start.x, end.x)
	var x_end: int = maxi(start.x, end.x)
	var y_start: int = mini(start.y, end.y)
	var y_end: int = maxi(start.y, end.y)
	
	var offset: int = line_width >> 1

	for x: int in range(x_start - offset, x_end + (line_width - offset)):
		for y: int in range(y_start - offset, y_end + (line_width - offset)):
			if bounds.contains(x, y):
				cb.call(PlotData.new(x, y, Color.BLACK))

func _draw_filled_circle(bounds: Bounds, cb: Callable, center_x: int, center_y: int, radius: int, color: Color) -> void:
	var r2: int = radius * radius
	for x: int in range(center_x - radius, center_x + radius + 1):
		for y: int in range(center_y - radius, center_y + radius + 1):
			if bounds.contains(x, y):
				var dx: int = x - center_x
				var dy: int = y - center_y
				if dx * dx + dy * dy <= r2:
					cb.call(PlotData.new(x, y, color))
