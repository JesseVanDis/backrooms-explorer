extends Node3D

@onready var map_node = $Map

const floor_scene: Resource = preload("res://scenes/lvl_0/part_1x1_floor.tscn")
const ceiling_scene: Resource = preload("res://scenes/lvl_0/part_1x1_ceiling.tscn")
const ceiling_light_scene: Resource = preload("res://scenes/lvl_0/part_1x1_ceiling_light.tscn")
const wall_scene_x: Resource = preload("res://scenes/lvl_0/part_wall_x.tscn")
const wall_scene_t: Resource = preload("res://scenes/lvl_0/part_wall_t.tscn")
const wall_scene_i: Resource = preload("res://scenes/lvl_0/part_wall_i.tscn")
const wall_scene_l: Resource = preload("res://scenes/lvl_0/part_wall_l.tscn")
const wall_scene_e: Resource = preload("res://scenes/lvl_0/part_wall_end.tscn")

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

func _place_wall(scene: Resource, pos, angle: float):
	var instance: Node3D = scene.instantiate()
	map_node.add_child(instance)
	instance.transform.origin = pos
	instance.rotate_y(angle)


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
				#_place_wall(wall_scene_x, tile_pos, 0)
				var wall_n = map.get_tile_clamped(x, y+1) == MapGenerator.TileType.WALL
				var wall_s = map.get_tile_clamped(x, y-1) == MapGenerator.TileType.WALL
				var wall_e = map.get_tile_clamped(x+1, y) == MapGenerator.TileType.WALL
				var wall_w = map.get_tile_clamped(x-1, y) == MapGenerator.TileType.WALL
				if	( wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall(wall_scene_x, tile_pos, 0)
				elif( wall_n &&  wall_s &&  wall_e && !wall_w): _place_wall(wall_scene_t, tile_pos, 0)
				elif( wall_n &&  wall_s && !wall_e &&  wall_w): _place_wall(wall_scene_t, tile_pos, PI)
				elif( wall_n &&  wall_s && !wall_e && !wall_w): _place_wall(wall_scene_i, tile_pos, 0)
				elif( wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall(wall_scene_t, tile_pos, -PI/2)
				elif( wall_n && !wall_s &&  wall_e && !wall_w): _place_wall(wall_scene_l, tile_pos, -PI/2)
				elif( wall_n && !wall_s && !wall_e &&  wall_w): _place_wall(wall_scene_l, tile_pos, PI)
				elif( wall_n && !wall_s && !wall_e && !wall_w): _place_wall(wall_scene_e, tile_pos, PI)
				elif(!wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall(wall_scene_t, tile_pos, PI/2)
				elif(!wall_n &&  wall_s &&  wall_e && !wall_w): _place_wall(wall_scene_l, tile_pos, 0)
				elif(!wall_n &&  wall_s && !wall_e &&  wall_w): _place_wall(wall_scene_l, tile_pos, PI/2)
				elif(!wall_n &&  wall_s && !wall_e && !wall_w): _place_wall(wall_scene_e, tile_pos, 0)
				elif(!wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall(wall_scene_i, tile_pos, PI/2)
				elif(!wall_n && !wall_s &&  wall_e && !wall_w): _place_wall(wall_scene_e, tile_pos, -PI/2)
				elif(!wall_n && !wall_s && !wall_e &&  wall_w): _place_wall(wall_scene_e, tile_pos, PI/2)
				elif(!wall_n && !wall_s && !wall_e && !wall_w): _place_wall(wall_scene_x, tile_pos, 0)

	var generator = MapGenerator.new();

	map = generator.generate_map(0, 0, 64, 64)
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
