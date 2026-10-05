extends Node

class_name MapGenerator

const CHANCE_BLINKING_LIGHT = 0.004

const BIOME_MASK                 = 0x000000FF
const TILE_MASK                  = 0xFFFFFF00

const WALL_MASK                  = 0x0000FF00

enum Pixel {
	NONE                         = 0x00000000,
	BIOME_MESS                   = 0x00000001,
	BIOME_ROOMS                  = 0x00000002,
	BIOME_ARCHES                 = 0x00000003,
	BIOME_PILLARS                = 0x00000004,
	TILE_WALL                    = 0x00000100,
	TILE_WALL_TOP_GAP            = 0x00000200,
	TILE_ARCH                    = 0x00000300,
	TILE_ARCH_MIRRORED           = 0x00000400,
	TILE_EMPTY                   = 0x00010000,
	TILE_CEILING_LIGHT           = 0x00020000,
	TILE_CEILING_LIGHT_BLINKING  = 0x00030000,
	INVALID                      = 0xFFFFFF00
}

#const BIOME_MASK = (1 << 16) - 1
#const TILE_MASK  = ((1 << 16) - 1) << 16

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

static func is_wall(pixel: Pixel) -> bool:
	return pixel & WALL_MASK != 0

static func is_wall_arch(pixel: Pixel) -> bool:
	var tile: Pixel = pixel & TILE_MASK as Pixel
	match tile:
		Pixel.TILE_ARCH, Pixel.TILE_ARCH_MIRRORED:
			return true
		_:
			return false

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

func _is_wall_deadend(ctx: Context, offset_x: int, offset_y: int) -> bool:
	var data: Array[Pixel] = ctx.previous_pass.data
	if is_wall(ctx.get_at_offset(data, offset_x, offset_y)):
		var wall_w: bool =  ctx.previous_pass.wall_w;
		var wall_e: bool =  ctx.previous_pass.wall_e;
		var wall_s: bool =  ctx.previous_pass.wall_s;
		var wall_n: bool =  ctx.previous_pass.wall_n;
		if(wall_w && !wall_n && !wall_s && !wall_e): return true
		if(!wall_w && wall_n && !wall_s && !wall_e): return true
		if(!wall_w && !wall_n && wall_s && !wall_e): return true
		if(!wall_w && !wall_n && !wall_s && wall_e): return true
	return false
	
func _get_wall_length(pp: PreviousPass, ctx: Context, limit: int = 10, offset_x: int = 0, offset_y: int = 0, check_diagonal: bool = true, visited: Dictionary = {}) -> int:
	var key := Vector2i(offset_x, offset_y)
	if visited.has(key):
		return 0
	visited[key] = true
	if !is_wall(ctx.get_at_offset(pp.data, offset_x, offset_y)):
		return 0
	var count := 1
	if count >= limit: return limit
	count += _get_wall_length(pp, ctx, limit - count, offset_x + 1, offset_y, check_diagonal, visited);     if count >= limit:	return limit
	count += _get_wall_length(pp, ctx, limit - count, offset_x - 1, offset_y, check_diagonal, visited);     if count >= limit:	return limit
	count += _get_wall_length(pp, ctx, limit - count, offset_x, offset_y + 1, check_diagonal, visited);     if count >= limit:	return limit
	count += _get_wall_length(pp, ctx, limit - count, offset_x, offset_y - 1, check_diagonal, visited);     if count >= limit:	return limit
	if check_diagonal:
		count += _get_wall_length(pp, ctx, limit - count, offset_x + 1, offset_y - 1, check_diagonal, visited); if count >= limit:	return limit
		count += _get_wall_length(pp, ctx, limit - count, offset_x - 1, offset_y - 1, check_diagonal, visited); if count >= limit:	return limit
		count += _get_wall_length(pp, ctx, limit - count, offset_x + 1, offset_y + 1, check_diagonal, visited); if count >= limit:	return limit
		count += _get_wall_length(pp, ctx, limit - count, offset_x - 1, offset_y + 1, check_diagonal, visited); if count >= limit:	return limit
	return count

#func _find_distance_to_deadend(ctx: Context, limit: int = 10) -> int:
	

func _is_wall_length_greater_then(pp: PreviousPass, ctx: Context, threshold: int, offset_x: int = 0, offset_y: int = 0, check_diagonal: bool = true) -> bool:
	if pp.wall_c && _get_wall_length(pp, ctx, threshold+1, offset_x, offset_y, check_diagonal) > threshold:
		return true
	return false

