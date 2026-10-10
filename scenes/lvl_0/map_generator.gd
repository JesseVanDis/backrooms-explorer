extends Node

class_name MapGenerator

const CHANCE_BLINKING_LIGHT = 0.004

const BIOME_MASK                 = 0x0000000000FF
const WALL_MASK                  = 0x00000000FF00
const TILE_MASK                  = 0x000000FFFF00
const FLAG_MASK                  = 0xFFFFFF000000

enum Pixel {
	NONE                         = 0x000000000000,
	BIOME_MESS                   = 0x000000000001,
	BIOME_ROOMS                  = 0x000000000002,
	BIOME_ARCHES                 = 0x000000000003,
	BIOME_PILLARS                = 0x000000000004,
	TILE_WALL                    = 0x000000000100,
	TILE_ARCH                    = 0x000000000200,
	TILE_EMPTY                   = 0x000000010000,
	TILE_CEILING_LIGHT           = 0x000000020000,
	TILE_CEILING_LIGHT_BLINKING  = 0x000000030000,
	FLAG_WALL_SKIRT_FN_E         = 0x000001000000, # skirt FacingNorth, on eastern 'lobe' 
	FLAG_WALL_SKIRT_FS_E         = 0x000002000000,
	FLAG_WALL_SKIRT_FN_W         = 0x000004000000,
	FLAG_WALL_SKIRT_FS_W         = 0x000008000000,
	FLAG_WALL_SKIRT_FE_N         = 0x000010000000,
	FLAG_WALL_SKIRT_FW_N         = 0x000020000000,
	FLAG_WALL_SKIRT_FE_S         = 0x000040000000,
	FLAG_WALL_SKIRT_FW_S         = 0x000080000000,
	FLAG_WALL_LINE_FN_E          = 0x000100000000,
	FLAG_WALL_LINE_FS_E          = 0x000200000000,
	FLAG_WALL_LINE_FN_W          = 0x000400000000,
	FLAG_WALL_LINE_FS_W          = 0x000800000000,
	FLAG_WALL_LINE_FE_N          = 0x001000000000,
	FLAG_WALL_LINE_FW_N          = 0x002000000000,
	FLAG_WALL_LINE_FE_S          = 0x004000000000,
	FLAG_WALL_LINE_FW_S          = 0x008000000000,
	FLAG_WALL_LOBE_N             = 0x010000000000,
	FLAG_WALL_LOBE_S             = 0x020000000000,
	FLAG_WALL_LOBE_E             = 0x040000000000,
	FLAG_WALL_LOBE_W             = 0x080000000000,
	FLAG_WALL_TOP_GAP            = 0x100000000000,
	FLAG_ARCH_ROT_TO_E           = 0x000001000000,
	FLAG_ARCH_MIRROR             = 0x000002000000,
	INVALID                      = 0x7FFFFFFFFFFFFFFF
}

#
#               FW_N | FE_N
#  FN_W    FN_W/FW_N | FE_N/FN_E   FN_E
#  ------------------+-------------------
#  FS_W    FS_W/FW_S | FE_S/FS_E   FS_E
#               FW_S | FE_S

enum WallFace {
	FN_E         = 0x01, # FacingNorth, on eastern 'lobe' 
	FS_E         = 0x02,
	FN_W         = 0x04,
	FS_W         = 0x08,
	FE_N         = 0x10,
	FW_N         = 0x20,
	FE_S         = 0x40,
	FW_S         = 0x80,	
}

const all_wall_faces: Array[WallFace] = [WallFace.FN_E, WallFace.FS_E, WallFace.FN_W, WallFace.FS_W, WallFace.FE_N, WallFace.FW_N, WallFace.FE_S, WallFace.FW_S]

func _ceiling_light(ctx: Context, misplacement_chance: float, interval_range: int, offset: int) -> bool:
	#if(posmod(ctx.x, 5) == 1 && posmod(ctx.y, 5) == 1):
	#	return true
	
	#@warning_ignore("integer_division")
	#var grid_x = ctx.x / interval_range as int
	#@warning_ignore("integer_division")
	#var grid_y = ctx.y / interval_range as int

	var grid_x := floori(float(ctx.x) / float(interval_range))
	var grid_y := floori(float(ctx.y) / float(interval_range))
	var light_pos_x: int = (grid_x * interval_range) + offset
	var light_pos_y: int = (grid_y * interval_range) + offset
	var random: float = ctx.random_with_seed(hash(Vector2i(grid_x, grid_y)))
	if random < misplacement_chance:
		if random < 0.25 * misplacement_chance:
			light_pos_x = light_pos_x+1
		elif random < 0.5 * misplacement_chance:
			light_pos_y = light_pos_y+1
		elif random < 0.75 * misplacement_chance:
			light_pos_x = light_pos_x-1
		else:
			light_pos_y = light_pos_y-1
		
	if ctx.x == light_pos_x && ctx.y == light_pos_y:
		return true
	return false

func _extend_walls(ctx: Context) -> bool:
	var pp: PreviousPass = ctx.previous_pass
	if !pp.wall_c:
		if pp.wall_nw || pp.wall_ne || pp.wall_sw || pp.wall_se: return false
		if pp.wall_w && pp.wall_ww && !pp.wall_n && !pp.wall_s: return true
		if pp.wall_e && pp.wall_ee && !pp.wall_n && !pp.wall_s: return true
		if pp.wall_n && pp.wall_nn && !pp.wall_w && !pp.wall_e: return true
		if pp.wall_s && pp.wall_ss && !pp.wall_w && !pp.wall_e: return true
	return false

func _retract_walls(ctx: Context) -> bool:
	var pp: PreviousPass = ctx.previous_pass
	if pp.wall_c:
		if pp.wall_n && !pp.wall_s: return true
		if pp.wall_s && !pp.wall_n: return true
		if pp.wall_w && !pp.wall_e: return true
		if pp.wall_e && !pp.wall_w: return true
	return false

func _is_isolated_wall_dot(ctx: Context) -> bool:
	var pp: PreviousPass = ctx.previous_pass
	if pp.wall_c:
		return !pp.wall_e && !pp.wall_w && !pp.wall_n && !pp.wall_s
	return false

func _is_isolated_wall_dot_at_offset(ctx: Context, offset_x: int, offset_y: int) -> bool:
	var c: bool = _is_wall_at_offset(ctx, offset_x, offset_y)
	if c:
		var n: bool = _is_wall_at_offset(ctx, offset_x, offset_y - 1)
		var s: bool = _is_wall_at_offset(ctx, offset_x, offset_y + 1)
		var e: bool = _is_wall_at_offset(ctx, offset_x + 1, offset_y)
		var w: bool = _is_wall_at_offset(ctx, offset_x - 1, offset_y)
		return !e && !w && !n && !s
	return false

static func is_wall(pixel: Pixel) -> bool:
	return pixel & WALL_MASK != 0

static func _is_wall_at_offset(ctx: Context, offset_x: int, offset_y: int) -> bool:
	return is_wall(ctx.get_at_offset(ctx.previous_pass.data, offset_x, offset_y))

static func with_flag(pixel: Pixel, flag: Pixel) -> Pixel:
	return (pixel as int | flag as int) as Pixel

static func has_flag(pixel: Pixel, flag: Pixel) -> bool:
	return pixel & flag != 0

static func is_wall_arch(pixel: Pixel) -> bool:
	var tile: Pixel = pixel & TILE_MASK as Pixel
	return tile == Pixel.TILE_ARCH

func _is_open_corner(ctx: Context) -> bool:
	var pp: PreviousPass = ctx.previous_pass
	if !pp.wall_c:
		if (pp.wall_w && pp.wall_ww) && (pp.wall_n || pp.wall_s): return true
		if (pp.wall_e && pp.wall_ee) && (pp.wall_n || pp.wall_s): return true
		if (pp.wall_n && pp.wall_nn) && (pp.wall_e || pp.wall_w): return true
		if (pp.wall_s && pp.wall_ss) && (pp.wall_e || pp.wall_w): return true
	return false

func _is_corner(ctx: Context) -> bool:
	var pp: PreviousPass = ctx.previous_pass
	if pp.wall_c:
		if pp.wall_n && pp.wall_e: return true
		if pp.wall_n && pp.wall_w: return true
		if pp.wall_s && pp.wall_e: return true
		if pp.wall_s && pp.wall_w: return true
		if pp.wall_w && pp.wall_n: return true
		if pp.wall_w && pp.wall_s: return true
		if pp.wall_e && pp.wall_n: return true
		if pp.wall_e && pp.wall_s: return true
	return false

func _is_wall_deadend(ctx: Context) -> bool:
	if ctx.previous_pass.wall_c:
		var wall_w: bool =  ctx.previous_pass.wall_w;
		var wall_e: bool =  ctx.previous_pass.wall_e;
		var wall_s: bool =  ctx.previous_pass.wall_s;
		var wall_n: bool =  ctx.previous_pass.wall_n;
		if(wall_w && !wall_n && !wall_s && !wall_e): return true
		if(!wall_w && wall_n && !wall_s && !wall_e): return true
		if(!wall_w && !wall_n && wall_s && !wall_e): return true
		if(!wall_w && !wall_n && !wall_s && wall_e): return true
	return false

# returns (0,0) if at a corner or intersection. direction is otherwise normalized.
func _get_wall_direction(ctx: Context) -> Vector2i:
	var pp: PreviousPass = ctx.previous_pass
	if pp.wall_c:
		if _is_junction(ctx):
			return Vector2i(0, 0)
		if _is_isolated_wall_dot(ctx):
			return Vector2i(0, 0)
		if pp.wall_n || pp.wall_s:
			return Vector2i(0, 1)
		if pp.wall_e || pp.wall_w:
			return Vector2i(1, 0)
	return Vector2i(0, 0)

