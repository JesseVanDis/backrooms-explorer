extends SceneTree

func _init():
	print("Starting MapGenerator test...")
	var gen_script = load("res://scenes/lvl_0/map_generator.gd")
	if not gen_script:
		push_error("Failed to load map_generator.gd")
		quit(1)
		return

	var gen = gen_script.new()

	# Test 1: Default settings
	print("Test 1: Generating map with default settings...")
	gen.generate_map(512, 512, 1234, "res://scenes/lvl_0/tests/test_maze_default.png")

	# Test 2: Custom settings (Large rooms, wide hallways)
	print("Test 2: Generating map with custom settings...")
	var settings = gen_script.MapSettings.new()
	settings.room_iterations = 40
	settings.room_min_size = 5
	settings.room_max_size = 30
	settings.hallway_min_width = 1
	settings.hallway_max_width = 6
	settings.room_margin = 2
	settings.dead_end_ratio = 0.0
	settings.fill_ratio = 0.1
	settings.connection_distance = 6
	settings.connection_chance = 0.5
	
	# Biome settings
	var aquamarine_biome = gen_script.MapSettings.BiomeSettings.new(Color.AQUAMARINE, 2, 3, 20, 30)
	var coral_biome      = gen_script.MapSettings.BiomeSettings.new(Color.CORAL,      20, 30, 10, 15)
	settings.biomes = [aquamarine_biome, coral_biome]

	gen.generate_map(512, 512, 2134, "res://scenes/lvl_0/tests/test_maze_custom.png", settings)

	print("Tests completed successfully. PNGs saved to scenes/lvl_0/tests/")
	quit(0)
