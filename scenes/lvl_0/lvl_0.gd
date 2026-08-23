extends Node3D

@onready var map_node = $Map

const floor_scene = preload("res://scenes/lvl_0/part_1x1_floor.tscn")
const ceiling_scene = preload("res://scenes/lvl_0/part_1x1_ceiling.tscn")
const wall_scene = preload("res://scenes/lvl_0/part_1x1_wall.tscn")

const tile_size = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Clear existing map children
	#for child in map_node.get_children():
	#	child.queue_free()
	
	var image = generate_level()
		
	# Find a spawn point (white pixel)
	var spawn_pos = _find_spawn_point(image)
	
	$Player.transform.origin = Vector3(spawn_pos.x * tile_size, 0.0, spawn_pos.y * tile_size)
	# Also reset rotation to avoid looking at the floor or something
	$Player.rotation = Vector3.ZERO

func generate_level() -> Image:
	const width = 64
	const height = 64
	
	var image = MapGenerator.new().generate_map_image(width, height, randi())
	
	for x in range(width):
		for z in range(height):
			var pixel = image.get_pixel(x, z)
			var is_wall = pixel.r < 0.1
			
			var pos = Vector3(x * tile_size, 0, z * tile_size)
			
			# Floor and Ceiling for every pixel
			var floor_inst = floor_scene.instantiate()
			map_node.add_child(floor_inst)
			floor_inst.transform.origin = pos
			# floor_inst.scale = Vector3(pixel_size, 1, pixel_size)
			
			var ceil_inst = ceiling_scene.instantiate()
			map_node.add_child(ceil_inst)
			ceil_inst.transform.origin = pos
			# ceil_inst.scale = Vector3(pixel_size, 1, pixel_size)
			
			if is_wall: # Check neighbors for walls
				_check_and_add_wall(image, x, z, x + 1, z, -PI/2, Vector3(tile_size/2, 0, 0)) # Right
				_check_and_add_wall(image, x, z, x - 1, z, PI/2, Vector3(-tile_size/2, 0, 0)) # Left
				_check_and_add_wall(image, x, z, x, z + 1, PI, Vector3(0, 0, tile_size/2)) # Back
				_check_and_add_wall(image, x, z, x, z - 1, 0, Vector3(0, 0, -tile_size/2)) # Front
	
	return image

func _check_and_add_wall(image: Image, x: int, z: int, nx: int, nz: int, rotation: float, offset: Vector3):
	var width: int  = image.get_width()
	var height: int = image.get_height()
	
	var is_neighbor_empty: bool = true
	if nx >= 0 and nx < width and nz >= 0 and nz < height:
		var neighbor_pixel = image.get_pixel(nx, nz)
		if neighbor_pixel.r < 0.1: # Neighbor is also a wall
			is_neighbor_empty = false
	
	if is_neighbor_empty:
		var wall_inst: Node3D = wall_scene.instantiate()
		map_node.add_child(wall_inst)
		wall_inst.transform.origin = Vector3(x * tile_size, 0, z * tile_size) + offset
		wall_inst.rotate_y(rotation)

func _find_spawn_point(image: Image) -> Vector2i:
	for x in range(image.get_width()):
		for z in range(image.get_height()):
			if image.get_pixel(x, z).r > 0.9:
				return Vector2i(x, z)
	return Vector2i(1, 1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