func _get_wall_direction_at_offset(ctx: Context, offset_x: int, offset_y: int) -> Vector2i:
	if _is_wall_at_offset(ctx, offset_x, offset_y):
		if _is_junction_at_offset(ctx, offset_x, offset_y):
			return Vector2i(0, 0)
		if _is_isolated_wall_dot_at_offset(ctx, offset_x, offset_y):
			return Vector2i(0, 0)
		
		var n: bool = _is_wall_at_offset(ctx, offset_x, offset_y - 1)
		var s: bool = _is_wall_at_offset(ctx, offset_x, offset_y + 1)
		var e: bool = _is_wall_at_offset(ctx, offset_x + 1, offset_y)
		var w: bool = _is_wall_at_offset(ctx, offset_x - 1, offset_y)
		
		if n || s:
			return Vector2i(0, 1)
		if e || w:
			return Vector2i(1, 0)
	return Vector2i(0, 0)

func _has_wall_face_at_offset(ctx: Context, face: WallFace, offset_x: int, offset_y: int) -> bool:
	var c: bool = _is_wall_at_offset(ctx, offset_x, offset_y)
	
	if !c:
		return false
	
	match face:
		WallFace.FN_E, WallFace.FS_E: return _is_wall_at_offset(ctx, offset_x + 1, offset_y);
		WallFace.FN_W, WallFace.FS_W: return _is_wall_at_offset(ctx, offset_x - 1, offset_y);
		WallFace.FE_N, WallFace.FW_N: return _is_wall_at_offset(ctx, offset_x, offset_y - 1);
		WallFace.FE_S, WallFace.FW_S: return _is_wall_at_offset(ctx, offset_x, offset_y + 1);
	
	return false

# returns attached faces using the mask. so expect something like WallFace.FN_E | WallFace.FE_N
func _get_attached_faces_at_offset(ctx: Context, face: WallFace, offset_x: int, offset_y: int, accept_90_deg_angles: bool, include_self: bool = false) -> int:
	
	var test_x_c: int = clamp(ctx.lx + offset_x, 0, ctx.w - 1)
	var test_y_c: int = clamp(ctx.ly + offset_y, 0, ctx.h - 1)
	var c: bool = ctx.previous_pass.data[(test_x_c) + (test_y_c) * ctx.w] & WALL_MASK != 0
	
	if !c:
		return 0
	
	var retval: int = 0
	if include_self:
		retval |= int(face)
	
	#
	#               FW_N | FE_N
	#  FN_W    FN_W/FW_N | FE_N/FN_E   FN_E
	#  ------------------+-------------------
	#  FS_W    FS_W/FW_S | FE_S/FS_E   FS_E
	#               FW_S | FE_S
	
	match face:
		WallFace.FN_E:
			var test_x_n1: int = clamp(ctx.lx + (offset_x-1), 0, ctx.w - 1)
			var test_y_p1: int = clamp(ctx.ly + (offset_y+1), 0, ctx.h - 1)
			var n: bool = ctx.previous_pass.data[(test_x_c) + (test_y_p1) * ctx.w] & WALL_MASK != 0
			var w: bool = ctx.previous_pass.data[(test_x_n1) + (test_y_c) * ctx.w] & WALL_MASK != 0
			if accept_90_deg_angles && n:	retval |= int(WallFace.FE_N)
			if !n && w: 					retval |= int(WallFace.FN_W)
		WallFace.FN_W:
			var test_x_p1: int = clamp(ctx.lx + (offset_x+1), 0, ctx.w - 1)
			var test_y_p1: int = clamp(ctx.ly + (offset_y+1), 0, ctx.h - 1)
			var n: bool = ctx.previous_pass.data[(test_x_c) + (test_y_p1) * ctx.w] & WALL_MASK != 0
			var e: bool = ctx.previous_pass.data[(test_x_p1) + (test_y_c) * ctx.w] & WALL_MASK != 0
			if accept_90_deg_angles && n:	retval |= int(WallFace.FW_N)
			if !n && e:						retval |= int(WallFace.FN_E)
		WallFace.FS_E:
			var test_x_n1: int = clamp(ctx.lx + (offset_x-1), 0, ctx.w - 1)
			var test_y_n1: int = clamp(ctx.ly + (offset_y-1), 0, ctx.h - 1)
			var s: bool = ctx.previous_pass.data[(test_x_c) + (test_y_n1) * ctx.w] & WALL_MASK != 0
			var w: bool = ctx.previous_pass.data[(test_x_n1) + (test_y_c) * ctx.w] & WALL_MASK != 0
			if accept_90_deg_angles && s:	retval |= int(WallFace.FE_S)
			if !s && w:						retval |= int(WallFace.FS_W)
		WallFace.FS_W:
			var test_x_p1: int = clamp(ctx.lx + (offset_x+1), 0, ctx.w - 1)
			var test_y_n1: int = clamp(ctx.ly + (offset_y-1), 0, ctx.h - 1)
			var s: bool = ctx.previous_pass.data[(test_x_c) + (test_y_n1) * ctx.w] & WALL_MASK != 0
			var e: bool = ctx.previous_pass.data[(test_x_p1) + (test_y_c) * ctx.w] & WALL_MASK != 0
			if accept_90_deg_angles && s:	retval |= int(WallFace.FW_S)
			if !s && e:						retval |= int(WallFace.FS_E)
		WallFace.FW_N:
			var test_x_n1: int = clamp(ctx.lx + (offset_x-1), 0, ctx.w - 1)
			var test_y_n1: int = clamp(ctx.ly + (offset_y-1), 0, ctx.h - 1)
			var w: bool = ctx.previous_pass.data[(test_x_n1) + (test_y_c) * ctx.w] & WALL_MASK != 0
			var s: bool = ctx.previous_pass.data[(test_x_c) + (test_y_n1) * ctx.w] & WALL_MASK != 0
			if accept_90_deg_angles && w:	retval |= int(WallFace.FN_W)
			if !w && s:						retval |= int(WallFace.FW_S)
		WallFace.FE_N:
			var test_x_p1: int = clamp(ctx.lx + (offset_x+1), 0, ctx.w - 1)
			var test_y_n1: int = clamp(ctx.ly + (offset_y-1), 0, ctx.h - 1)
			var e: bool = ctx.previous_pass.data[(test_x_p1) + (test_y_c) * ctx.w] & WALL_MASK != 0
			var s: bool = ctx.previous_pass.data[(test_x_c) + (test_y_n1) * ctx.w] & WALL_MASK != 0
			if accept_90_deg_angles && e:	retval |= int(WallFace.FN_E)
			if !e && s:						retval |= int(WallFace.FE_S)
		WallFace.FW_S:
			var test_x_n1: int = clamp(ctx.lx + (offset_x-1), 0, ctx.w - 1)
			var test_y_p1: int = clamp(ctx.ly + (offset_y+1), 0, ctx.h - 1)
			var n: bool = ctx.previous_pass.data[(test_x_c) + (test_y_p1) * ctx.w] & WALL_MASK != 0
			var w: bool = ctx.previous_pass.data[(test_x_n1) + (test_y_c) * ctx.w] & WALL_MASK != 0
			if accept_90_deg_angles && w:	retval |= int(WallFace.FS_W)
			if !w && n:						retval |= int(WallFace.FW_N)
		WallFace.FE_S:
			var test_x_p1: int = clamp(ctx.lx + (offset_x+1), 0, ctx.w - 1)
			var test_y_p1: int = clamp(ctx.ly + (offset_y+1), 0, ctx.h - 1)
			var n: bool = ctx.previous_pass.data[(test_x_c) + (test_y_p1) * ctx.w] & WALL_MASK != 0
			var e: bool = ctx.previous_pass.data[(test_x_p1) + (test_y_c) * ctx.w] & WALL_MASK != 0
			if accept_90_deg_angles && e:	retval |= int(WallFace.FS_E)
			if !e && n:						retval |= int(WallFace.FE_N)
	
	return retval

func _get_neighbor_offset_for_face(face: WallFace, offset_x: int, offset_y: int) -> Vector2i:
	match face:
		WallFace.FW_N:	return Vector2i(offset_x, offset_y - 1)
		WallFace.FE_N:	return Vector2i(offset_x, offset_y - 1)
		WallFace.FW_S:	return Vector2i(offset_x, offset_y + 1)
		WallFace.FE_S:	return Vector2i(offset_x, offset_y + 1)
		WallFace.FN_E:	return Vector2i(offset_x + 1, offset_y)
		WallFace.FS_E:	return Vector2i(offset_x + 1, offset_y)
		WallFace.FN_W:	return Vector2i(offset_x - 1, offset_y)
		WallFace.FS_W:	return Vector2i(offset_x - 1, offset_y)
	return Vector2i(offset_x, offset_y)

static func _get_linked_face(face: WallFace) -> WallFace:
	match face:
		WallFace.FW_N:	return WallFace.FW_S
		WallFace.FE_N:	return WallFace.FE_S
		WallFace.FW_S:	return WallFace.FW_N
		WallFace.FE_S:	return WallFace.FE_N
		WallFace.FN_E:	return WallFace.FN_W
		WallFace.FS_E:	return WallFace.FS_W
		WallFace.FN_W:	return WallFace.FN_E
		WallFace.FS_W:	return WallFace.FS_E
	return face
	