func _is_wall_length_lesser_then(pp: PreviousPass, ctx: Context, threshold: int, offset_x: int = 0, offset_y: int = 0, check_diagonal: bool = true) -> bool:
	if !pp.wall_c:
		return true
	return _get_wall_length(pp, ctx, threshold+1, offset_x, offset_y, check_diagonal) < threshold

func _replace_deadend_wall_with_upper_gap(ctx: Context) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	if pp.wall_c:
		if(pp.wall_w && !pp.wall_n && !pp.wall_s && !pp.wall_e): return Pixel.TILE_WALL_TOP_GAP
		if(!pp.wall_w && pp.wall_n && !pp.wall_s && !pp.wall_e): return Pixel.TILE_WALL_TOP_GAP
		if(!pp.wall_w && !pp.wall_n && pp.wall_s && !pp.wall_e): return Pixel.TILE_WALL_TOP_GAP
		if(!pp.wall_w && !pp.wall_n && !pp.wall_s && pp.wall_e): return Pixel.TILE_WALL_TOP_GAP
	return pp.no_change()

func _spread_upper_gap(ctx: Context) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	if pp.tile_c == Pixel.TILE_WALL:
		if pp.tile_n == Pixel.TILE_WALL_TOP_GAP && !pp.wall_e && !pp.wall_w: return Pixel.TILE_WALL_TOP_GAP
		if pp.tile_s == Pixel.TILE_WALL_TOP_GAP && !pp.wall_e && !pp.wall_w: return Pixel.TILE_WALL_TOP_GAP
		if pp.tile_e == Pixel.TILE_WALL_TOP_GAP && !pp.wall_n && !pp.wall_s: return Pixel.TILE_WALL_TOP_GAP
		if pp.tile_w == Pixel.TILE_WALL_TOP_GAP && !pp.wall_n && !pp.wall_s: return Pixel.TILE_WALL_TOP_GAP
	return pp.no_change()

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

