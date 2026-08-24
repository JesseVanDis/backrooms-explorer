extends Node3D

@onready var map_node = $Map

const floor_scene = preload("res://scenes/lvl_0/part_1x1_floor.tscn")
const ceiling_scene = preload("res://scenes/lvl_0/part_1x1_ceiling.tscn")
const wall_scene = preload("res://scenes/lvl_0/part_1x1_wall.tscn")
const ceiling_light_scene = preload("res://scenes/lvl_0/part_1x1_ceiling_light.tscn")

const tile_size = 1.0

var map: MapGenerator.Section

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Clear existing map children
	#for child in map_node.get_children():
	#	child.queue_free()
	
	generate_level()
		
	# Find a spawn point (white pixel)
	var spawn_pos = _find_spawn_point()
	
	$Player.transform.origin = Vector3(spawn_pos.x * tile_size, 0.0, spawn_pos.y * tile_size)
	# Also reset rotation to avoid looking at the floor or something
	$Player.rotation = Vector3.ZERO

func generate_level() -> void:
	const radius = 64
		
	var place_tile: Callable = func(x: int, y: int, tile_pos: Vector3, tile_type: MapGenerator.TileType) -> void:
		# ALWAYS add a floor and ceiling
		var floor_inst   = floor_scene.instantiate()
		var ceiling_inst = ceiling_scene.instantiate()
		map_node.add_child(floor_inst)
		map_node.add_child(ceiling_inst)
		floor_inst.transform.origin = tile_pos
		ceiling_inst.transform.origin = tile_pos

		# now what to put there...
		match tile_type:
			MapGenerator.TileType.EMPTY:
				# do nothing
				return
			MapGenerator.TileType.CEILING_LIGHT:
				var ceiling_light_inst = ceiling_light_scene.instantiate()
				map_node.add_child(ceiling_light_inst)
				ceiling_light_inst.transform.origin = tile_pos
				
			MapGenerator.TileType.WALL:
				pass

	var generator = MapGenerator.new();

	map = generator.generate_map(-radius, -radius, radius, radius)	
	for y in range(map.y, map.y + map.h):
		for x in range(map.x, map.x + map.w):
			place_tile.call(x, y, Vector3(x,0,y), map.get_tile(x, y));

	
	#
	#var image = MapGenerator.new().generate_map_image(width, height, 1234) #randi())
	#
	#for x in range(width):
		#for z in range(height):
			#var is_wall = MapGenerator.is_wall(image, x, z);
			#var is_light = MapGenerator.is_light(image, x, z);
			#
			#var pos = Vector3(x * tile_size, 0, z * tile_size)
			#
			## Floor and Ceiling for every pixel
			#var floor_inst = floor_scene.instantiate()
			#map_node.add_child(floor_inst)
			#floor_inst.transform.origin = pos
			#
			#var ceiling_inst = ceiling_scene.instantiate()
			#map_node.add_child(ceiling_inst)
			#ceiling_inst.transform.origin = pos
			#
			#if is_light:
				#var ceiling_light_inst = ceiling_light_scene.instantiate()
				#map_node.add_child(ceiling_light_inst)
				#ceiling_light_inst.transform.origin = pos
				#
			#
			#if is_wall: # Check neighbors for walls
				#_check_and_add_wall(image, x, z, x + 1, z, -PI/2, Vector3(tile_size/2, 0, 0)) # Right
				#_check_and_add_wall(image, x, z, x - 1, z, PI/2, Vector3(-tile_size/2, 0, 0)) # Left
				#_check_and_add_wall(image, x, z, x, z + 1, PI, Vector3(0, 0, tile_size/2)) # Back
				#_check_and_add_wall(image, x, z, x, z - 1, 0, Vector3(0, 0, -tile_size/2)) # Front
	

#func _check_and_add_wall(image: Image, x: int, z: int, nx: int, nz: int, angle: float, offset: Vector3):
	#var width: int  = image.get_width()
	#var height: int = image.get_height()
	#
	#var is_neighbor_empty: bool = true
	#if nx >= 0 and nx < width and nz >= 0 and nz < height:
		#if MapGenerator.is_wall(image, nx, nz):
			#is_neighbor_empty = false
	#
	#if is_neighbor_empty:
		#var wall_inst: Node3D = wall_scene.instantiate()
		#map_node.add_child(wall_inst)
		#wall_inst.transform.origin = Vector3(x * tile_size, 0, z * tile_size) + offset
		#wall_inst.rotate_y(angle)
#
func _find_spawn_point() -> Vector2i:
	for y in range(map.y, map.y + map.h):
		for x in range(map.x, map.x + map.w):
			if map.get_tile(x, y) != MapGenerator.TileType.WALL:
				return Vector2i(x, y)
	return Vector2i(1, 1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