func _get_connected_walls_at_offset(ctx: Context, face: WallFace, offset_x: int, offset_y: int, accept_90_deg_angles: bool, include_self: bool = false, limit: int = 50) -> Array[Vector3i]:
	var connected: Dictionary = {} # (index_x, index_y, WallFace), bool
	var visited: Dictionary = {} # (index_x, index_y, WallFace), bool
	
	var stack: Array = [[face, offset_x, offset_y, limit]]
	
	while stack.size() > 0:
		var current: Array = stack.pop_back()
		var curr_face: WallFace = current[0]
		var curr_x: int = current[1]
		var curr_y: int = current[2]
		var curr_limit: int = current[3]
		
		if curr_limit <= 0:
			continue
			
		var position := Vector3i(curr_x, curr_y, int(curr_face))
		if visited.has(position):
			continue
		visited[position] = true
		
		if !_has_wall_face_at_offset(ctx, curr_face, curr_x, curr_y):
			continue
			
		connected[position] = true
		
		var attached_faces: int = _get_attached_faces_at_offset(ctx, curr_face, curr_x, curr_y, accept_90_deg_angles, true)
		
		for face_it in all_wall_faces:
			var attached_face: int = face_it & attached_faces
			if attached_face == 0:
				continue
			var next_offset := _get_neighbor_offset_for_face(attached_face, curr_x, curr_y)
			var linked_face: WallFace = _get_linked_face(attached_face)
			stack.push_back([linked_face, next_offset.x, next_offset.y, curr_limit - 1])

	if !include_self:
		connected.erase(Vector3i(offset_x, offset_y, int(face)))
	
	var retval: Array[Vector3i] = Array(connected.keys(), TYPE_VECTOR3I, &"", null)
	retval.sort()
	return retval

func _get_wall_face_hash(ctx: Context, face: WallFace, limit: int = 50) -> int:
	if !_has_wall_face_at_offset(ctx, face, 0, 0):
		return 0
	
	var cache_key: Vector3i = Vector3i(ctx.x, ctx.y, int(face) | (int(limit) << 18))
	var cached: Variant = ctx.pass_cache.get(cache_key)
	if cached != null:
		var cached_int: int = cached
		return cached_int
	
	var hash_vec3 := Vector3i(0,0,0)
	var connected_faces: Array[Vector3i] = _get_connected_walls_at_offset(ctx, face, 0, 0, false, false, limit)
	if connected_faces.size() == 0:
		return 0
	connected_faces.append(Vector3i(0, 0, int(face)))
	for v in connected_faces:
		var index_x: int = v.x + ctx.x
		var index_y: int = v.y + ctx.y
		hash_vec3.x += index_x
		hash_vec3.y += index_y
		hash_vec3.z += v.z
	
	var result: int = hash(hash_vec3)
	for v in connected_faces:
		var key: Vector3i = Vector3i(ctx.x + v.x, ctx.y + v.y, v.z | (int(limit) << 18))
		ctx.pass_cache[key] = result
		
	return result

func _get_wall_section_hash(ctx: Context, limit: int = 50) -> int:
	var direction: Vector2i = _get_wall_direction(ctx)
	if direction == Vector2i(0, 0):
		return 0
	
	var hash_vec: Vector4i = Vector4i(0, 0, 0, 0)
	if direction.y == 0:
		var max_x: int = 0
		var min_x: int = 0
		for x in range(0, limit):
			var next_direction: Vector2i = _get_wall_direction_at_offset(ctx, x, 0)
			max_x = x
			if next_direction != direction:
				break
		for x in range(0, limit):
			var next_direction: Vector2i = _get_wall_direction_at_offset(ctx, -x, 0)
			min_x = -x
			if next_direction != direction:
				break
		hash_vec = Vector4i(min_x + ctx.x, ctx.y, max_x + ctx.x, ctx.y)
		
	if direction.x == 0:
		var max_y: int = 0
		var min_y: int = 0
		for y in range(0, limit):
			var next_direction: Vector2i = _get_wall_direction_at_offset(ctx, 0, y)
			max_y = y
			if next_direction != direction:
				break
		for y in range(0, limit):
			var next_direction: Vector2i = _get_wall_direction_at_offset(ctx, 0, -y)
			min_y = -y
			if next_direction != direction:
				break
		hash_vec = Vector4i(ctx.x, min_y + ctx.y, ctx.x, max_y + ctx.y)
	return hash(hash_vec)
	

func _get_wall_length(_pp: PreviousPass, ctx: Context, limit: int = 10, offset_x: int = 0, offset_y: int = 0, check_diagonal: bool = true, visited: Dictionary = {}) -> int:
	var stack: Array = [[offset_x, offset_y]]
	var count := 0
	
	while stack.size() > 0 && count < limit:
		var curr: Array = stack.pop_back()
		var curr_x: int = curr[0]
		var curr_y: int = curr[1]
		
		var key := Vector2i(curr_x, curr_y)
		if visited.has(key):
			continue
		visited[key] = true
		
		if !_is_wall_at_offset(ctx, curr_x, curr_y):
			continue
			
		count += 1
		if count >= limit:
			break
			
		# Push neighbors to stack
		stack.push_back([curr_x + 1, curr_y])
		stack.push_back([curr_x - 1, curr_y])
		stack.push_back([curr_x, curr_y + 1])
		stack.push_back([curr_x, curr_y - 1])
		
		if check_diagonal:
			stack.push_back([curr_x + 1, curr_y - 1])
			stack.push_back([curr_x - 1, curr_y - 1])
			stack.push_back([curr_x + 1, curr_y + 1])
			stack.push_back([curr_x - 1, curr_y + 1])
			
	return count

func _is_junction(ctx: Context) -> bool:
	var pp: PreviousPass = ctx.previous_pass
	return pp.wall_c && ((pp.wall_n || pp.wall_s) && (pp.wall_w || pp.wall_e))

func _is_junction_at_offset(ctx: Context, offset_x: int, offset_y: int) -> bool:
	var c: bool = _is_wall_at_offset(ctx, offset_x, offset_y)
	var n: bool = _is_wall_at_offset(ctx, offset_x, offset_y - 1)
	var s: bool = _is_wall_at_offset(ctx, offset_x, offset_y + 1)
	var e: bool = _is_wall_at_offset(ctx, offset_x + 1, offset_y)
	var w: bool = _is_wall_at_offset(ctx, offset_x - 1, offset_y)
	return c && ((n || s) && (w || e))

func _connect_lobes(ctx: Context, current_pixel: Pixel) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	var pixel: Pixel = current_pixel
	if (pixel & TILE_MASK) == Pixel.TILE_WALL:
		if pp.wall_n:
			pixel = with_flag(pixel, Pixel.FLAG_WALL_LOBE_N)
		if pp.wall_s:
			pixel = with_flag(pixel, Pixel.FLAG_WALL_LOBE_S)
		if pp.wall_e:
			pixel = with_flag(pixel, Pixel.FLAG_WALL_LOBE_E)
		if pp.wall_w:
			pixel = with_flag(pixel, Pixel.FLAG_WALL_LOBE_W)
	return pixel

func _handle_walltypes(ctx: Context, current_pixel: Pixel) -> Pixel:
	var pixel: Pixel = current_pixel
	
	if (pixel & TILE_MASK) == Pixel.TILE_WALL:
		for wall_face in all_wall_faces:
			var face_hash: int = _get_wall_face_hash(ctx, wall_face)
			if face_hash != 0:
				var add_line: bool = ctx.random_with_seed(hash([face_hash, "line"])) > 0.5
				var add_skirt: bool = ctx.random_with_seed(hash([face_hash, "skirt"])) > 0.5
				if add_line:
					pixel = with_flag(pixel, _face_to_flag_wall_line(wall_face))
				if add_skirt:
					pixel = with_flag(pixel, _face_to_flag_wall_skirt(wall_face))
		
	return pixel


func _find_distance_to_deadend(pp: PreviousPass, ctx: Context, limit: int = 10, offset_x: int = 0, offset_y: int = 0, visited: Dictionary = {}) -> int:
	var stack: Array = [[offset_x, offset_y, 0]] # [x, y, distance]
	var min_dist: int = -1
	
	while stack.size() > 0:
		var curr: Array = stack.pop_back()
		var curr_x: int = curr[0]
		var curr_y: int = curr[1]
		var curr_dist: int = curr[2]
		
		if curr_dist >= limit:
			continue
			
		var key := Vector2i(curr_x, curr_y)
		if visited.has(key) && visited[key] <= curr_dist:
			continue
		visited[key] = curr_dist
		
		var c: bool = is_wall(ctx.get_at_offset(pp.data, curr_x, curr_y))
		if !c:
			continue
			
		var n: bool = is_wall(ctx.get_at_offset(pp.data, curr_x, curr_y - 1))
		var s: bool = is_wall(ctx.get_at_offset(pp.data, curr_x, curr_y + 1))
		var e: bool = is_wall(ctx.get_at_offset(pp.data, curr_x + 1, curr_y))
		var w: bool = is_wall(ctx.get_at_offset(pp.data, curr_x - 1, curr_y))
		
		var is_junction: bool = (n || s) && (e || w)
		if is_junction:
			continue
			
		var is_dead_end: bool = (int(n) + int(s) + int(e) + int(w)) == 1
		if is_dead_end:
			if min_dist == -1 || curr_dist < min_dist:
				min_dist = curr_dist
		else:
			if n: stack.push_back([curr_x, curr_y - 1, curr_dist + 1])
			if s: stack.push_back([curr_x, curr_y + 1, curr_dist + 1])
			if e: stack.push_back([curr_x + 1, curr_y, curr_dist + 1])
			if w: stack.push_back([curr_x - 1, curr_y, curr_dist + 1])
			
	return min_dist

