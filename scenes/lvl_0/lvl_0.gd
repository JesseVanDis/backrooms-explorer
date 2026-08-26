extends Node3D

@onready var map_node: Node3D = $Map

const floor_scene: Resource = preload("res://scenes/lvl_0/part_1x1_floor.tscn")
const ceiling_scene: Resource = preload("res://scenes/lvl_0/part_1x1_ceiling.tscn")
const ceiling_light_scene: Resource = preload("res://scenes/lvl_0/part_1x1_ceiling_light.tscn")
const wall_scene_x: Resource = preload("res://scenes/lvl_0/part_wall_x.tscn")
const wall_scene_t: Resource = preload("res://scenes/lvl_0/part_wall_t.tscn")
const wall_scene_i: Resource = preload("res://scenes/lvl_0/part_wall_i.tscn")
const wall_scene_l: Resource = preload("res://scenes/lvl_0/part_wall_l.tscn")
const wall_scene_e: Resource = preload("res://scenes/lvl_0/part_wall_end.tscn")

const tile_size: float = 1.0
const CHUNK_SIZE: int = 64
const GENERATION_THRESHOLD: float = 15.0

var generated_chunks: Dictionary = {} # Vector2i -> MapGenerator.Section
var rendered_chunks: Dictionary = {} # Vector2i -> Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initial generation
	_generate_chunk(Vector2i(0, 0))
	
	# Find a spawn point (white pixel)
	var spawn_pos: Vector2i = _find_spawn_point()
	
	$Player.transform.origin = Vector3(float(spawn_pos.x) * tile_size, 0.0, float(spawn_pos.y) * tile_size)
	# Also reset rotation to avoid looking at the floor or something
	$Player.rotation = Vector3.ZERO

func _place_wall(parent: Node3D, scene: Resource, pos: Vector3, angle: float) -> void:
	var instance: Node3D = scene.instantiate()
	parent.add_child(instance)
	instance.transform.origin = pos
	instance.rotate_y(angle)

func _get_tile_at(x: int, y: int) -> MapGenerator.TileType:
	var cp: Vector2i = Vector2i(int(floor(float(x) / CHUNK_SIZE)), int(floor(float(y) / CHUNK_SIZE)))
	var section: MapGenerator.Section = _ensure_chunk_data(cp)
	return section.get_tile(x, y)

func _ensure_chunk_data(cp: Vector2i) -> MapGenerator.Section:
	if generated_chunks.has(cp):
		return generated_chunks[cp]
	
	var x0: int = cp.x * CHUNK_SIZE
	var y0: int = cp.y * CHUNK_SIZE
	
	var generator: MapGenerator = MapGenerator.new()
	var section: MapGenerator.Section = generator.generate_map(x0, y0, x0 + CHUNK_SIZE, y0 + CHUNK_SIZE)
	generated_chunks[cp] = section
	return section

func _generate_chunk(cp: Vector2i) -> void:
	if rendered_chunks.has(cp):
		return
	
	var section: MapGenerator.Section = _ensure_chunk_data(cp)
	
	# Create a container for the chunk
	var chunk_node: Node3D = Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [cp.x, cp.y]
	map_node.add_child(chunk_node)
	rendered_chunks[cp] = chunk_node
	
	# Inspiration from generate_level
	for y in range(section.y, section.y + section.h):
		for x in range(section.x, section.x + section.w):
			_render_tile(chunk_node, section, x, y)

