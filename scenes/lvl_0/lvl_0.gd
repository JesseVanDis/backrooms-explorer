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

const TILE_SIZE: float = 1.0
const CHUNK_SIZE: int = 64
const GENERATION_THRESHOLD: float = 30.0
const REMOVAL_THRESHOLD: float = 200.0


var model_floor: Model = _load_model(floor_scene)
var model_ceiling: Model = _load_model(ceiling_scene)
var model_ceiling_light: Model = _load_model(ceiling_light_scene)
var model_wall_x: Model = _load_model(wall_scene_x)
var model_wall_t: Model = _load_model(wall_scene_t)
var model_wall_i: Model = _load_model(wall_scene_i)
var model_wall_l: Model = _load_model(wall_scene_l)
var model_wall_e: Model = _load_model(wall_scene_e)

class Model:
	var graphic: Node3D
	var collision: CollisionShape3D
	
	func _init() -> void:
		pass;

class Chunk:
	var chunk_index: Vector2i
	var global_pos: Vector2
	var static_body_3d: StaticBody3D
	var tiles: Node3D
	var section: MapGenerator.Section
	
	func _init() -> void:
		pass;

class PlacedTile:
	# constant
	var tile_index: Vector2i
	var angle: float
	var models: Dictionary # string, Model
	
	# mutable
	var graphics: Dictionary # string, CollisionShape3D
	var collision_shapes: Dictionary # string, CollisionShape3D
	
	func _init() -> void:
		pass;
	
var chunks: Dictionary = {}        # Vector2i(chunk index) -> Chunk
var placed_tiles: Dictionary = {}  # Vector2i(tile index)  -> PlacedTile
#var rendered_chunks: Dictionary = {} # Vector2i -> Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initial generation
	_get_or_create_chunk(Vector2i(0, 0))
	
	# Find a spawn point (white pixel)
	var spawn_pos: Vector2i = _find_spawn_point()
	
	$Player.transform.origin = Vector3(float(spawn_pos.x) * TILE_SIZE, 0.0, float(spawn_pos.y) * TILE_SIZE)

func _place_wall(parent: Node3D, static_body: StaticBody3D, model: Model, tile_index: Vector2i, angle: float) -> void:
	_instantiate_model(parent, static_body, model, tile_index, angle)

func _get_tile_at(x: int, y: int) -> MapGenerator.TileType:
	var cp: Vector2i = Vector2i(int(floor(float(x) / CHUNK_SIZE)), int(floor(float(y) / CHUNK_SIZE)))
	if ! chunks.has(cp):
		return MapGenerator.TileType.WALL
	var section: MapGenerator.Section = _get_or_create_chunk(cp).section
	return section.get_tile(x, y)

func _get_or_create_chunk(chunk_index: Vector2i) -> Chunk:
	if chunks.has(chunk_index):
		return chunks[chunk_index]
	print("Creating chunk: " + str(chunk_index))
	var x0: int = chunk_index.x * CHUNK_SIZE
	var y0: int = chunk_index.y * CHUNK_SIZE
	var generator: MapGenerator = MapGenerator.new()
	var chunk: Chunk = Chunk.new()
	print(" - generating bitmap...")
	chunk.section = generator.generate_map(x0, y0, x0 + CHUNK_SIZE, y0 + CHUNK_SIZE)
	chunk.chunk_index = chunk_index
	chunk.global_pos = Vector2(x0, y0)
	chunk.static_body_3d = StaticBody3D.new()
	chunk.tiles = Node3D.new()
	map_node.add_child(chunk.static_body_3d)
	map_node.add_child(chunk.tiles)
	chunk.static_body_3d.name = "Chunk_static_body_%d_%d" % [chunk_index.x, chunk_index.y]
	chunk.tiles.name = "Chunk_%d_%d" % [chunk_index.x, chunk_index.y]
	chunks[chunk_index] = chunk
	print(" - converting pixels to models...")
	for y in range(chunk.section.y, chunk.section.y + chunk.section.h):
		for x in range(chunk.section.x, chunk.section.x + chunk.section.w):
			_add_tile(chunk.tiles, chunk.static_body_3d, chunk.section, x, y)
	print(" - done")
	return chunk