#func _most_northern_ending_of_wall(pp: PreviousPass, ctx: Context, limit: int = 50, offset_x: int = 0, offset_y: int = 0, visited: Dictionary = {}) -> int:
	#if limit <= 0:
		#return 0xffffffff
	#var key := Vector2i(offset_x, offset_y)
	#if visited.has(key):
		#return 0xffffffff
	#visited[key] = true
	#var c: bool = is_wall(ctx.get_at_offset(pp.data, offset_x, offset_y))
	#if !c:
		#return 0xffffffff
	#var result: int = ctx.y + offset_y
	#result = min(result, _most_northern_ending_of_wall(pp, ctx, limit-1, offset_x, offset_y - 1, visited))
	#result = min(result, _most_northern_ending_of_wall(pp, ctx, limit-1, offset_x, offset_y + 1, visited))
	#result = min(result, _most_northern_ending_of_wall(pp, ctx, limit-1, offset_x + 1, offset_y, visited))
	#result = min(result, _most_northern_ending_of_wall(pp, ctx, limit-1, offset_x - 1, offset_y, visited))
	#return result

func _find_distance_to_junction(pp: PreviousPass, ctx: Context, limit: int = 10, offset_x: int = 0, offset_y: int = 0, visited: Dictionary = {}) -> int:
	if limit <= 0:
		return -1
	var key := Vector2i(offset_x, offset_y)
	if visited.has(key):
		return -1
	visited[key] = true
	var c: bool = is_wall(ctx.get_at_offset(pp.data, offset_x, offset_y))
	if !c:
		return -1
	var n: bool = is_wall(ctx.get_at_offset(pp.data, offset_x, offset_y - 1))
	var s: bool = is_wall(ctx.get_at_offset(pp.data, offset_x, offset_y + 1))
	var e: bool = is_wall(ctx.get_at_offset(pp.data, offset_x + 1, offset_y))
	var w: bool = is_wall(ctx.get_at_offset(pp.data, offset_x - 1, offset_y))
	var is_junction: bool = (n || s) && (e || w)
	if is_junction:
		return 0
	var result: int = -1
	if n:	result = max(result, _find_distance_to_junction(pp, ctx, limit-1, offset_x, offset_y - 1, visited))
	if s:	result = max(result, _find_distance_to_junction(pp, ctx, limit-1, offset_x, offset_y + 1, visited))
	if e:	result = max(result, _find_distance_to_junction(pp, ctx, limit-1, offset_x + 1, offset_y, visited))
	if w:	result = max(result, _find_distance_to_junction(pp, ctx, limit-1, offset_x - 1, offset_y, visited))
	if result >= 0:
		return result + 1
	return -1

func _is_wall_length_greater_then(pp: PreviousPass, ctx: Context, threshold: int, offset_x: int = 0, offset_y: int = 0, check_diagonal: bool = true) -> bool:
	if pp.wall_c && _get_wall_length(pp, ctx, threshold+1, offset_x, offset_y, check_diagonal) > threshold:
		return true
	return false

func _is_wall_length_lesser_then(pp: PreviousPass, ctx: Context, threshold: int, offset_x: int = 0, offset_y: int = 0, check_diagonal: bool = true) -> bool:
	if !pp.wall_c:
		return true
	return _get_wall_length(pp, ctx, threshold+1, offset_x, offset_y, check_diagonal) < threshold

const NUM_PASSES_IN_GEN_BIOMES = 1 # change this everytime you change the amount of cases in 'match pass_index' below
func _gen_biomes(pass_index: int, ctx: Context) -> Pixel:
	var noise_upscale: float = 0.01
	
	match pass_index:
		0:
			var noise := UtilsMath.fractal_noise_2d(ctx.x_flt * noise_upscale, ctx.y_flt * noise_upscale)
			if noise < 0.4:
				return Pixel.BIOME_ROOMS
			if noise < 0.44:
				return Pixel.BIOME_ARCHES
			if noise < 0.6:
				return Pixel.BIOME_MESS
			if noise < 0.62:
				return Pixel.BIOME_ARCHES
			else:
				return Pixel.BIOME_PILLARS

			# var grid_low_x: int = int(roundf(float(ctx.x) / 40.0))
			# var grid_low_y: int = int(roundf(float(ctx.y) / 40.0))
			# var random: float = ctx.random_with_seed(hash(Vector2i(grid_low_x, grid_low_y)))
			# if random < 0.2:
			# 	return Pixel.BIOME_PILLARS
			# if random < 0.6:
			# 	return Pixel.BIOME_MESS
			# else:
			# 	return Pixel.BIOME_ROOMS
	return Pixel.INVALID

func _test(pass_index: int, ctx: Context) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	
	match pass_index:
		0:
			# if ctx.x == 5 && ctx.y == 4: return Pixel.TILE_CEILING_LIGHT_BLINKING
			if ctx.x == 2 && ctx.y == 2: return Pixel.TILE_CEILING_LIGHT
			if ctx.x == 10 && ctx.y == 10: return Pixel.TILE_CEILING_LIGHT
			if ctx.x == 2 && ctx.y == 10: return Pixel.TILE_CEILING_LIGHT
			if ctx.x == 10 && ctx.y == 2: return Pixel.TILE_CEILING_LIGHT
			
			for x in range(4, 9):
				if ctx.x == x && ctx.y == 4: 
					if x <= 4:
						return with_flag(Pixel.TILE_WALL, Pixel.FLAG_WALL_SKIRT_FN_E | Pixel.FLAG_WALL_SKIRT_FW_S | Pixel.FLAG_WALL_LINE_FW_S)
					elif x >= 8:
						return with_flag(Pixel.TILE_WALL, Pixel.FLAG_WALL_SKIRT_FN_W)
					return with_flag(Pixel.TILE_WALL, Pixel.FLAG_WALL_SKIRT_FN_E | Pixel.FLAG_WALL_SKIRT_FN_W)

				if ctx.x == x && ctx.y == 8: 
					if x <= 4:
						return with_flag(Pixel.TILE_WALL, Pixel.FLAG_WALL_LINE_FS_E | Pixel.FLAG_WALL_SKIRT_FW_N | Pixel.FLAG_WALL_LINE_FW_N)
					elif x >= 8:
						return with_flag(Pixel.TILE_WALL, Pixel.FLAG_WALL_LINE_FS_W)
					return with_flag(Pixel.TILE_WALL, Pixel.FLAG_WALL_LINE_FS_E | Pixel.FLAG_WALL_LINE_FS_W)
					
			for y in range(5, 8):
				if ctx.x == 4 && ctx.y == y:
					return with_flag(Pixel.TILE_WALL, Pixel.FLAG_WALL_LINE_FW_N | Pixel.FLAG_WALL_LINE_FW_S | Pixel.FLAG_WALL_SKIRT_FW_N | Pixel.FLAG_WALL_SKIRT_FW_S)
					
				if ctx.x == 8 && ctx.y == y: return Pixel.TILE_WALL
			
			if ctx.x == 9 && ctx.y == 5: return with_flag(Pixel.TILE_WALL, Pixel.FLAG_WALL_TOP_GAP)
			if ctx.x == 10 && ctx.y == 5: return with_flag(Pixel.TILE_WALL, Pixel.FLAG_WALL_TOP_GAP)

			if ctx.x == 8 && ctx.y == 12: return Pixel.TILE_ARCH
			if ctx.x == 8 && ctx.y == 11: return with_flag(Pixel.TILE_ARCH, Pixel.FLAG_ARCH_MIRROR)

			if ctx.x == 11 && ctx.y == 8: return with_flag(with_flag(Pixel.TILE_ARCH, Pixel.FLAG_ARCH_ROT_TO_E), Pixel.FLAG_ARCH_MIRROR)
			if ctx.x == 12 && ctx.y == 8: return with_flag(Pixel.TILE_ARCH, Pixel.FLAG_ARCH_ROT_TO_E)
			
			return Pixel.TILE_EMPTY
		
		1:
			#if pp.wall_c:
				#var wall_face: WallFace = WallFace.FN_E
				#var fn_e_hash: int = _get_wall_face_hash(ctx, wall_face)
				#var wall_hash: int = _get_wall_section_hash(ctx)
				#print("wallhash [" + str(ctx.x) + "," + str(ctx.y) + ", " + str(wall_face) + "] = " + str(fn_e_hash))
			return _connect_lobes(ctx, pp.pixel_c)
			
	return Pixel.INVALID


func _gen(pass_index: int, ctx: Context) -> Pixel:
	#return _test(pass_index, ctx)
	
	var pp: PreviousPass = ctx.previous_pass
	var retval: Pixel = Pixel.INVALID
	if pass_index < NUM_PASSES_IN_GEN_BIOMES:
		retval = _gen_biomes(pass_index, ctx)
	else:
		var biome_pass_index: int = pass_index - NUM_PASSES_IN_GEN_BIOMES
		match pp.biome_c:
			Pixel.BIOME_MESS:
				retval = _gen_biome_mess(biome_pass_index, ctx)
			Pixel.BIOME_ROOMS:
				retval = _gen_biome_rooms(biome_pass_index, ctx)
			Pixel.BIOME_ARCHES:
				retval = _gen_biome_arches(biome_pass_index, ctx)
			Pixel.BIOME_PILLARS:
				retval = _gen_biome_pillars(biome_pass_index, ctx)
	
	# force empty area at spawn point
	if (ctx.x * ctx.x) < 100 && (ctx.y * ctx.y) < 100 && retval != Pixel.INVALID && pp.wall_c:
		retval = pp.with_tile(Pixel.TILE_EMPTY)
	return retval

