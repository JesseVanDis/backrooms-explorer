class_name Lvl_0
extends Node

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
var model_arch_i:                 Model = _load_model(preload("res://scenes/lvl_0/part_arch_i.tscn"))
var model_arch_e:                 Model = _load_model(preload("res://scenes/lvl_0/part_arch_e.tscn"))

@onready var _node_map: Node3D = $_viewport_container/_viewport/Map
var _player: Player = null

var _did_hit_floor: bool = false

class ModelModefier:
	var remove_meshes_with_postfix: Array[String] = []
	var yoffset_n: float = 0
	var yoffset_s: float = 0
	var yoffset_w: float = 0
	var yoffset_e: float = 0
	var yoffset_c: float = 0

class Model:
	var id: int
	var graphic: Node3D
	var collisions: Array[CollisionShape3D]
	
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
	var model_modefier: ModelModefier

	# mutable
	var graphics: Dictionary # int(model_id), CollisionShape3D
	var collision_shapes: Dictionary # int(model_id), Array[CollisionShape3D]
	
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
	_player = $_viewport_container/_viewport/Player
	
	_player.add_wieldable("lvl_0_landing", false, true,  {
							"max_look_freedom_degrees_v": 10.0, 
							"max_look_freedom_degrees_h": 0.0, 
							"movement_multiplier": 0.0,
							"actions_at_millisecond": [
								{600:  {"set_animation_speed": 0.13}},
								{1000: {"set_animation_speed": 0.3}},
								{2000: {"set_animation_speed": 1.0}}
							]
						})

	# Initial generation
	print("Loading initial chunks...")
	while true:
		var chunk1: Chunk = _get_or_create_chunk(Vector2i(0, 0), true)
		var chunk2: Chunk = _get_or_create_chunk(Vector2i(-1, -1), true)
		var chunk3: Chunk = _get_or_create_chunk(Vector2i(-1, 0), true)
		var chunk4: Chunk = _get_or_create_chunk(Vector2i(0, -1), true)
		if chunk1 != null && chunk2 != null && chunk3 != null && chunk4 != null:
			break
		OS.delay_msec(50)
	print("All initial chunks loaded")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	_handle_player_landing()
	_handle_world_generation()
	_handle_tile_graphics()
	_handle_static_collision_shapes()

func _handle_player_landing() -> void:
	if _player:
		if !_did_hit_floor && _player.is_on_floor():
			_player.active_wieldable = "lvl_0_landing"
			_did_hit_floor = true

func _place_wall_specific(model: Model, tile_index: Vector2i, angle: float, model_modefier: ModelModefier = null) -> void:
	_instantiate_model(model, tile_index, angle, model_modefier)