func _instantiate_model(graphic_parent: Node3D, collision_parent: StaticBody3D, model: Model, tile_index: Vector2i, angle: float):
	var placed_tile: PlacedTile = PlacedTile.new()
	placed_tile.models[model.graphic.name] = model
	placed_tile.angle = angle
	placed_tile.tile_index = tile_index
	placed_tiles[tile_index] = placed_tile

func _add_tile(parent: Node3D, static_body: StaticBody3D, section: MapGenerator.Section, x: int, y: int) -> void:
	var tile_type: MapGenerator.TileType = section.get_tile(x, y)
	var tile_index: Vector2i = Vector2i(x, y)
	
	# ALWAYS add a floor and ceiling
	_instantiate_model(parent, static_body, model_floor, tile_index, 0)
	_instantiate_model(parent, static_body, model_ceiling, tile_index, 0)

	match tile_type:
		MapGenerator.TileType.EMPTY:
			return
			
		MapGenerator.TileType.CEILING_LIGHT:
			_instantiate_model(parent, static_body, model_ceiling_light, tile_index, 0)
			
		MapGenerator.TileType.WALL:
			# Use _get_tile_at for seamless transitions between chunks
			var wall_n: bool = _get_tile_at(x, y + 1) == MapGenerator.TileType.WALL
			var wall_s: bool = _get_tile_at(x, y - 1) == MapGenerator.TileType.WALL
			var wall_e: bool = _get_tile_at(x + 1, y) == MapGenerator.TileType.WALL
			var wall_w: bool = _get_tile_at(x - 1, y) == MapGenerator.TileType.WALL
			
			if  ( wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall(parent, static_body, model_wall_x, tile_index, 0.0)
			elif( wall_n &&  wall_s &&  wall_e && !wall_w): _place_wall(parent, static_body, model_wall_t, tile_index, 0.0)
			elif( wall_n &&  wall_s && !wall_e &&  wall_w): _place_wall(parent, static_body, model_wall_t, tile_index, PI)
			elif( wall_n &&  wall_s && !wall_e && !wall_w): _place_wall(parent, static_body, model_wall_i, tile_index, 0.0)
			elif( wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall(parent, static_body, model_wall_t, tile_index, -PI/2)
			elif( wall_n && !wall_s &&  wall_e && !wall_w): _place_wall(parent, static_body, model_wall_l, tile_index, -PI/2)
			elif( wall_n && !wall_s && !wall_e &&  wall_w): _place_wall(parent, static_body, model_wall_l, tile_index, PI)
			elif( wall_n && !wall_s && !wall_e && !wall_w): _place_wall(parent, static_body, model_wall_e, tile_index, PI)
			elif(!wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall(parent, static_body, model_wall_t, tile_index, PI/2)
			elif(!wall_n &&  wall_s &&  wall_e && !wall_w): _place_wall(parent, static_body, model_wall_l, tile_index, 0.0)
			elif(!wall_n &&  wall_s && !wall_e &&  wall_w): _place_wall(parent, static_body, model_wall_l, tile_index, PI/2)
			elif(!wall_n &&  wall_s && !wall_e && !wall_w): _place_wall(parent, static_body, model_wall_e, tile_index, 0.0)
			elif(!wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall(parent, static_body, model_wall_i, tile_index, PI/2)
			elif(!wall_n && !wall_s &&  wall_e && !wall_w): _place_wall(parent, static_body, model_wall_e, tile_index, -PI/2)
			elif(!wall_n && !wall_s && !wall_e &&  wall_w): _place_wall(parent, static_body, model_wall_e, tile_index, PI/2)
			elif(!wall_n && !wall_s && !wall_e && !wall_w): _place_wall(parent, static_body, model_wall_x, tile_index, 0.0)

#
func _find_spawn_point() -> Vector2i:
	var first_chunk: Chunk = _get_or_create_chunk(Vector2i(0, 0))
	for y in range(first_chunk.section.y, first_chunk.section.y + first_chunk.section.h):
		for x in range(first_chunk.section.x, first_chunk.section.x + first_chunk.section.w):
			if first_chunk.section.get_tile(x, y) != MapGenerator.TileType.WALL:
				return Vector2i(x, y)
	return Vector2i(1, 1)

func _remove_chunk(chunk_index: Vector2i) -> void:
	print("Removing chunk: " + str(chunk_index))
	var chunk_node: Node3D = chunks[chunk_index].tiles
	var chunk_collisions: StaticBody3D = chunks[chunk_index].static_body_3d
	var chunk_name: String = chunk_node.name
	var chunk_collisions_name: String = chunk_collisions.name
	map_node.remove_child(chunk_node)
	map_node.remove_child(chunk_collisions)
	chunk_node.queue_free()
	
	# Clean up collision shapes that were moved to the global StaticBody3D ( not tested ) 
	get_tree().call_group("col_" + chunk_name, "queue_free")
	get_tree().call_group("col_" + chunk_collisions_name, "queue_free")
	chunks.erase(chunk_index)

var _last_tiles_where_collision_is_needed: Dictionary # Vector2i, bool   ( bool not used. treat as std::set )
func _handle_static_collision_shapes() -> void:
	var create = func(placed_tile: PlacedTile, chunk: Chunk):
		for model: Model in placed_tile.models.values():
			if (model.collision != null) && (! placed_tile.collision_shapes.has(model.collision.name)):
				var tile_pos: Vector3 = Vector3(float(placed_tile.tile_index.x) * TILE_SIZE, 0.0, float(placed_tile.tile_index.y) * TILE_SIZE)
				var collision_shape = model.collision.duplicate()
				collision_shape.transform.origin = tile_pos
				collision_shape.rotate_y(placed_tile.angle)
				chunk.static_body_3d.add_child(collision_shape)
				placed_tile.collision_shapes[model.collision.name] = collision_shape

	var remove = func(placed_tile: PlacedTile):
		for collision_shape in placed_tile.collision_shapes.values():
			collision_shape.queue_free() # automatically removes it from the scene as well.
		placed_tile.collision_shapes = {}
	
	_handle_tiles_in_radius(2, _last_tiles_where_collision_is_needed, create, remove)


var _last_tiles_where_graphics_is_needed: Dictionary # Vector2i, bool   ( bool not used. treat as std::set )
func _handle_tile_graphics() -> void:
	var create = func(placed_tile: PlacedTile, chunk: Chunk):
		for model: Model in placed_tile.models.values():
			if ! placed_tile.graphics.has(model.graphic.name):
				var tile_pos: Vector3 = Vector3(float(placed_tile.tile_index.x) * TILE_SIZE, 0.0, float(placed_tile.tile_index.y) * TILE_SIZE)
				var graphic = model.graphic.duplicate()
				graphic.transform.origin = tile_pos
				graphic.rotate_y(placed_tile.angle)
				chunk.tiles.add_child(graphic)
				placed_tile.graphics[model.graphic.name] = graphic

	var remove = func(placed_tile: PlacedTile):
		for graphic: Node3D in placed_tile.graphics.values():
			graphic.get_parent().remove_child(graphic)
			graphic.queue_free()
		placed_tile.graphics = {}
	
	_handle_tiles_in_radius(5, _last_tiles_where_graphics_is_needed, create, remove)

func _handle_tiles_in_radius(radius: int, cache: Dictionary, create_cb: Callable, remove_cb: Callable) -> void:
	var player_pos_3d: Vector3 = $Player/CharacterBody3D.transform.origin
	var player_pos: Vector2 = Vector2(player_pos_3d.x, player_pos_3d.z)
	var tile_index_of_player = Vector2i(int(player_pos.x), int(player_pos.y))
	#print("player tile index: " + str(tile_index_of_player))
	
	var x0 = tile_index_of_player.x - radius
	var x1 = tile_index_of_player.x + radius
	var y0 = tile_index_of_player.y - radius
	var y1 = tile_index_of_player.y + radius
	
	var tiles_visible: Array[Vector2i] = []
	var tiles_no_longer_visible = cache.duplicate()
	
	for y in range(y0, y1):
		for x in range(x0, x1):
			var tile_index = Vector2i(x, y)
			tiles_visible.append(tile_index)
			tiles_no_longer_visible.erase(tile_index)

	# remove collision tile first
	for tile_index: Vector2i in tiles_no_longer_visible.keys():
		if placed_tiles.has(tile_index):
			var placed_tile: PlacedTile = placed_tiles[tile_index]
			remove_cb.call(placed_tile)
	
	cache.clear()
	for tile_index: Vector2i in tiles_visible:
		cache[tile_index] = true
		if placed_tiles.has(tile_index):
			var placed_tile: PlacedTile = placed_tiles[tile_index]
			var chunk_index = _get_chunk_index(tile_index)
			if chunks.has(chunk_index):
				var chunk: Chunk = chunks[chunk_index]
				#var tile_pos: Vector3 = Vector3(float(tile_index.x) * TILE_SIZE, 0.0, float(tile_index.y) * TILE_SIZE)
				create_cb.call(placed_tile, chunk)
				

func _handle_world_generation() -> void:
	var player_pos_3d: Vector3 = $Player/CharacterBody3D.transform.origin
	var player_pos: Vector2 = Vector2(player_pos_3d.x, player_pos_3d.z)
	#print("Player pos: " + str(player_pos))
	
	# Removal logic
	var chunks_to_remove: Array[Vector2i] = []
	for chunk: Chunk in chunks.values():
		var dist: float = (_get_center_chunk_pos(chunk.chunk_index) - player_pos).length()
		if (dist - CHUNK_SIZE/2.0) > REMOVAL_THRESHOLD:
			chunks_to_remove.append(chunk.chunk_index)
			
	for chunk_index: Vector2i in chunks_to_remove:
		_remove_chunk(chunk_index)

	var current_chunk_x: int = int(floor(player_pos.x / float(CHUNK_SIZE)))
	var current_chunk_y: int = int(floor(player_pos.y / float(CHUNK_SIZE)))
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var chunk_index: Vector2i = Vector2i(current_chunk_x + dx, current_chunk_y + dy)
			if not chunks.has(chunk_index):
				var dist: float = (_get_center_chunk_pos(chunk_index) - player_pos).length()
				# print("chunk: [" + str(chunk_index) + "] check distance: " + str(dist - CHUNK_SIZE/2.0) + ")")
				if (dist - CHUNK_SIZE/2.0) < GENERATION_THRESHOLD:
					_get_or_create_chunk(chunk_index)

func _get_chunk_index(tile_index: Vector2i) -> Vector2i:
	return Vector2i(tile_index.x / CHUNK_SIZE, tile_index.y / CHUNK_SIZE)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	_handle_world_generation()
	_handle_tile_graphics()
	_handle_static_collision_shapes()

func _get_collision_shape(resource: Resource) -> CollisionShape3D:
	var inst: Node3D = resource.instantiate()
	for child: Node in inst.get_children():
		if child is CollisionShape3D:
			var shape := child.duplicate() as CollisionShape3D
			inst.queue_free()
			return shape
	inst.queue_free()
	return null

func _instantiate_and_remove_collision(graphic: Resource) -> Node3D:
	var node: Node3D = graphic.instantiate()
	for child: Node in node.get_children():
		if child is CollisionShape3D:
			child.queue_free()
	return node

func _load_model(tile: Resource) -> Model:
	var retval = Model.new()
	retval.graphic = _instantiate_and_remove_collision(tile)
	retval.collision = _get_collision_shape(tile)
	return retval

func _get_center_chunk_pos(chunk_index: Vector2i) -> Vector2:
	return Vector2((float(chunk_index.x * CHUNK_SIZE)) + CHUNK_SIZE/2.0, (float(chunk_index.y * CHUNK_SIZE)) + CHUNK_SIZE / 2.0)