func _gen_biome_mess(pass_index: int, ctx: Context) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	var num_neighbour_walls: int = 0;
	if pp.wall_w: num_neighbour_walls = num_neighbour_walls + 1
	if pp.wall_e: num_neighbour_walls = num_neighbour_walls + 1
	if pp.wall_s: num_neighbour_walls = num_neighbour_walls + 1
	if pp.wall_n: num_neighbour_walls = num_neighbour_walls + 1
	
	match pass_index:
		0:
			if ctx.random() > 0.9:
				return pp.with_tile(Pixel.TILE_WALL)
			if _ceiling_light(ctx, 0.7, 5, 2):
				return pp.with_tile(Pixel.TILE_CEILING_LIGHT)
			return pp.with_tile(Pixel.TILE_EMPTY)
	
		1: # make some lights blinking
			if pp.tile_c == Pixel.TILE_CEILING_LIGHT && ctx.random() < CHANCE_BLINKING_LIGHT:
				return pp.with_tile(Pixel.TILE_CEILING_LIGHT_BLINKING)
			return pp.no_change()
		
		2:
			if num_neighbour_walls > 0 && !pp.wall_c:
				if ctx.random() > 0.75:
					return pp.with_tile(Pixel.TILE_WALL)
			return pp.no_change()
			
		3:
			if _is_isolated_wall_dot(ctx):
				return pp.with_tile(Pixel.TILE_EMPTY)
			return pp.no_change()
		
		4,5,6,7,8,9,10:
			if ctx.random() > 0.1:
				if _extend_walls(ctx):
					return pp.with_tile(Pixel.TILE_WALL)
			return pp.no_change()
		
		11:
			if ctx.random() > 0.1:
				if _extend_walls(ctx):
					return pp.with_tile(Pixel.TILE_WALL)
			if _is_isolated_wall_dot(ctx):
				return pp.with_tile(Pixel.TILE_EMPTY)
			return pp.no_change()
		
		12:
			return _handle_walltypes(ctx, _connect_lobes(ctx, pp.pixel_c))
		
		#12:
			#if pp.wall_c && _find_distance_to_deadend(pp, ctx, 5) < 3:
				#return pp.with_tile(Pixel.TILE_WALL_TOP_GAP)
			#return pp.no_change()
		
	return Pixel.INVALID

func _gen_biome_rooms(pass_index: int, ctx: Context) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	
	const grid_cell_size = 7
	var grid_x := floori(ctx.x_flt / grid_cell_size)
	var grid_y := floori(ctx.y_flt / grid_cell_size)
	var grid_local_x := (ctx.x - (grid_x * grid_cell_size))
	var grid_local_y := (ctx.y - (grid_y * grid_cell_size))

	var noise_upscale: float = 0.4
	
	match pass_index:
		0: # grid
			if grid_local_x == 0:
				return pp.with_tile(Pixel.TILE_WALL)
			if grid_local_y == 0:
				return pp.with_tile(Pixel.TILE_WALL)
			return pp.with_tile(Pixel.TILE_EMPTY)

		1: # openings
			if pp.tile_c == Pixel.TILE_WALL:
				var noise := UtilsMath.fractal_noise_2d(ctx.x_flt * noise_upscale, ctx.y_flt * noise_upscale)
				if noise > 0.55:
					return pp.with_tile(Pixel.TILE_EMPTY)
			return pp.no_change()
		
		2: # coridors
			return pp.no_change()

		3: # close open corners
			if _is_open_corner(ctx):
				return pp.with_tile(Pixel.TILE_WALL)
			return pp.no_change()

		4: # filter small walls
			if pp.wall_c && _is_wall_length_lesser_then(pp, ctx, 4):
				return pp.with_tile(Pixel.TILE_EMPTY)
			return pp.no_change()

		5: # lights
			if !pp.wall_c:
				if _ceiling_light(ctx, 0.1, 4, 2):
					return pp.with_tile(Pixel.TILE_CEILING_LIGHT)
			return pp.no_change()
		
		6: # make some lights blinking
			if pp.tile_c == Pixel.TILE_CEILING_LIGHT && ctx.random() < CHANCE_BLINKING_LIGHT:
				return pp.with_tile(Pixel.TILE_CEILING_LIGHT_BLINKING)
			return pp.no_change()
		
		7:
			if pp.wall_c && _is_wall_deadend(ctx) && ctx.random() > 0.70:
				var distance_to_deadend: int = _find_distance_to_deadend(pp, ctx, 5)
				var distance_to_junction: int = _find_distance_to_junction(pp, ctx, 5)
				if distance_to_deadend >= 0 && distance_to_junction >= 0:
					var total: int = distance_to_deadend + distance_to_junction
					if total <= 3:
						return with_flag(pp.with_tile(Pixel.TILE_WALL), Pixel.FLAG_WALL_TOP_GAP)
			return pp.no_change()
			
		8, 9, 10:
			if pp.wall_c && !_is_junction(ctx):
				if has_flag(pp.pixel_n, Pixel.FLAG_WALL_TOP_GAP): return with_flag(pp.pixel_c, Pixel.FLAG_WALL_TOP_GAP)
				if has_flag(pp.pixel_s, Pixel.FLAG_WALL_TOP_GAP): return with_flag(pp.pixel_c, Pixel.FLAG_WALL_TOP_GAP)
				if has_flag(pp.pixel_w, Pixel.FLAG_WALL_TOP_GAP): return with_flag(pp.pixel_c, Pixel.FLAG_WALL_TOP_GAP)
				if has_flag(pp.pixel_e, Pixel.FLAG_WALL_TOP_GAP): return with_flag(pp.pixel_c, Pixel.FLAG_WALL_TOP_GAP)
			return pp.no_change()
		
		11:
			return _handle_walltypes(ctx, _connect_lobes(ctx, pp.pixel_c))
			

	return Pixel.INVALID

func _gen_biome_arches(pass_index: int, ctx: Context) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	const grid_cell_size = 7
	var grid_x := floori(ctx.x_flt / grid_cell_size)
	var grid_y := floori(ctx.y_flt / grid_cell_size)
	var grid_local_x := (ctx.x - (grid_x * grid_cell_size))
	var grid_local_y := (ctx.y - (grid_y * grid_cell_size))

	var noise_upscale: float = 0.4
	
	match pass_index:
		0: # grid
			if grid_local_x == 0:
				return pp.with_tile(Pixel.TILE_ARCH)
			if grid_local_y == 0:
				return pp.with_tile(Pixel.TILE_ARCH)
			return pp.with_tile(Pixel.TILE_EMPTY)

		1: # openings
			if pp.tile_c == Pixel.TILE_ARCH:
				var noise := UtilsMath.fractal_noise_2d(ctx.x_flt * noise_upscale, ctx.y_flt * noise_upscale)
				if noise > 0.55:
					return pp.with_tile(Pixel.TILE_EMPTY)
			return pp.no_change()
		
		2: # coridors
			return pp.no_change()

		3: # filter small walls
			if pp.wall_c && _is_wall_length_lesser_then(pp, ctx, 4):
				return pp.with_tile(Pixel.TILE_EMPTY)
			return pp.no_change()

		4: # lights
			if !pp.wall_c:
				if _ceiling_light(ctx, 0.1, 4, 2):
					return pp.with_tile(Pixel.TILE_CEILING_LIGHT)
			return pp.no_change()
		
		5: # make some lights blinking
			if pp.tile_c == Pixel.TILE_CEILING_LIGHT && ctx.random() < CHANCE_BLINKING_LIGHT:
				return pp.with_tile(Pixel.TILE_CEILING_LIGHT_BLINKING)
			return pp.no_change()
		
		6:
			if pp.wall_c && _is_corner(ctx):
				return pp.with_tile(Pixel.TILE_EMPTY)
			return pp.no_change()
		
		7:
			if pp.wall_c && _is_wall_length_lesser_then(pp, ctx, 5, 0, 0, false): 
				return pp.with_tile(Pixel.TILE_EMPTY)
			return pp.no_change()
	
		8: # close open corners
			if _is_open_corner(ctx):
				return pp.with_tile(Pixel.TILE_WALL)
			var n: bool = (ctx.get_at_offset(pp.data,  0, -1) & TILE_MASK as Pixel) == Pixel.TILE_ARCH
			var s: bool = (ctx.get_at_offset(pp.data,  0,  1) & TILE_MASK as Pixel) == Pixel.TILE_ARCH
			var e: bool = (ctx.get_at_offset(pp.data, -1,  0) & TILE_MASK as Pixel) == Pixel.TILE_ARCH
			var w: bool = (ctx.get_at_offset(pp.data,  1,  0) & TILE_MASK as Pixel) == Pixel.TILE_ARCH
			if (n && s) || (w && e):
				return pp.with_tile(Pixel.TILE_ARCH)
			return pp.no_change()
	
		9: # alighn
			if pp.tile_c == Pixel.TILE_ARCH:# && ((ctx.x & 1) == 1 || (ctx.y & 1) == 1): 
				var n: bool = (ctx.get_at_offset(pp.data,  0, -1) & TILE_MASK as Pixel) == Pixel.TILE_ARCH
				var s: bool = (ctx.get_at_offset(pp.data,  0,  1) & TILE_MASK as Pixel) == Pixel.TILE_ARCH
				var e: bool = (ctx.get_at_offset(pp.data, -1,  0) & TILE_MASK as Pixel) == Pixel.TILE_ARCH
				var w: bool = (ctx.get_at_offset(pp.data,  1,  0) & TILE_MASK as Pixel) == Pixel.TILE_ARCH
				var pixel: Pixel = pp.pixel_c
				if (e || w):
					pixel = with_flag(pixel, Pixel.FLAG_ARCH_ROT_TO_E)
				if ((n || s) && (ctx.y & 1) == 1):
					pixel = with_flag(pixel, Pixel.FLAG_ARCH_MIRROR)
				if ((e || w) && (ctx.x & 1) == 1):
					pixel = with_flag(pixel, Pixel.FLAG_ARCH_MIRROR)
				return pixel
			return pp.no_change()
		
		10: # fix mis-alighned
			if !is_wall_arch(pp.tile_c):
				return pp.no_change() 
			var n: Pixel = (ctx.get_at_offset(pp.data,  0, -1) & TILE_MASK as Pixel)
			var s: Pixel = (ctx.get_at_offset(pp.data,  0,  1) & TILE_MASK as Pixel)
			var e: Pixel = (ctx.get_at_offset(pp.data, -1,  0) & TILE_MASK as Pixel)
			var w: Pixel = (ctx.get_at_offset(pp.data,  1,  0) & TILE_MASK as Pixel)
			
			# safety
			if !is_wall_arch(n) && !has_flag(pp.pixel_c, Pixel.FLAG_ARCH_ROT_TO_E) && !has_flag(pp.pixel_c, Pixel.FLAG_ARCH_MIRROR):
				if pp.wall_n: 
					return pp.with_tile(Pixel.TILE_WALL) 
				else: 
					return pp.with_tile(Pixel.TILE_EMPTY)
			if !is_wall_arch(s) && !has_flag(pp.pixel_c, Pixel.FLAG_ARCH_ROT_TO_E) && has_flag(pp.pixel_c, Pixel.FLAG_ARCH_MIRROR):
				if pp.wall_s: 
					return pp.with_tile(Pixel.TILE_WALL) 
				else: 
					return pp.with_tile(Pixel.TILE_EMPTY)
			if !is_wall_arch(e) && has_flag(pp.pixel_c, Pixel.FLAG_ARCH_ROT_TO_E) && !has_flag(pp.pixel_c, Pixel.FLAG_ARCH_MIRROR):
				if pp.wall_e: 
					return pp.with_tile(Pixel.TILE_WALL) 
				else: 
					return pp.with_tile(Pixel.TILE_EMPTY)
			if !is_wall_arch(w) && has_flag(pp.pixel_c, Pixel.FLAG_ARCH_ROT_TO_E) && has_flag(pp.pixel_c, Pixel.FLAG_ARCH_MIRROR):
				if pp.wall_w: 
					return pp.with_tile(Pixel.TILE_WALL) 
				else: 
					return pp.with_tile(Pixel.TILE_EMPTY)
			
			return pp.no_change()
	
		11:
			return _handle_walltypes(ctx, _connect_lobes(ctx, pp.pixel_c))
		
	return Pixel.INVALID