func _render_tile(parent: Node3D, section: MapGenerator.Section, x: int, y: int) -> void:
	var tile_type: MapGenerator.TileType = section.get_tile(x, y)
	var tile_pos: Vector3 = Vector3(float(x) * tile_size, 0.0, float(y) * tile_size)
	
	# ALWAYS add a floor and ceiling
	var floor_inst: Node3D = floor_scene.instantiate()
	var ceiling_inst: Node3D = ceiling_scene.instantiate()
	parent.add_child(floor_inst)
	parent.add_child(ceiling_inst)
	floor_inst.transform.origin = tile_pos
	ceiling_inst.transform.origin = tile_pos

	match tile_type:
		MapGenerator.TileType.EMPTY:
			return
		MapGenerator.TileType.CEILING_LIGHT:
			var ceiling_light_inst: Node3D = ceiling_light_scene.instantiate()
			parent.add_child(ceiling_light_inst)
			ceiling_light_inst.transform.origin = tile_pos
			
		MapGenerator.TileType.WALL:
			# Use _get_tile_at for seamless transitions between chunks
			var wall_n: bool = _get_tile_at(x, y + 1) == MapGenerator.TileType.WALL
			var wall_s: bool = _get_tile_at(x, y - 1) == MapGenerator.TileType.WALL
			var wall_e: bool = _get_tile_at(x + 1, y) == MapGenerator.TileType.WALL
			var wall_w: bool = _get_tile_at(x - 1, y) == MapGenerator.TileType.WALL
			
			if    ( wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall(parent, wall_scene_x, tile_pos, 0.0)
			elif( wall_n &&  wall_s &&  wall_e && !wall_w): _place_wall(parent, wall_scene_t, tile_pos, 0.0)
			elif( wall_n &&  wall_s && !wall_e &&  wall_w): _place_wall(parent, wall_scene_t, tile_pos, PI)
			elif( wall_n &&  wall_s && !wall_e && !wall_w): _place_wall(parent, wall_scene_i, tile_pos, 0.0)
			elif( wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall(parent, wall_scene_t, tile_pos, -PI/2)
			elif( wall_n && !wall_s &&  wall_e && !wall_w): _place_wall(parent, wall_scene_l, tile_pos, -PI/2)
			elif( wall_n && !wall_s && !wall_e &&  wall_w): _place_wall(parent, wall_scene_l, tile_pos, PI)
			elif( wall_n && !wall_s && !wall_e && !wall_w): _place_wall(parent, wall_scene_e, tile_pos, PI)
			elif(!wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall(parent, wall_scene_t, tile_pos, PI/2)
			elif(!wall_n &&  wall_s &&  wall_e && !wall_w): _place_wall(parent, wall_scene_l, tile_pos, 0.0)
			elif(!wall_n &&  wall_s && !wall_e &&  wall_w): _place_wall(parent, wall_scene_l, tile_pos, PI/2)
			elif(!wall_n &&  wall_s && !wall_e && !wall_w): _place_wall(parent, wall_scene_e, tile_pos, 0.0)
			elif(!wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall(parent, wall_scene_i, tile_pos, PI/2)
			elif(!wall_n && !wall_s &&  wall_e && !wall_w): _place_wall(parent, wall_scene_e, tile_pos, -PI/2)
			elif(!wall_n && !wall_s && !wall_e &&  wall_w): _place_wall(parent, wall_scene_e, tile_pos, PI/2)
			elif(!wall_n && !wall_s && !wall_e && !wall_w): _place_wall(parent, wall_scene_x, tile_pos, 0.0)

#
func _find_spawn_point() -> Vector2i:
	var first_chunk: MapGenerator.Section = _ensure_chunk_data(Vector2i(0, 0))
	for y in range(first_chunk.y, first_chunk.y + first_chunk.h):
		for x in range(first_chunk.x, first_chunk.x + first_chunk.w):
			if first_chunk.get_tile(x, y) != MapGenerator.TileType.WALL:
				return Vector2i(x, y)
	return Vector2i(1, 1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var player_pos: Vector3 = $Player.transform.origin
	var px: float = player_pos.x / tile_size
	var py: float = player_pos.z / tile_size
	
	var current_chunk_x: int = int(floor(px / float(CHUNK_SIZE)))
	var current_chunk_y: int = int(floor(py / float(CHUNK_SIZE)))
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cp: Vector2i = Vector2i(current_chunk_x + dx, current_chunk_y + dy)
			if not rendered_chunks.has(cp):
				var chunk_min_x: float = float(cp.x * CHUNK_SIZE)
				var chunk_max_x: float = float((cp.x + 1) * CHUNK_SIZE)
				var chunk_min_y: float = float(cp.y * CHUNK_SIZE)
				var chunk_max_y: float = float((cp.y + 1) * CHUNK_SIZE)
				
				var closest_x: float = clamp(px, chunk_min_x, chunk_max_x)
				var closest_y: float = clamp(py, chunk_min_y, chunk_max_y)
				
				var dist: float = Vector2(px - closest_x, py - closest_y).length()
				if dist < GENERATION_THRESHOLD:
					_generate_chunk(cp)

func generate_level() -> void:
	# Keep for inspiration/compatibility but actual work is in _generate_chunk
	_generate_chunk(Vector2i(0, 0))
