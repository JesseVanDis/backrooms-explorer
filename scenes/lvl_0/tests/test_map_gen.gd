extends SceneTree

func _init() -> void:
	print("Starting MapGenerator test...")
	var gen_script: GDScript = load("res://scenes/lvl_0/map_generator.gd")
	if not gen_script:
		push_error("Failed to load map_generator.gd")
		quit(1)
		return

	var gen: MapGenerator = gen_script.new()
	var image: Image = gen.generate_map_image(512, 512)
	var err := image.save_png("res://scenes/lvl_0/tests/result.png")
	if err != OK:
		push_error("Failed to save maze image: " + str(err))
		
	quit(0)