func _gen_biome_pillars(pass_index: int, ctx: Context) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	
	const grid_cell_size = 3
	var grid_x := floori(ctx.x_flt / grid_cell_size)
	var grid_y := floori(ctx.y_flt / grid_cell_size)
	var grid_local_x := (ctx.x - (grid_x * grid_cell_size))
	var grid_local_y := (ctx.y - (grid_y * grid_cell_size))
	
	match pass_index:
		0:
			if _ceiling_light(ctx, 1.0, 3, 1):
				return pp.with_tile(Pixel.TILE_CEILING_LIGHT)
			return pp.with_tile(Pixel.TILE_EMPTY)
		
		1: # make some lights blinking
			if pp.tile_c == Pixel.TILE_CEILING_LIGHT && ctx.random() < CHANCE_BLINKING_LIGHT:
				return pp.with_tile(Pixel.TILE_CEILING_LIGHT_BLINKING)
			return pp.no_change()
		
		2:
			var x_offset := 1
			var y_offset := 1
			if ((grid_local_x == x_offset + 0 && grid_local_y == y_offset + 0) || 
				(grid_local_x == x_offset + 0 && grid_local_y == y_offset + 1) ||
				(grid_local_x == x_offset + 1 && grid_local_y == y_offset + 0) || 
				(grid_local_x == x_offset + 1 && grid_local_y == y_offset + 1)):
					return pp.with_tile(Pixel.TILE_WALL)

		3,4,5,6,7,8:
			return pp.no_change()
		
		9:
			if pp.wall_c && _is_wall_length_lesser_then(pp, ctx, 4): 
				return pp.with_tile(Pixel.TILE_EMPTY)
			return pp.no_change()
		
		10:
			return _handle_walltypes(ctx, _connect_lobes(ctx, pp.pixel_c))

			
	return Pixel.INVALID

class Section:
	var x: int
	var y: int
	var w: int
	var h: int
	var data: Array[Pixel] = []
	
	func set_pixel(global_x: int, global_y: int, tile_type: Pixel) -> void:
		data[(global_x - x) + (global_y - y) * w] = tile_type;
		
	func get_pixel(global_x: int, global_y: int) -> Pixel:
		return data[(global_x - x) + (global_y - y) * w];

	func get_pixel_clamped(global_x: int, global_y: int) -> Pixel:
		return data[clamp(global_x - x, 0, w-1) + clamp(global_y - y, 0, h-1) * w];
	
	func _init(x0: int, y0: int, x1: int, y1: int) -> void:
		var size: int = (x1-x0) * (y1-y0)
		x = x0;
		y = y0;
		w = x1-x0;
		h = y1-y0;
		data.resize(size);

class PreviousPass:
	var data: Array[Pixel]
	
	var pixel_c: Pixel = Pixel.NONE
	var tile_c: Pixel = Pixel.NONE
	var biome_c: Pixel = Pixel.NONE
	var pixel_n: Pixel
	var pixel_nn: Pixel
	var pixel_s: Pixel
	var pixel_ss: Pixel
	var pixel_e: Pixel
	var pixel_ee: Pixel
	var pixel_w: Pixel
	var pixel_ww: Pixel
	var pixel_nw: Pixel
	var pixel_ne: Pixel
	var pixel_sw: Pixel
	var pixel_se: Pixel
	var wall_c: bool
	var wall_n: bool
	var wall_nn: bool
	var wall_s: bool
	var wall_ss: bool
	var wall_e: bool
	var wall_ee: bool
	var wall_w: bool
	var wall_ww: bool
	var wall_nw: bool
	var wall_ne: bool
	var wall_sw: bool
	var wall_se: bool
	
	func with_tile(tile: Pixel) -> Pixel:
		if tile & BIOME_MASK != 0:
			push_error("argument given to 'with_tile' MUST be a tile")
			return no_change()
		return (biome_c as int | tile as int) as Pixel

	func with_biome(biome: Pixel) -> Pixel:
		if biome & TILE_MASK != 0:
			push_error("argument given to 'with_biome' MUST be a biome")
			return no_change()
		return (tile_c as int | biome as int) as Pixel
		
	func no_change() -> Pixel:
		return pixel_c

	func update(ctx: Context) -> void:
		pixel_c = ctx.get_at(data)
		biome_c = TileUtils.get_biome(pixel_c)
		tile_c = (pixel_c & TILE_MASK) as Pixel

		var test_x_n2: int = clamp(ctx.lx - 2, 0, ctx.w - 1)
		var test_x_n1: int = clamp(ctx.lx - 1, 0, ctx.w - 1)
		var test_x_p0: int = clamp(ctx.lx + 0, 0, ctx.w - 1)
		var test_x_p1: int = clamp(ctx.lx + 1, 0, ctx.w - 1)
		var test_x_p2: int = clamp(ctx.lx + 2, 0, ctx.w - 1)
		
		var test_y_n2_w: int = clamp(ctx.ly - 2, 0, ctx.h - 1) * ctx.w
		var test_y_n1_w: int = clamp(ctx.ly - 1, 0, ctx.h - 1) * ctx.w
		var test_y_p0_w: int = clamp(ctx.ly + 0, 0, ctx.h - 1) * ctx.w
		var test_y_p1_w: int = clamp(ctx.ly + 1, 0, ctx.h - 1) * ctx.w
		var test_y_p2_w: int = clamp(ctx.ly + 2, 0, ctx.h - 1) * ctx.w

		pixel_n  = data[test_x_p0 + test_y_n1_w]
		pixel_nn = data[test_x_p0 + test_y_n2_w]
		pixel_s  = data[test_x_p0 + test_y_p1_w]
		pixel_ss = data[test_x_p0 + test_y_p2_w]
		pixel_e  = data[test_x_p1 + test_y_p0_w]
		pixel_ee = data[test_x_p2 + test_y_p0_w]
		pixel_w  = data[test_x_n1 + test_y_p0_w]
		pixel_ww = data[test_x_n2 + test_y_p0_w]
		pixel_nw = data[test_x_n1 + test_y_n1_w]
		pixel_ne = data[test_x_p1 + test_y_n1_w]
		pixel_sw = data[test_x_n1 + test_y_p1_w]
		pixel_se = data[test_x_p1 + test_y_p1_w]
		
		wall_c = pixel_c & WALL_MASK != 0
		wall_n = pixel_n & WALL_MASK != 0
		wall_nn = pixel_nn & WALL_MASK != 0
		wall_s = pixel_s & WALL_MASK != 0
		wall_ss = pixel_ss & WALL_MASK != 0
		wall_e = pixel_e & WALL_MASK != 0
		wall_ee = pixel_ee & WALL_MASK != 0
		wall_w = pixel_w & WALL_MASK != 0
		wall_ww = pixel_ww & WALL_MASK != 0
		wall_nw = pixel_nw & WALL_MASK != 0
		wall_ne = pixel_ne & WALL_MASK != 0
		wall_sw = pixel_sw & WALL_MASK != 0
		wall_se = pixel_se & WALL_MASK != 0

	func _init() -> void:
		pass;
	