func _place_wall(wall_model_x: Model, _wall_model_i: Model, _wall_model_e: Model, tile_index: Vector2i) -> void:
	var pc: MapGenerator.Pixel = _get_pixel_at(tile_index.x, tile_index.y)
	var pn: MapGenerator.Pixel = _get_pixel_at(tile_index.x, tile_index.y - 1)
	var ps: MapGenerator.Pixel = _get_pixel_at(tile_index.x, tile_index.y + 1)
	var pe: MapGenerator.Pixel = _get_pixel_at(tile_index.x + 1, tile_index.y)
	var pw: MapGenerator.Pixel = _get_pixel_at(tile_index.x - 1, tile_index.y)
	
	# var c: MapGenerator.Pixel = pc & MapGenerator.TILE_MASK as MapGenerator.Pixel
	# var n: MapGenerator.Pixel = pn & MapGenerator.TILE_MASK as MapGenerator.Pixel
	# var s: MapGenerator.Pixel = ps & MapGenerator.TILE_MASK as MapGenerator.Pixel
	# var e: MapGenerator.Pixel = pe & MapGenerator.TILE_MASK as MapGenerator.Pixel
	# var w: MapGenerator.Pixel = pw & MapGenerator.TILE_MASK as MapGenerator.Pixel
	#var wall_n: bool = MapGenerator.is_wall(pn)
	#var wall_s: bool = MapGenerator.is_wall(ps)
	#var wall_e: bool = MapGenerator.is_wall(pe)
	#var wall_w: bool = MapGenerator.is_wall(pw)
	#
	#var special: bool = MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_TOP_GAP)
	
	##if  ( !special && wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall_specific(wall_model_x, tile_index, 0.0)
	#if !special && wall_model_i: # just straight
		#if( wall_n &&  wall_s && !wall_e && !wall_w): _place_wall_specific(wall_model_i, tile_index, 0.0)
		#elif(!wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall_specific(wall_model_i, tile_index, PI/2)
	#if !special && wall_model_e: # wall endings
		#if( wall_n && !wall_s && !wall_e && !wall_w): _place_wall_specific(wall_model_e, tile_index, 0.0)
		#elif(!wall_n &&  wall_s && !wall_e && !wall_w): _place_wall_specific(wall_model_e, tile_index, PI)
		#elif(!wall_n && !wall_s &&  wall_e && !wall_w): _place_wall_specific(wall_model_e, tile_index, -PI/2)
		#elif(!wall_n && !wall_s && !wall_e &&  wall_w): _place_wall_specific(wall_model_e, tile_index, PI/2)
	#else:
	var angle: float = 0
	var model_modefier: ModelModefier = null
	
	if (pc & MapGenerator.TILE_MASK) == MapGenerator.Pixel.TILE_WALL:
		model_modefier = ModelModefier.new()
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LOBE_N): model_modefier.remove_meshes_with_postfix.append("_n")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LOBE_S): model_modefier.remove_meshes_with_postfix.append("_s")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LOBE_E): model_modefier.remove_meshes_with_postfix.append("_e")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LOBE_W): model_modefier.remove_meshes_with_postfix.append("_w")
		
		var top_gap_offset: float = -1.0
		if MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_TOP_GAP):
			model_modefier.yoffset_n = top_gap_offset
			model_modefier.yoffset_s = top_gap_offset
			model_modefier.yoffset_w = top_gap_offset
			model_modefier.yoffset_e = top_gap_offset
			model_modefier.yoffset_c = top_gap_offset
		if MapGenerator.has_flag(pn, MapGenerator.Pixel.FLAG_WALL_TOP_GAP): model_modefier.yoffset_n = top_gap_offset
		if MapGenerator.has_flag(ps, MapGenerator.Pixel.FLAG_WALL_TOP_GAP): model_modefier.yoffset_s = top_gap_offset
		if MapGenerator.has_flag(pe, MapGenerator.Pixel.FLAG_WALL_TOP_GAP): model_modefier.yoffset_e = top_gap_offset
		if MapGenerator.has_flag(pw, MapGenerator.Pixel.FLAG_WALL_TOP_GAP): model_modefier.yoffset_w = top_gap_offset
		
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_SKIRT_FN_E):	model_modefier.remove_meshes_with_postfix.append("_skirt_fn_e")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_SKIRT_FS_E):	model_modefier.remove_meshes_with_postfix.append("_skirt_fs_e")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_SKIRT_FN_W):	model_modefier.remove_meshes_with_postfix.append("_skirt_fn_w")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_SKIRT_FS_W):	model_modefier.remove_meshes_with_postfix.append("_skirt_fs_w")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_SKIRT_FE_N):	model_modefier.remove_meshes_with_postfix.append("_skirt_fe_n")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_SKIRT_FW_N):	model_modefier.remove_meshes_with_postfix.append("_skirt_fw_n")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_SKIRT_FE_S):	model_modefier.remove_meshes_with_postfix.append("_skirt_fe_s")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_SKIRT_FW_S):	model_modefier.remove_meshes_with_postfix.append("_skirt_fw_s")
		
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LINE_FN_E):	model_modefier.remove_meshes_with_postfix.append("_line_fn_e")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LINE_FS_E):	model_modefier.remove_meshes_with_postfix.append("_line_fs_e")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LINE_FN_W):	model_modefier.remove_meshes_with_postfix.append("_line_fn_w")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LINE_FS_W):	model_modefier.remove_meshes_with_postfix.append("_line_fs_w")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LINE_FE_N):	model_modefier.remove_meshes_with_postfix.append("_line_fe_n")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LINE_FW_N):	model_modefier.remove_meshes_with_postfix.append("_line_fw_n")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LINE_FE_S):	model_modefier.remove_meshes_with_postfix.append("_line_fe_s")
		if !MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_WALL_LINE_FW_S):	model_modefier.remove_meshes_with_postfix.append("_line_fw_s")
		
		#	FLAG_WALL_SKIRT_FN_E         = 0x000001000000, # skirt FacingNorth, on eastern 'lobe' 
		#	FLAG_WALL_SKIRT_FS_E         = 0x000002000000,
		#	FLAG_WALL_SKIRT_FN_W         = 0x000004000000,
		#	FLAG_WALL_SKIRT_FS_W         = 0x000008000000,
		#	FLAG_WALL_SKIRT_FE_N         = 0x000010000000,
		#	FLAG_WALL_SKIRT_FW_N         = 0x000020000000,
		#	FLAG_WALL_SKIRT_FE_S         = 0x000040000000,
		#	FLAG_WALL_SKIRT_FW_S         = 0x000080000000,
		
	if (pc & MapGenerator.TILE_MASK) == MapGenerator.Pixel.TILE_ARCH:
		model_modefier = ModelModefier.new()
		if MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_ARCH_ROT_TO_E):
			angle += PI/2.0
		if MapGenerator.has_flag(pc, MapGenerator.Pixel.FLAG_ARCH_MIRROR):
			angle += PI
	
	_place_wall_specific(wall_model_x, tile_index, angle, model_modefier)

	#if  ( wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall_specific(wall_model_x, tile_index, 0.0, null)
	#elif( wall_n &&  wall_s &&  wall_e && !wall_w): _place_wall_specific(wall_model_t, tile_index, 0.0, ModelModefier.new())
	#elif( wall_n &&  wall_s && !wall_e &&  wall_w): _place_wall_specific(wall_model_t, tile_index, PI)
	#elif( wall_n &&  wall_s && !wall_e && !wall_w): _place_wall_specific(wall_model_i, tile_index, 0.0)
	#elif( wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall_specific(wall_model_t, tile_index, -PI/2)
	#elif( wall_n && !wall_s &&  wall_e && !wall_w): _place_wall_specific(wall_model_l, tile_index, -PI/2)
	#elif( wall_n && !wall_s && !wall_e &&  wall_w): _place_wall_specific(wall_model_l, tile_index, PI)
	#elif( wall_n && !wall_s && !wall_e && !wall_w): _place_wall_specific(wall_model_e, tile_index, PI)
	#elif(!wall_n &&  wall_s &&  wall_e &&  wall_w): _place_wall_specific(wall_model_t, tile_index, PI/2)
	#elif(!wall_n &&  wall_s &&  wall_e && !wall_w): _place_wall_specific(wall_model_l, tile_index, 0.0)
	#elif(!wall_n &&  wall_s && !wall_e &&  wall_w): _place_wall_specific(wall_model_l, tile_index, PI/2)
	#elif(!wall_n &&  wall_s && !wall_e && !wall_w): _place_wall_specific(wall_model_e, tile_index, 0.0)
	#elif(!wall_n && !wall_s &&  wall_e &&  wall_w): _place_wall_specific(wall_model_i, tile_index, PI/2)
	#elif(!wall_n && !wall_s &&  wall_e && !wall_w): _place_wall_specific(wall_model_e, tile_index, -PI/2)
	#elif(!wall_n && !wall_s && !wall_e &&  wall_w): _place_wall_specific(wall_model_e, tile_index, PI/2)
	#elif(!wall_n && !wall_s && !wall_e && !wall_w): _place_wall_specific(wall_model_x, tile_index, 0.0)
	
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
	var section: MapGenerator.Section = generator.generate_map(x0, y0, x0 + CHUNK_SIZE, y0 + CHUNK_SIZE, 8)
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

