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
func _find_spawn_point() -> Vector2i:
	for y in range(map.y, map.y + map.h):
		for x in range(map.x, map.x + map.w):
			if map.get_tile(x, y) != MapGenerator.TileType.WALL:
				return Vector2i(x, y)
	return Vector2i(1, 1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
