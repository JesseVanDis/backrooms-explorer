class_name Lvl_0
extends Node3D

const TILE_SIZE: float = 1.0
const CHUNK_SIZE: int = 128
const GENERATION_THRESHOLD: float = CHUNK_SIZE
const REMOVAL_THRESHOLD: float = 200.0
const VIEW_DISTANCE: int = 60

var model_floor:                  Model = _load_model(preload("res://scenes/lvl_0/part_1x1_floor.tscn"))
var model_ceiling:                Model = _load_model(preload("res://scenes/lvl_0/part_1x1_ceiling.tscn"))
var model_ceiling_light:          Model = _load_model(preload("res://scenes/lvl_0/part_1x1_ceiling_light.tscn"))
var model_ceiling_light_blinking: Model = _load_model(preload("res://scenes/lvl_0/part_1x1_ceiling_light_blinking.tscn"))
var model_wall_x:                 Model = _load_model(preload("res://scenes/lvl_0/part_wall_x.tscn"))
var model_wall_t:                 Model = _load_model(preload("res://scenes/lvl_0/part_wall_t.tscn"))
var model_wall_i:                 Model = _load_model(preload("res://scenes/lvl_0/part_wall_i.tscn"))
var model_wall_l:                 Model = _load_model(preload("res://scenes/lvl_0/part_wall_l.tscn"))
var model_wall_e:                 Model = _load_model(preload("res://scenes/lvl_0/part_wall_end.tscn"))

@onready var _node_map: Node3D = $Map
var _player: Player = null

var _did_hit_floor: bool = false

class Model:
	var id: int
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
	var models: Dictionary # int(model_id), Model
	
	# mutable
	var graphics: Dictionary # int(model_id), CollisionShape3D
	var collision_shapes: Dictionary # int(model_id), CollisionShape3D
	
	func _init() -> void:
		pass;
	
var chunks: Dictionary = {}        # Vector2i(chunk index) -> Chunk
var placed_tiles: Dictionary = {}  # Vector2i(tile index)  -> PlacedTile
#var rendered_chunks: Dictionary = {} # Vector2i -> Node3D

func initialize_async() -> void:
	initialized()