func _instantiate_model(model: Model, tile_index: Vector2i, angle: float, model_modefier: ModelModefier = null) -> void:
	var placed_tile: PlacedTile
	if placed_tiles.has(tile_index):
		placed_tile = placed_tiles[tile_index]
	else:
		placed_tile = PlacedTile.new()
		placed_tiles[tile_index] = placed_tile
	
	placed_tile.models[model.id] = model
	placed_tile.model_modefier = model_modefier
	placed_tile.angle = angle
	placed_tile.tile_index = tile_index

func _get_wall_t_px(x: int, y: int) -> Vector2i:
	var wall_c: bool = MapGenerator.is_wall(_get_pixel_at(x, y))
	if !wall_c:
		return Vector2i(0, 0)
	var wall_n: bool = MapGenerator.is_wall(_get_pixel_at(x, y - 1))
	var wall_s: bool = MapGenerator.is_wall(_get_pixel_at(x, y + 1))
	var wall_e: bool = MapGenerator.is_wall(_get_pixel_at(x + 1, y))
	var wall_w: bool = MapGenerator.is_wall(_get_pixel_at(x - 1, y))
	if int(wall_n) + int(wall_s) + int(wall_e) + int(wall_w) != 3:
		return Vector2i(0, 0)
	if !wall_n: return Vector2i(x, y + 1)
	if !wall_s: return Vector2i(x, y - 1)
	if !wall_e: return Vector2i(x - 1, y)
	if !wall_w: return Vector2i(x + 1, y)
	return Vector2i(0, 0)