class Context:
	var x: int
	var y: int
	var lx: int
	var ly: int
	var start_x: int
	var start_y: int
	var w: int
	var h: int
	var x_flt: float
	var y_flt: float
	var previous_pass: PreviousPass;
	var pass_cache: Dictionary; # store anything here. sort of a way to communication between pixels
	
	func get_at(pass_data: Array[Pixel]) -> Pixel:
		return pass_data[lx + ly * w]
	
	func get_at_offset(pass_data: Array[Pixel], offset_x: int, offset_y: int) -> Pixel:
		var test_x: int = clamp(lx + offset_x, 0, w - 1)
		var test_y: int = clamp(ly + offset_y, 0, h - 1)
		return pass_data[test_x + test_y * w]
	
	func random() -> float:
		var seed_value: int = hash(Vector2i(int(x), int(y)))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		return rng.randf()
	
	func random_with_seed(seed_val: Variant) -> float:
		var seed_value: int = hash(seed_val)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		return rng.randf()
	
#	func with_biome(pixel: Pixel) -> Pixel:
#		tile = TileUtils.remove_biome(pixel)
#		return tile | TileUtils.get_biome(previous_pass.pixel_c) as Pixel

func _flag_strings_contains(flags: Array[String], text: String) -> bool:
	for flag_str: String in flags:
		if flag_str.contains(text):
			return true
	return false

func _set_wall_edge_pixel(image: Image, flags: Array[String], x: int, y: int) -> void:
	var color_with_line: Color = Color(0.0, 0.0, 1.0, 1.0) # pink
	var color_with_skirt: Color = Color(1.0, 0.0, 0.0, 1.0) # pink
	var color_with_line_and_skirt: Color = Color(1.0, 0.0, 1.0, 1.0) # pink
	var has_line: bool = _flag_strings_contains(flags, "_LINE_")
	var has_skirt: bool = _flag_strings_contains(flags, "_SKIRT_")
	if !has_line && !has_skirt:
		return
	if has_line && has_skirt:
		image.set_pixel(x, y, color_with_line_and_skirt)
	if has_line && !has_skirt:
		image.set_pixel(x, y, color_with_line)
	if !has_line && has_skirt:
		image.set_pixel(x, y, color_with_skirt)

func generate_map_image(width: int, height: int) -> Image:
	var image: Image = Image.create(width * 6, height * 6, false, Image.FORMAT_RGB8)
		
	var map: Section = generate_map(0, 0, width, height);
	for y in range(0, height):
		for x in range(0, width):
			var pixel: Pixel = map.get_pixel(x, y)
			var color_biome: Color = TileUtils.to_color((pixel & BIOME_MASK) | Pixel.TILE_EMPTY)
			var color: Color = TileUtils.to_color(pixel)
			
			for dy in range(6):
				for dx in range(6):
					image.set_pixel(x * 6 + dx, y * 6 + dy, color_biome)

			if (pixel & WALL_MASK) == Pixel.TILE_ARCH:
				for dy in range(1,5):
					for dx in range(1,5):
						image.set_pixel(x * 6 + dx, y * 6 + dy, color)
				if !has_flag(pixel, Pixel.FLAG_ARCH_MIRROR) && !has_flag(pixel, Pixel.FLAG_ARCH_ROT_TO_E):
					for dx in range(1,5): image.set_pixel(x * 6 + dx, y * 6 + 5, color)
					for dx in range(1,5): for dy in range(0,5): image.set_pixel(x * 6 + dx, y * 6 + dy, color.darkened((float(dy)/5.0) * 0.5))
				if has_flag(pixel, Pixel.FLAG_ARCH_MIRROR) && !has_flag(pixel, Pixel.FLAG_ARCH_ROT_TO_E):
					for dx in range(1,5): image.set_pixel(x * 6 + dx, y * 6 + 0, color)
					for dx in range(1,5): for dy in range(1,6): image.set_pixel(x * 6 + dx, y * 6 + dy, color.darkened((float(6.0-dy)/5.0) * 0.5))
				if !has_flag(pixel, Pixel.FLAG_ARCH_MIRROR) && has_flag(pixel, Pixel.FLAG_ARCH_ROT_TO_E):
					for dy in range(1,5): image.set_pixel(x * 6 + 5, y * 6 + dy, color)
					for dy in range(1,5): for dx in range(0,5): image.set_pixel(x * 6 + dx, y * 6 + dy, color.darkened((float(dx)/5.0) * 0.5))
				if has_flag(pixel, Pixel.FLAG_ARCH_MIRROR) && has_flag(pixel, Pixel.FLAG_ARCH_ROT_TO_E):
					for dy in range(1,5): image.set_pixel(x * 6 + 0, y * 6 + dy, color)
					for dy in range(1,5): for dx in range(1,6): image.set_pixel(x * 6 + dx, y * 6 + dy, color.darkened((float(6.0-dx)/5.0) * 0.5))
				
			elif (pixel & WALL_MASK) == Pixel.TILE_WALL:
				#var _color_with_line: Color = Color(0.0, 0.0, 1.0, 1.0) # pink
				#var _color_with_skirt: Color = Color(1.0, 0.0, 0.0, 1.0) # pink
				#var _color_with_line_and_skirt: Color = Color(1.0, 0.0, 1.0, 1.0) # pink
				
				# Directions based on last 3 chars: N_E, S_E, N_W, S_W, E_N, W_N, E_S, W_S
				# Also check for N, S, E, W if they were to be added
				
				var flags_to_check: Array[Pixel] = [
					Pixel.FLAG_WALL_SKIRT_FN_E, Pixel.FLAG_WALL_SKIRT_FS_E,
					Pixel.FLAG_WALL_SKIRT_FN_W, Pixel.FLAG_WALL_SKIRT_FS_W,
					Pixel.FLAG_WALL_SKIRT_FE_N, Pixel.FLAG_WALL_SKIRT_FW_N,
					Pixel.FLAG_WALL_SKIRT_FE_S, Pixel.FLAG_WALL_SKIRT_FW_S,
					Pixel.FLAG_WALL_LINE_FN_E, Pixel.FLAG_WALL_LINE_FS_E,
					Pixel.FLAG_WALL_LINE_FN_W, Pixel.FLAG_WALL_LINE_FS_W,
					Pixel.FLAG_WALL_LINE_FE_N, Pixel.FLAG_WALL_LINE_FW_N,
					Pixel.FLAG_WALL_LINE_FE_S, Pixel.FLAG_WALL_LINE_FW_S
				]
				
				## N_E
				#if has_flag(pixel, Pixel.FLAG_WALL_SKIRT_FN_E) && has_flag(pixel, Pixel.FLAG_WALL_LINE_FN_E):
					#for dx in range(3,6): image.set_pixel(x * 6 + dx, y * 6 + 1, color_with_line_and_skirt)
				#if has_flag(pixel, Pixel.FLAG_WALL_SKIRT_FN_E) && !has_flag(pixel, Pixel.FLAG_WALL_LINE_FN_E):
					#for dx in range(3,6): image.set_pixel(x * 6 + dx, y * 6 + 1, color_with_skirt)
				#if !has_flag(pixel, Pixel.FLAG_WALL_SKIRT_FN_E) && has_flag(pixel, Pixel.FLAG_WALL_LINE_FN_E):
					#for dx in range(3,6): image.set_pixel(x * 6 + dx, y * 6 + 1, color_with_line)
				#
				
				var flags_n_e: Array[String]
				var flags_s_e: Array[String]
				var flags_n_w: Array[String]
				var flags_s_w: Array[String]
				var flags_e_n: Array[String]
				var flags_e_s: Array[String]
				var flags_w_n: Array[String]
				var flags_w_s: Array[String]

				for flag: Pixel in flags_to_check: 
					if has_flag(pixel, flag): 
						var flag_name: String = Pixel.keys()[Pixel.values().find(flag)]
						var suffix: String = flag_name.right(3)
						match suffix:
							"N_E": flags_n_e.append(flag_name)
							"S_E": flags_s_e.append(flag_name)
							"N_W": flags_n_w.append(flag_name)
							"S_W": flags_s_w.append(flag_name)
							"E_N": flags_e_n.append(flag_name)
							"W_N": flags_w_n.append(flag_name)
							"E_S": flags_e_s.append(flag_name)
							"W_S": flags_w_s.append(flag_name)
				
				for dx in range(3,6): _set_wall_edge_pixel(image, flags_n_e, x * 6 + dx, y * 6 + 1) #N_E
				for dx in range(3,6): _set_wall_edge_pixel(image, flags_s_e, x * 6 + dx, y * 6 + 4) #S_E
				for dx in range(0,3): _set_wall_edge_pixel(image, flags_n_w, x * 6 + dx, y * 6 + 1) #N_W
				for dx in range(0,3): _set_wall_edge_pixel(image, flags_s_w, x * 6 + dx, y * 6 + 4) #S_W
				for dy in range(0,3): _set_wall_edge_pixel(image, flags_e_n, x * 6 + 4, y * 6 + dy) #E_N
				for dy in range(0,3): _set_wall_edge_pixel(image, flags_w_n, x * 6 + 1, y * 6 + dy) #W_N
				for dy in range(3,6): _set_wall_edge_pixel(image, flags_e_s, x * 6 + 4, y * 6 + dy) #E_S
				for dy in range(3,6): _set_wall_edge_pixel(image, flags_w_s, x * 6 + 1, y * 6 + dy) #W_S
				
				
					#
				#for flag: Pixel in flags_to_check:
					#if has_flag(pixel, flag):
						#var flag_name: String = Pixel.keys()[Pixel.values().find(flag)]
						#var suffix: String = flag_name.right(3)
						#
						#var edge_color: Color = color_with_line_and_skirt
						#if !flag_name.contains("SKIRT"):
							#edge_color = color_with_line
						#if !flag_name.contains("LINE"):
							#edge_color = color_with_skirt
						#
						#match suffix:
							#"N_E": for dx in range(3,6): image.set_pixel(x * 6 + dx, y * 6 + 1, edge_color)
							#"S_E": for dx in range(3,6): image.set_pixel(x * 6 + dx, y * 6 + 4, edge_color)
							#"N_W": for dx in range(0,3): image.set_pixel(x * 6 + dx, y * 6 + 1, edge_color)
							#"S_W": for dx in range(0,3): image.set_pixel(x * 6 + dx, y * 6 + 4, edge_color)
							#"E_N": for dy in range(0,3): image.set_pixel(x * 6 + 4, y * 6 + dy, edge_color)
							#"W_N": for dy in range(0,3): image.set_pixel(x * 6 + 1, y * 6 + dy, edge_color)
							#"E_S": for dy in range(3,6): image.set_pixel(x * 6 + 4, y * 6 + dy, edge_color)
							#"W_S": for dy in range(3,6): image.set_pixel(x * 6 + 1, y * 6 + dy, edge_color)
			#
				for dy in range(2,4):
					for dx in range(2,4):
						image.set_pixel(x * 6 + dx, y * 6 + dy, color)
				if has_flag(pixel, Pixel.FLAG_WALL_LOBE_N):
					for dy in range(0,2): for dx in range(2,4): image.set_pixel(x * 6 + dx, y * 6 + dy, color)
				if has_flag(pixel, Pixel.FLAG_WALL_LOBE_S):
					for dy in range(4,6): for dx in range(2,4): image.set_pixel(x * 6 + dx, y * 6 + dy, color)
				if has_flag(pixel, Pixel.FLAG_WALL_LOBE_E):
					for dy in range(2,4): for dx in range(4,6): image.set_pixel(x * 6 + dx, y * 6 + dy, color)
				if has_flag(pixel, Pixel.FLAG_WALL_LOBE_W):
					for dy in range(2,4): for dx in range(0,2): image.set_pixel(x * 6 + dx, y * 6 + dy, color)
			
			else:
				for dy in range(6):
					for dx in range(6):
						image.set_pixel(x * 6 + dx, y * 6 + dy, color)

	
	return image;

