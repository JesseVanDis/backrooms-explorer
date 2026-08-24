extends SceneTree

var _failures: int = 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _init() -> void:
	print("Starting MapGenerator test...")
	var gen_script: GDScript = load("res://scenes/lvl_0/map_generator.gd")
	if not gen_script:
		push_error("Failed to load map_generator.gd")
		quit(1)
		return

	var gen: MapGenerator = gen_script.new()

	print("Test 1: Plot callbacks respect bounds...")
	var plotted_pixels: Dictionary[Vector2i, Color] = {}
	var cb: Callable = func(data: MapGenerator.PlotData) -> void:
		plotted_pixels[Vector2i(data.x, data.y)] = data.color
	var bounds: MapGenerator.Bounds = gen_script.Bounds.new(10, 20, 13, 23)
	gen._carve_line(bounds, cb, Vector2i(9, 21), Vector2i(14, 21), 1)
	_check(plotted_pixels.size() == 3, "Carved line should be clipped to the bounds")
	for point: Vector2i in plotted_pixels:
		_check(bounds.contains(point.x, point.y), "Plot callback received an out-of-bounds point")

	plotted_pixels.clear()
	gen._draw_filled_circle(bounds, cb, 11, 21, 1, Color.CORAL)
	_check(plotted_pixels.size() == 5, "Radius-one circle should plot five pixels")
	_check(plotted_pixels.get(Vector2i(11, 21)) == Color.CORAL, "Plot callback should receive the requested color")

	plotted_pixels.clear()
	var empty_bounds: MapGenerator.Bounds = gen_script.Bounds.new(3, 3, 3, 8)
	gen._draw_filled_circle(empty_bounds, cb, 3, 4, 3, Color.BLACK)
	_check(plotted_pixels.is_empty(), "Empty bounds should not plot pixels")

	# Test 2: Default settings
	print("Test 2: Generating map with default settings...")
	gen.generate_map(512, 512, 1234, "res://scenes/lvl_0/tests/test_maze_default.png")

	# Test 3: Custom settings (Large rooms, wide hallways)
	print("Test 3: Generating map with custom settings...")
	var settings: MapGenerator.MapSettings = gen_script.MapSettings.new()
	# settings.room_iterations = 40
	# settings.room_min_size = 5
	# settings.room_max_size = 30
	# settings.hallway_min_width = 1
	# settings.hallway_max_width = 6
	# settings.room_margin = 2
	# settings.dead_end_ratio = 0.0
	# settings.fill_ratio = 0.1
	# settings.connection_distance = 6
	# settings.connection_chance = 0.5
	
	# Biome settings
	var aquamarine_biome: MapGenerator.MapSettings.BiomeSettings = gen_script.MapSettings.BiomeSettings.new(Color.AQUAMARINE, 2, 3, 20, 30)
	var coral_biome: MapGenerator.MapSettings.BiomeSettings = gen_script.MapSettings.BiomeSettings.new(Color.CORAL, 20, 30, 10, 15)
	settings.biomes = [aquamarine_biome, coral_biome]

	gen.generate_map(512, 512, 2134, "res://scenes/lvl_0/tests/test_maze_custom.png", settings)

	if _failures == 0:
		print("Tests completed successfully. PNGs saved to scenes/lvl_0/tests/")
	quit(_failures)