func initialized() -> bool:
	var chunk1: Chunk = _get_or_create_chunk(Vector2i(0, 0), true)
	var chunk2: Chunk = _get_or_create_chunk(Vector2i(-1, -1), true)
	var chunk3: Chunk = _get_or_create_chunk(Vector2i(-1, 0), true)
	var chunk4: Chunk = _get_or_create_chunk(Vector2i(0, -1), true)
	return chunk1 && chunk2 && chunk3 && chunk4

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_player = $Player
	UtilsScreen.fade_out_screen(get_tree())
		
	# Initial generation
	_get_or_create_chunk(Vector2i(0, 0), false)
	_get_or_create_chunk(Vector2i(-1, -1), false)
	_get_or_create_chunk(Vector2i(-1, 0), false)
	_get_or_create_chunk(Vector2i(0, -1), false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	_handle_player_landing()
	_handle_world_generation()
	_handle_tile_graphics()
	_handle_static_collision_shapes()


func _handle_player_landing() -> void:
	var player: Player = $Player
	if player:
		if !_did_hit_floor && player.is_on_floor():
			player.active_wieldable = Player.Wieldable.LVL_0_HITGROUND
			_did_hit_floor = true

func _place_wall(model: Model, tile_index: Vector2i, angle: float) -> void:
	_instantiate_model(model, tile_index, angle)

func _get_pixel_at(x: int, y: int) -> MapGenerator.Pixel:
	var chunk_index: Vector2i = Vector2i(int(floorf(float(x) / CHUNK_SIZE)), int(floorf(float(y) / CHUNK_SIZE)))
	if ! chunks.has(chunk_index):
		return MapGenerator.Pixel.INVALID
	var chunk: Chunk = _get_or_create_chunk(chunk_index, false)
	var section: MapGenerator.Section = chunk.section
	return section.get_pixel(x, y)

var chunks_in_progress: Dictionary = {}        # Vector2i(chunk index) -> bool ( bool ignored )
var chunks_in_progress_mutex := Mutex.new()
var chunks_in_results: Dictionary = {} # Vector2i(chunk index) -> MapGenerator.Section
var chunks_in_results_mutex := Mutex.new()

func _generate_chunk(chunk_index: Vector2i) -> MapGenerator.Section:
	print("Creating chunk: " + str(chunk_index))
	var x0: int = chunk_index.x * CHUNK_SIZE
	var y0: int = chunk_index.y * CHUNK_SIZE
	var generator := MapGenerator.new()
	print(" - generating bitmap...")
	var section: MapGenerator.Section = generator.generate_map(x0, y0, x0 + CHUNK_SIZE, y0 + CHUNK_SIZE)
	return section
	
func _generate_chunk_thread(chunk_index: Vector2i) -> void:
	var section: MapGenerator.Section = _generate_chunk(chunk_index)
	chunks_in_results_mutex.lock()
	chunks_in_results[chunk_index] = section
	chunks_in_results_mutex.unlock()

var chunk_threads: Dictionary = {}
func _start_chunk_generation(chunk_index: Vector2i) -> void:
	var thread := Thread.new()
	chunk_threads[chunk_index] = thread
	thread.start(_generate_chunk_thread.bind(chunk_index))
	
func _get_or_create_chunk(chunk_index: Vector2i, async: bool) -> Chunk:
	if chunks.has(chunk_index):
		var cached_chunk: Chunk = chunks[chunk_index]
		if _node_map:
			if cached_chunk.static_body_3d.get_parent() != _node_map:
				_node_map.add_child(cached_chunk.static_body_3d)
			if cached_chunk.tiles.get_parent() != _node_map:
				_node_map.add_child(cached_chunk.tiles)
		return cached_chunk
		
	var x0: int = chunk_index.x * CHUNK_SIZE
	var y0: int = chunk_index.y * CHUNK_SIZE
	
	var result: MapGenerator.Section = null
	if async:
		chunks_in_progress_mutex.lock()
		var already_generating := chunks_in_progress.has(chunk_index)
		if !already_generating:
			chunks_in_progress[chunk_index] = true
			chunks_in_progress_mutex.unlock()
			_start_chunk_generation(chunk_index)
		else:
			chunks_in_progress_mutex.unlock()
		
		if already_generating:
			# check for result
			chunks_in_results_mutex.lock()
			if chunks_in_results.has(chunk_index):
				result = chunks_in_results[chunk_index]
				chunks_in_results.erase(chunk_index)
			chunks_in_results_mutex.unlock()
		
		if result == null:
			return null
	else:
		result = _generate_chunk(chunk_index)
	
	var chunk: Chunk = Chunk.new()
	chunk.section = result
	chunk.chunk_index = chunk_index
	chunk.global_pos = Vector2(x0, y0)
	chunk.static_body_3d = StaticBody3D.new()
	chunk.tiles = Node3D.new()
	if _node_map:
		_node_map.add_child(chunk.static_body_3d)
		_node_map.add_child(chunk.tiles)
	chunk.static_body_3d.name = "Chunk_static_body_%d_%d" % [chunk_index.x, chunk_index.y]
	chunk.tiles.name = "Chunk_%d_%d" % [chunk_index.x, chunk_index.y]
	chunks[chunk_index] = chunk
	print("converting pixels to models for chunk[" + str(chunk_index) + "]...")
	for y in range(chunk.section.y, chunk.section.y + chunk.section.h):
		for x in range(chunk.section.x, chunk.section.x + chunk.section.w):
			_add_tile(chunk.section, x, y)
	print("converting pixels to models for chunk[" + str(chunk_index) + "]... done")
	return chunk

func _instantiate_model(model: Model, tile_index: Vector2i, angle: float) -> void:
	var placed_tile: PlacedTile
	if placed_tiles.has(tile_index):
		placed_tile = placed_tiles[tile_index]
	else:
		placed_tile = PlacedTile.new()
		placed_tiles[tile_index] = placed_tile
	
	placed_tile.models[model.id] = model
	placed_tile.angle = angle
	placed_tile.tile_index = tile_index

func _add_tile(section: MapGenerator.Section, x: int, y: int) -> void:
	var pixel: MapGenerator.Pixel = section.get_pixel(x, y)
	var tile_index: Vector2i = Vector2i(x, y)
	
	# ALWAYS add a floor and ceiling
	_instantiate_model(model_floor, tile_index, 0)

	match pixel & MapGenerator.TILE_MASK:
		MapGenerator.Pixel.TILE_EMPTY:
			_instantiate_model(model_ceiling, tile_index, 0)
			return
			
		MapGenerator.Pixel.TILE_CEILING_LIGHT:
			_instantiate_model(model_ceiling_light, tile_index, 0)
			
		MapGenerator.Pixel.TILE_CEILING_LIGHT_BLINKING:
			_instantiate_model(model_ceiling_light_blinking, tile_index, 0)
			
		MapGenerator.Pixel.TILE_WALL:
			_instantiate_model(model_ceiling, tile_index, 0)
			# Use _get_pixel_at for seamless transitions between chunks
			var wall_n: bool = (_get_pixel_at(x, y + 1) & MapGenerator.TILE_MASK) == MapGenerator.Pixel.TILE_WALL
			var wall_s: bool = (_get_pixel_at(x, y - 1) & MapGenerator.TILE_MASK) == MapGenerator.Pixel.TILE_WALL
			var wall_e: bool = (_get_pixel_at(x + 1, y) & MapGenerator.TILE_MASK) == MapGenerator.Pixel.TILE_WALL
			var wall_w: bool = (_get_pixel_at(x - 1, y) & MapGenerator.TILE_MASK) == MapGenerator.Pixel.TILE_WALL
			
			if  ( wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall(model_wall_x, tile_index, 0.0)
			elif( wall_n &&  wall_s &&  wall_e && !wall_w): _place_wall(model_wall_t, tile_index, 0.0)
			elif( wall_n &&  wall_s && !wall_e &&  wall_w): _place_wall(model_wall_t, tile_index, PI)
			elif( wall_n &&  wall_s && !wall_e && !wall_w): _place_wall(model_wall_i, tile_index, 0.0)
			elif( wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall(model_wall_t, tile_index, -PI/2)
			elif( wall_n && !wall_s &&  wall_e && !wall_w): _place_wall(model_wall_l, tile_index, -PI/2)
			elif( wall_n && !wall_s && !wall_e &&  wall_w): _place_wall(model_wall_l, tile_index, PI)
			elif( wall_n && !wall_s && !wall_e && !wall_w): _place_wall(model_wall_e, tile_index, PI)
			elif(!wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall(model_wall_t, tile_index, PI/2)
			elif(!wall_n &&  wall_s &&  wall_e && !wall_w): _place_wall(model_wall_l, tile_index, 0.0)
			elif(!wall_n &&  wall_s && !wall_e &&  wall_w): _place_wall(model_wall_l, tile_index, PI/2)
			elif(!wall_n &&  wall_s && !wall_e && !wall_w): _place_wall(model_wall_e, tile_index, 0.0)
			elif(!wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall(model_wall_i, tile_index, PI/2)
			elif(!wall_n && !wall_s &&  wall_e && !wall_w): _place_wall(model_wall_e, tile_index, -PI/2)
			elif(!wall_n && !wall_s && !wall_e &&  wall_w): _place_wall(model_wall_e, tile_index, PI/2)
			elif(!wall_n && !wall_s && !wall_e && !wall_w): _place_wall(model_wall_x, tile_index, 0.0)

#
func _find_spawn_point() -> Vector2i:
	var first_chunk: Chunk = _get_or_create_chunk(Vector2i(0, 0), false)
	for y in range(first_chunk.section.y, first_chunk.section.y + first_chunk.section.h):
		for x in range(first_chunk.section.x, first_chunk.section.x + first_chunk.section.w):
			if ((first_chunk.section.get_pixel(x, y) & MapGenerator.TILE_MASK) != MapGenerator.Pixel.TILE_WALL):
				return Vector2i(x, y)
	return Vector2i(1, 1)

func _remove_chunk(chunk_index: Vector2i) -> void:
	print("Removing chunk: " + str(chunk_index))
	var chunk_node: Node3D = chunks[chunk_index].tiles
	var chunk_collisions: StaticBody3D = chunks[chunk_index].static_body_3d
	var chunk_name: String = chunk_node.name
	var chunk_collisions_name: String = chunk_collisions.name
	_node_map.remove_child(chunk_node)
	_node_map.remove_child(chunk_collisions)
	chunk_node.queue_free()
	
	# Clean up collision shapes that were moved to the global StaticBody3D ( not tested ) 
	get_tree().call_group("col_" + chunk_name, "queue_free")
	get_tree().call_group("col_" + chunk_collisions_name, "queue_free")
	chunks.erase(chunk_index)

class HandleTilesCache:
	var last_tiles_where_needed: Dictionary # Vector2i, bool   ( bool not used. treat as std::set )
	var placed_tiles: Dictionary # Vector2i, bool   ( bool not used. treat as std::set )

var _collision_tiles_cache: HandleTilesCache = HandleTilesCache.new() # Vector2i, bool   ( bool not used. treat as std::set )
func _handle_static_collision_shapes() -> void:
	var create: Callable = func(placed_tile: PlacedTile, chunk: Chunk) -> void:
		for model: Model in placed_tile.models.values():
			if (model.collision != null) && (! placed_tile.collision_shapes.has(model.id)):
				#print("Collision '" + str(model.id) + "' place!")
				var tile_pos: Vector3 = Vector3(float(placed_tile.tile_index.x) * TILE_SIZE, 0.0, float(placed_tile.tile_index.y) * TILE_SIZE)
				var collision_shape: CollisionShape3D = model.collision.duplicate()
				collision_shape.transform.origin = tile_pos
				collision_shape.rotate_y(placed_tile.angle)
				chunk.static_body_3d.add_child(collision_shape)
				placed_tile.collision_shapes[model.id] = collision_shape
				
	var remove: Callable = func(placed_tile: PlacedTile) -> void:
		for collision_shape: CollisionShape3D in placed_tile.collision_shapes.values():
			collision_shape.queue_free() # automatically removes it from the scene as well.
		placed_tile.collision_shapes = {}
		
	_handle_tiles_in_radius(2, _collision_tiles_cache, create, remove)

var _graphic_tiles_cache: HandleTilesCache = HandleTilesCache.new() # Vector2i, bool   ( bool not used. treat as std::set )
func _handle_tile_graphics() -> void:
	var create: Callable = func(placed_tile: PlacedTile, chunk: Chunk) -> void:
		for model: Model in placed_tile.models.values():
			if ! placed_tile.graphics.has(model.id):
				var tile_pos: Vector3 = Vector3(float(placed_tile.tile_index.x) * TILE_SIZE, 0.0, float(placed_tile.tile_index.y) * TILE_SIZE)
				# push_warning("adding: " + str(model.id))
				var graphic: Node3D = model.graphic.duplicate()
				graphic.transform.origin = tile_pos
				graphic.rotate_y(placed_tile.angle)
				chunk.tiles.add_child(graphic)
				placed_tile.graphics[model.id] = graphic
	
	var remove: Callable = func(placed_tile: PlacedTile) -> void:
		for graphic: Node3D in placed_tile.graphics.values():
			graphic.queue_free() # gets remove from the parent automatically
		placed_tile.graphics = {}
	
	_handle_tiles_in_radius(VIEW_DISTANCE, _graphic_tiles_cache, create, remove, 50)

func _handle_tiles_in_radius(radius: int, cache: HandleTilesCache, create_cb: Callable, remove_cb: Callable, max_tiles_to_handle: int = 0) -> void:
	var player_pos_3d: Vector3 = _player.transform.origin
	var player_pos: Vector2 = Vector2(player_pos_3d.x, player_pos_3d.z)
	var tile_index_of_player: Vector2i = Vector2i(int(player_pos.x), int(player_pos.y))
	#print("player tile index: " + str(tile_index_of_player))
	
	var x0: int = tile_index_of_player.x - radius
	var x1: int = tile_index_of_player.x + radius
	var y0: int = tile_index_of_player.y - radius
	var y1: int = tile_index_of_player.y + radius
	
	var tiles_visible: Array[Vector2i] = []
	var tiles_no_longer_visible: Dictionary = cache.last_tiles_where_needed.duplicate()
	
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dist: float = (Vector2(x, y) - player_pos).length()
			if int(roundf(dist)) < radius:
				var tile_index: Vector2i = Vector2i(x, y)
				tiles_visible.append(tile_index)
				tiles_no_longer_visible.erase(tile_index)
	
	# iterate from player outwards
	var sort_by_distance: Callable = func(a: Vector2i, b: Vector2i) -> float: return a.distance_squared_to(Vector2i(player_pos)) < b.distance_squared_to(Vector2i(player_pos))
	tiles_visible.sort_custom(sort_by_distance)

	# remove out-of-range tile first
	for tile_index: Vector2i in tiles_no_longer_visible.keys():
		if placed_tiles.has(tile_index):
			var placed_tile: PlacedTile = placed_tiles[tile_index]
			remove_cb.call(placed_tile)
			cache.placed_tiles[tile_index] = false
	
	var num_tiles_handled: int = 0
	cache.last_tiles_where_needed.clear()
	for tile_index: Vector2i in tiles_visible:
		cache.last_tiles_where_needed[tile_index] = true
		if placed_tiles.has(tile_index):
			var placed_tile: PlacedTile = placed_tiles[tile_index]
			var chunk_index: Vector2i = _get_chunk_index(tile_index)
			if chunks.has(chunk_index):
				if (!cache.placed_tiles.has(tile_index)) || cache.placed_tiles[tile_index] == false:
					var chunk: Chunk = chunks[chunk_index]
					#var tile_pos: Vector3 = Vector3(float(tile_index.x) * TILE_SIZE, 0.0, float(tile_index.y) * TILE_SIZE)
					create_cb.call(placed_tile, chunk)
					num_tiles_handled = num_tiles_handled + 1
					cache.placed_tiles[tile_index] = true
					if max_tiles_to_handle > 0 && num_tiles_handled > max_tiles_to_handle:
						break


func _handle_world_generation() -> void:
	var player_pos_3d: Vector3 = _player.transform.origin
	var player_pos: Vector2 = Vector2(player_pos_3d.x, player_pos_3d.z)
	# print("Player pos: " + str(player_pos))
	
	# Removal logic
	var chunks_to_remove: Array[Vector2i] = []
	for chunk: Chunk in chunks.values():
		var dist: float = (_get_center_chunk_pos(chunk.chunk_index) - player_pos).length()
		if (dist - CHUNK_SIZE/2.0) > REMOVAL_THRESHOLD:
			chunks_to_remove.append(chunk.chunk_index)
			
	for chunk_index: Vector2i in chunks_to_remove:
		_remove_chunk(chunk_index)

	var current_chunk_x: int = int(floorf(player_pos.x / float(CHUNK_SIZE)))
	var current_chunk_y: int = int(floorf(player_pos.y / float(CHUNK_SIZE)))
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var chunk_index: Vector2i = Vector2i(current_chunk_x + dx, current_chunk_y + dy)
			if not chunks.has(chunk_index):
				var chunk_center: Vector2 = _get_center_chunk_pos(chunk_index)
				var dist: float = (chunk_center - player_pos).length()
				# print("chunk: [" + str(chunk_index) + "]. center: [" + str(chunk_center) + "] check distance: " + str(dist - CHUNK_SIZE/2.0) + ")")
				if (dist - CHUNK_SIZE/2.0) < GENERATION_THRESHOLD:
					_get_or_create_chunk(chunk_index, true)

func _get_chunk_index(tile_index: Vector2i) -> Vector2i:
	return Vector2i(int(roundf(float(tile_index.x) / float(CHUNK_SIZE))), int(roundf(float(tile_index.y) / float(CHUNK_SIZE))))

func _get_collision_shape(resource: PackedScene) -> CollisionShape3D:
	var inst: Node3D = resource.instantiate()
	for child: Node in inst.get_children():
		if child is CollisionShape3D:
			var shape: CollisionShape3D = child.duplicate() as CollisionShape3D
			inst.queue_free()
			return shape
	inst.queue_free()
	return null

func _instantiate_and_remove_collision(graphic: PackedScene) -> Node3D:
	var inst: Node3D = graphic.instantiate()
	var new_node: Node3D = Node3D.new()

	var script: Script = inst.get_script()
	if script != null:
		new_node.set_script(script)
	
	for child: Node in inst.get_children():
		if not (child is CollisionShape3D or child is CollisionPolygon3D or child is PhysicsBody3D):
			var dup: Node = child.duplicate()
			new_node.add_child(dup)
	
	inst.queue_free()
	return new_node

var last_model_id: int = 0
func _load_model(tile: PackedScene) -> Model:
	last_model_id = last_model_id + 1
	var retval: Model = Model.new()
	retval.graphic = _instantiate_and_remove_collision(tile)
	retval.collision = _get_collision_shape(tile)
	retval.id = last_model_id
	return retval

func _get_center_chunk_pos(chunk_index: Vector2i) -> Vector2:
	return Vector2((float(chunk_index.x * CHUNK_SIZE)) + CHUNK_SIZE/2.0, (float(chunk_index.y * CHUNK_SIZE)) + CHUNK_SIZE / 2.0)