func _add_tile(section: MapGenerator.Section, x: int, y: int) -> void:
	var pixel: MapGenerator.Pixel = section.get_pixel(x, y)
	var tile_index: Vector2i = Vector2i(x, y)
	
	# ALWAYS add a floor and ceiling
	_instantiate_model(model_floor, tile_index, 0)
	if (((pixel & MapGenerator.TILE_MASK) != MapGenerator.Pixel.TILE_CEILING_LIGHT) && 
		((pixel & MapGenerator.TILE_MASK) != MapGenerator.Pixel.TILE_CEILING_LIGHT_BLINKING)):
		_instantiate_model(model_ceiling, tile_index, 0)
	
	match pixel & MapGenerator.TILE_MASK:
		MapGenerator.Pixel.TILE_EMPTY:
			return
			
		MapGenerator.Pixel.TILE_CEILING_LIGHT:
			_instantiate_model(model_ceiling_light, tile_index, 0)
			
		MapGenerator.Pixel.TILE_CEILING_LIGHT_BLINKING:
			_instantiate_model(model_ceiling_light_blinking, tile_index, 0)

		MapGenerator.Pixel.TILE_ARCH:
			_place_wall(model_arch_i, null, model_arch_e, tile_index)
		
		MapGenerator.Pixel.TILE_WALL: # gap handled in '_place_wall'
			_place_wall(model_wall_x, null, null, tile_index)

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


func _handle_model_modefier_should_remove_node(node: Node3D, model_modefier: ModelModefier) -> bool:
	if model_modefier:
		for postfix in model_modefier.remove_meshes_with_postfix:
			if node.name.ends_with(postfix):
				return true
	return false

func _handle_model_modefier_of_node(node: Node3D, model_modefier: ModelModefier) -> void:
	if model_modefier == null:
		return
	
	if _handle_model_modefier_should_remove_node(node, model_modefier):
		node.queue_free()
		return

	if node.name.ends_with("offs_n"): 
		node.position.y += model_modefier.yoffset_n
	if node.name.ends_with("offs_s"): 
		node.position.y += model_modefier.yoffset_s
	if node.name.ends_with("offs_w"): 
		node.position.y += model_modefier.yoffset_w
	if node.name.ends_with("offs_e"): 
		node.position.y += model_modefier.yoffset_e
	if node.name.ends_with("offs_c"): 
		node.position.y += model_modefier.yoffset_c
		
	
func _handle_model_modefier(graphic: Node3D, model_modefier: ModelModefier) -> void:
	if model_modefier == null:
		return
	for child: Node in graphic.get_children():
		if child is Node3D:
			_handle_model_modefier_of_node(child as Node3D, model_modefier)

var _collision_tiles_cache: HandleTilesCache = HandleTilesCache.new() # Vector2i, bool   ( bool not used. treat as std::set )
func _handle_static_collision_shapes() -> void:
	var create: Callable = func(placed_tile: PlacedTile, chunk: Chunk) -> void:
		for model: Model in placed_tile.models.values():
			if (model.collisions.size() > 0) && (!placed_tile.collision_shapes.has(model.id)):
				#print("Collision '" + str(model.id) + "' place!")
				var added_shapes: Array[CollisionShape3D] = []
				for collision: CollisionShape3D in model.collisions:
					var tile_pos: Vector3 = Vector3(float(placed_tile.tile_index.x) * TILE_SIZE, 0.0, float(placed_tile.tile_index.y) * TILE_SIZE)
					if !_handle_model_modefier_should_remove_node(collision, placed_tile.model_modefier):
						var collision_shape: CollisionShape3D = collision.duplicate()
						collision_shape.transform.origin += tile_pos
						collision_shape.rotate_y(placed_tile.angle)
						chunk.static_body_3d.add_child(collision_shape)
						added_shapes.append(collision_shape)
						_handle_model_modefier_of_node(collision_shape, placed_tile.model_modefier)
				placed_tile.collision_shapes[model.id] = added_shapes
				
	var remove: Callable = func(placed_tile: PlacedTile) -> void:
		for collision_shapes: Array[CollisionShape3D] in placed_tile.collision_shapes.values():
			for collision_shape in collision_shapes:
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
				if placed_tile.model_modefier:
					_handle_model_modefier(graphic, placed_tile.model_modefier)
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

func _get_collision_shapes(resource: PackedScene) -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	var inst: Node3D = resource.instantiate()
	for child: Node in inst.get_children():
		if child is CollisionShape3D:
			var shape: CollisionShape3D = child.duplicate() as CollisionShape3D
			shapes.append(shape)
	inst.queue_free()
	return shapes

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
	retval.collisions = _get_collision_shapes(tile)
	retval.id = last_model_id
	return retval

func _get_center_chunk_pos(chunk_index: Vector2i) -> Vector2:
	return Vector2((float(chunk_index.x * CHUNK_SIZE)) + CHUNK_SIZE/2.0, (float(chunk_index.y * CHUNK_SIZE)) + CHUNK_SIZE / 2.0)