func generate_biome_image(width: int, height: int) -> Image:
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGB8)
		
	var map: Section = generate_map(0, 0, width, height);
	for y in range(0, height):
		for x in range(0, width):
			image.set_pixel(x, y, TileUtils.to_color(map.get_pixel(x, y)))
	
	return image;
	

func generate_map(x0: int, y0: int, x1: int, y1: int) -> Section:
	var retval: Section = Section.new(x0, y0, x1, y1);
	_run_mapshader(retval)
	return retval

func _run_mapshader(section: Section) -> void:
	var size: int = section.w * section.h

	var pass_a: Array[Pixel] = []
	var pass_b: Array[Pixel] = []
	pass_a.resize(size)
	
	_run_pass(section.x, section.y, section.x + section.w, section.y + section.h, pass_b, 0, pass_a);
	#print("Pass: " + str(0))
	section.data = pass_b
	
	var was_valid := true
	var pass_index: int = 1
	while was_valid:
		if pass_index & 1 == 0:
			was_valid = _run_pass(section.x, section.y, section.x + section.w, section.y + section.h, pass_b, pass_index, pass_a);
			section.data = pass_b
		else:
			was_valid = _run_pass(section.x, section.y, section.x + section.w, section.y + section.h, pass_a, pass_index, pass_b);
			section.data = pass_a
		#print("Pass: " + str(pass_index))
		pass_index = pass_index+1

func _run_pass(x0: int, y0: int, x1: int, y1: int, target: Array[Pixel], pass_index: int, previous_pass_array: Array[Pixel]) -> bool:
	print("Running pass: " + str(pass_index))
	var width: int = x1 - x0;
	var context: Context = Context.new()
	context.w = x1-x0;
	context.h = y1-y0;
	context.start_x = x0;
	context.start_y = y0;
	context.previous_pass = PreviousPass.new()
	context.previous_pass.data = previous_pass_array
	context.pass_cache = {}
	var all_pixels_set_to_count := true
		
	target.resize(context.w * context.h);
	for y in range(y0, y1):
		var ly: int = y - y0
		context.ly = ly
		for x in range(x0, x1):
			var lx: int = x - x0
			var index := lx + ly * width
			context.x = x;
			context.y = y;
			context.lx = lx
			context.x_flt = float(x);
			context.y_flt = float(y);
			context.previous_pass.update(context)
			var pixel: Pixel = _gen(pass_index, context);
			if pixel != Pixel.INVALID:
				target[index] = pixel;
				all_pixels_set_to_count = false
			else:
				target[index] = previous_pass_array[index]
	# print("all_pixels_set_to_count: " + str(all_pixels_set_to_count) + " for index: " + str(pass_index))
	return !all_pixels_set_to_count

static func _face_to_flag_wall_skirt(face: WallFace) -> Pixel:
	match face:
		WallFace.FN_E: return Pixel.FLAG_WALL_SKIRT_FN_E
		WallFace.FS_E: return Pixel.FLAG_WALL_SKIRT_FS_E
		WallFace.FN_W: return Pixel.FLAG_WALL_SKIRT_FN_W
		WallFace.FS_W: return Pixel.FLAG_WALL_SKIRT_FS_W
		WallFace.FE_N: return Pixel.FLAG_WALL_SKIRT_FE_N
		WallFace.FW_N: return Pixel.FLAG_WALL_SKIRT_FW_N
		WallFace.FE_S: return Pixel.FLAG_WALL_SKIRT_FE_S
		WallFace.FW_S: return Pixel.FLAG_WALL_SKIRT_FW_S
	return Pixel.NONE

static func _face_to_flag_wall_line(face: WallFace) -> Pixel:
	match face:
		WallFace.FN_E: return Pixel.FLAG_WALL_LINE_FN_E
		WallFace.FS_E: return Pixel.FLAG_WALL_LINE_FS_E
		WallFace.FN_W: return Pixel.FLAG_WALL_LINE_FN_W
		WallFace.FS_W: return Pixel.FLAG_WALL_LINE_FS_W
		WallFace.FE_N: return Pixel.FLAG_WALL_LINE_FE_N
		WallFace.FW_N: return Pixel.FLAG_WALL_LINE_FW_N
		WallFace.FE_S: return Pixel.FLAG_WALL_LINE_FE_S
		WallFace.FW_S: return Pixel.FLAG_WALL_LINE_FW_S
	return Pixel.NONE
	
class TileUtils:
	static func get_biome(pixel: Pixel) -> Pixel:
		return pixel & BIOME_MASK as Pixel
	
	static func remove_biome(pixel: Pixel) -> Pixel:
		return pixel - get_biome(pixel) as Pixel
	
	
	static func to_color(pixel: Pixel) -> Color:
		#if true:
		#	return Color(float(pixel) / 255.0, float(pixel) / 255.0, float(pixel) / 255.0, 1.0)

		match pixel:
			Pixel.BIOME_MESS    | Pixel.TILE_EMPTY:   return Color(0.587, 0.723, 1.0, 1.0)
			Pixel.BIOME_ROOMS   | Pixel.TILE_EMPTY:   return Color(0.739, 0.634, 1.0, 1.0)
			Pixel.BIOME_ARCHES  | Pixel.TILE_EMPTY:   return Color(1.0, 0.559, 0.567, 1.0)
			Pixel.BIOME_PILLARS | Pixel.TILE_EMPTY:   return Color(0.962, 0.576, 1.0, 1.0)
		
		var tile : Pixel = pixel & TILE_MASK as Pixel
		if tile == Pixel.TILE_CEILING_LIGHT:							return Color(0,1,1)
		if tile == Pixel.TILE_CEILING_LIGHT_BLINKING:					return Color(0.0, 0.58, 0.614, 1.0)
		if tile == Pixel.TILE_WALL:
			if MapGenerator.has_flag(pixel, Pixel.FLAG_WALL_TOP_GAP):	return Color(0.393, 0.393, 0.393, 1.0)
			return Color(0,0,0)
		if tile == Pixel.TILE_ARCH:										return Color(0.622, 0.428, 0.0, 1.0)
		
		var h := fmod(absf(sin(float(pixel) * 12.9898) * 43758.5453), 1.0)
		return Color.from_hsv(h, 0.7, 1.0)
		
		# return Color(1,0,1)