func _gen(pass_index: int, ctx: Context) -> Pixel:
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
			if ctx.random() > 0.9: 
				return _replace_deadend_wall_with_upper_gap(ctx)
			return pp.no_change()
		
		13,14,15:
			return _spread_upper_gap(ctx)
		
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
			if ctx.random() > 0.9:
				return _replace_deadend_wall_with_upper_gap(ctx)
			return pp.no_change()
	
		8,9,10:
			return _spread_upper_gap(ctx)

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
				if ((n || s) && (ctx.y & 1) == 1):
					return pp.with_tile(Pixel.TILE_ARCH_MIRRORED)
				if ((e || w) && (ctx.x & 1) == 1):
					return pp.with_tile(Pixel.TILE_ARCH_MIRRORED)
			return pp.no_change()
		
		10: # fix mis-alighned
			if pp.wall_c && !is_wall_arch(pp.tile_c):
				return pp.no_change() 
			var n: Pixel = (ctx.get_at_offset(pp.data,  0, -1) & TILE_MASK as Pixel)
			var s: Pixel = (ctx.get_at_offset(pp.data,  0,  1) & TILE_MASK as Pixel)
			var e: Pixel = (ctx.get_at_offset(pp.data, -1,  0) & TILE_MASK as Pixel)
			var w: Pixel = (ctx.get_at_offset(pp.data,  1,  0) & TILE_MASK as Pixel)
			if pp.wall_n && !is_wall_arch(n) && pp.tile_c == Pixel.TILE_ARCH_MIRRORED:
				return pp.with_tile(Pixel.TILE_WALL)
			if pp.wall_s && !is_wall_arch(s) && pp.tile_c == Pixel.TILE_ARCH:
				return pp.with_tile(Pixel.TILE_WALL)
			if pp.wall_w && !is_wall_arch(w) && pp.tile_c == Pixel.TILE_ARCH:
				return pp.with_tile(Pixel.TILE_WALL)
			if pp.wall_e && !is_wall_arch(e) && pp.tile_c == Pixel.TILE_ARCH_MIRRORED:
				return pp.with_tile(Pixel.TILE_WALL)
			return pp.no_change()
			
		11: # filter small walls
			if pp.wall_c:
				var n: Pixel = (ctx.get_at_offset(pp.data,  0, -1) & TILE_MASK as Pixel)
				var s: Pixel = (ctx.get_at_offset(pp.data,  0,  1) & TILE_MASK as Pixel)
				var e: Pixel = (ctx.get_at_offset(pp.data, -1,  0) & TILE_MASK as Pixel)
				var w: Pixel = (ctx.get_at_offset(pp.data,  1,  0) & TILE_MASK as Pixel)
				
				if pp.tile_c == Pixel.TILE_WALL:
					if e != Pixel.TILE_WALL && s != Pixel.TILE_WALL && n != Pixel.TILE_WALL && w != Pixel.TILE_WALL:
						return pp.with_tile(Pixel.TILE_EMPTY)
				
				if is_wall_arch(pp.tile_c):
					if !is_wall_arch(e) && !is_wall_arch(s) && !is_wall_arch(n) && !is_wall_arch(w):
						return pp.with_tile(Pixel.TILE_EMPTY)
			return pp.no_change()
	
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
	var tile_n: Pixel
	var tile_nn: Pixel
	var tile_s: Pixel
	var tile_ss: Pixel
	var tile_e: Pixel
	var tile_ee: Pixel
	var tile_w: Pixel
	var tile_ww: Pixel
	var tile_nw: Pixel
	var tile_ne: Pixel
	var tile_sw: Pixel
	var tile_se: Pixel
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
		return biome_c | tile as Pixel

	func with_biome(biome: Pixel) -> Pixel:
		if biome & TILE_MASK != 0:
			push_error("argument given to 'with_biome' MUST be a biome")
			return no_change()
		return tile_c | biome as Pixel
		
	func no_change() -> Pixel:
		return pixel_c

	func update(ctx: Context) -> void:
		pixel_c = ctx.get_at(data)
		biome_c = TileUtils.get_biome(pixel_c)
		tile_c = pixel_c - biome_c as Pixel

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

		tile_n  = data[test_x_p0 + test_y_n1_w]
		tile_nn = data[test_x_p0 + test_y_n2_w]
		tile_s  = data[test_x_p0 + test_y_p1_w]
		tile_ss = data[test_x_p0 + test_y_p2_w]
		tile_e  = data[test_x_p1 + test_y_p0_w]
		tile_ee = data[test_x_p2 + test_y_p0_w]
		tile_w  = data[test_x_n1 + test_y_p0_w]
		tile_ww = data[test_x_n2 + test_y_p0_w]
		tile_nw = data[test_x_n1 + test_y_n1_w]
		tile_ne = data[test_x_p1 + test_y_n1_w]
		tile_sw = data[test_x_n1 + test_y_p1_w]
		tile_se = data[test_x_p1 + test_y_p1_w]
		
		wall_c = pixel_c & WALL_MASK != 0
		wall_n = tile_n & WALL_MASK != 0
		wall_nn = tile_nn & WALL_MASK != 0
		wall_s = tile_s & WALL_MASK != 0
		wall_ss = tile_ss & WALL_MASK != 0
		wall_e = tile_e & WALL_MASK != 0
		wall_ee = tile_ee & WALL_MASK != 0
		wall_w = tile_w & WALL_MASK != 0
		wall_ww = tile_ww & WALL_MASK != 0
		wall_nw = tile_nw & WALL_MASK != 0
		wall_ne = tile_ne & WALL_MASK != 0
		wall_sw = tile_sw & WALL_MASK != 0
		wall_se = tile_se & WALL_MASK != 0

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

func generate_map_image(width: int, height: int) -> Image:
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGB8)
		
	var map: Section = generate_map(0, 0, width, height);
	for y in range(0, height):
		for x in range(0, width):
			image.set_pixel(x, y, TileUtils.to_color(map.get_pixel(x, y)))
	
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
		
		match pixel & TILE_MASK:
			Pixel.TILE_CEILING_LIGHT:               return Color(0,1,1)
			Pixel.TILE_CEILING_LIGHT_BLINKING:      return Color(0.0, 0.58, 0.614, 1.0)
			Pixel.TILE_WALL:                        return Color(0,0,0)
			Pixel.TILE_WALL_TOP_GAP:                return Color(0.393, 0.393, 0.393, 1.0)
			Pixel.TILE_ARCH:                        return Color(0.622, 0.428, 0.0, 1.0)
			Pixel.TILE_ARCH_MIRRORED:               return Color(0.769, 0.303, 0.0, 1.0)
		
		var h := fmod(absf(sin(float(pixel) * 12.9898) * 43758.5453), 1.0)
		return Color.from_hsv(h, 0.7, 1.0)
		
		# return Color(1,0,1)
