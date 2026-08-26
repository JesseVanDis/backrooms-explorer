extends Node

class_name MapGenerator

enum TileType {
	EMPTY,
	CEILING_LIGHT,
	WALL,
}

func _ceiling_light(ctx: Context) -> bool:
	if(posmod(ctx.x, 5) == 1 && posmod(ctx.y, 5) == 1):
		return true
	return false

func _mapshader_standard(context: Context) -> TileType:
	if context.random() > 0.8:
		return TileType.WALL
	if _ceiling_light(context):
		return TileType.CEILING_LIGHT
	return TileType.EMPTY

func _extend_walls(ctx: Context) -> bool:
	var pp: PreviousPass = ctx.previous_pass
	if !pp.wall_c:
		if pp.wall_nw || pp.wall_ne || pp.wall_sw || pp.wall_se: return false
		if pp.wall_w && pp.wall_ww && !pp.wall_n && !pp.wall_s: return true
		if pp.wall_e && pp.wall_ee && !pp.wall_n && !pp.wall_s: return true
		if pp.wall_n && pp.wall_nn && !pp.wall_w && !pp.wall_e: return true
		if pp.wall_s && pp.wall_ss && !pp.wall_w && !pp.wall_e: return true
	return false

func _is_isolated_wall_dot(ctx: Context) -> bool:
	var pp: PreviousPass = ctx.previous_pass
	if pp.wall_c:
		return !pp.wall_e && !pp.wall_w && !pp.wall_n && !pp.wall_s
	return false

func _is_open_corner(ctx: Context) -> bool:
	var pp: PreviousPass = ctx.previous_pass
	if !pp.wall_c:
		if (pp.wall_w || pp.wall_e) && (pp.wall_n || pp.wall_s): return true
	return false

func _is_deadend(ctx: Context, offset_x: int, offset_y: int) -> bool:
	var data: Array[TileType] = ctx.previous_pass.data
	if ctx.get_at_offset(data, offset_x, offset_y) == TileType.WALL:
		var wall_w: bool =  ctx.get_at_offset(data, offset_x + -1, offset_y + 0)  == TileType.WALL;
		var wall_e: bool =  ctx.get_at_offset(data, offset_x +  1, offset_y + 0)  == TileType.WALL;
		var wall_s: bool =  ctx.get_at_offset(data, offset_x +  0, offset_y + -1) == TileType.WALL;
		var wall_n: bool =  ctx.get_at_offset(data, offset_x +  0, offset_y + 1)  == TileType.WALL;
		if(wall_w && !wall_n && !wall_s && !wall_e): return true
		if(!wall_w && wall_n && !wall_s && !wall_e): return true
		if(!wall_w && !wall_n && wall_s && !wall_e): return true
		if(!wall_w && !wall_n && !wall_s && wall_e): return true
	return false
	
const _NUM_PASSES: int = 11
	
func _mapshader_pass(pass_index: int, ctx: Context) -> TileType:
	var pp: PreviousPass = ctx.previous_pass
	var num_neighbour_walls: int = 0;
	if pp.wall_w: num_neighbour_walls = num_neighbour_walls + 1
	if pp.wall_e: num_neighbour_walls = num_neighbour_walls + 1
	if pp.wall_s: num_neighbour_walls = num_neighbour_walls + 1
	if pp.wall_n: num_neighbour_walls = num_neighbour_walls + 1

	match pass_index:
		0:
			if ctx.random() > 0.9:
				return TileType.WALL
			if _ceiling_light(ctx):
				return TileType.CEILING_LIGHT
			return TileType.EMPTY
	
		1:
			if num_neighbour_walls > 0 && !pp.wall_c:
				if ctx.random() > 0.75:
					return TileType.WALL
			return ctx.get_at(pp.data)
			
		2:
			if _is_isolated_wall_dot(ctx):
				return TileType.EMPTY
			return ctx.get_at(pp.data)
		
		3,4,5,6,7,8,9,10:
			if ctx.random() > 0.1:
				if _extend_walls(ctx):
					return TileType.WALL
			return ctx.get_at(pp.data)
		
		11: 
			# make room for spawn
			pass
	
		#2:
			#if ctx.random() > 0.3:
				#var dir: int = int(ctx.random() * 4.0) & 3
				#if dir == 0:
					#if _is_deadend(ctx, 0, -1):
						#return TileType.WALL
				#if dir == 1:
					#if _is_deadend(ctx, 0, 1):
						#return TileType.WALL
				#if dir == 2:
					#if _is_deadend(ctx, -1, 0):
						#return TileType.WALL
				#if dir == 3:
					#if _is_deadend(ctx,  1, 0):
						#return TileType.WALL
			#return ctx.get_at(pp.data)
	
		#7:
			#if _is_open_corner(ctx):
				#return TileType.WALL
			#return ctx.get_at(pp.data)
	
	return TileType.EMPTY


class PlotData:
	var tile_type: TileType
	func _init() -> void:
		pass;

class Section:
	var x: int
	var y: int
	var w: int
	var h: int
	var data: Array[TileType] = []
	
	func set_tile(x: int, y: int, tile_type: TileType) -> void:
		data[x + y * w] = tile_type;
		
	func get_tile(x: int, y: int) -> TileType:
		return data[x + y * w];

	func get_tile_clamped(x: int, y: int) -> TileType:
		return data[clamp(x, 0, w-1) + clamp(y, 0, h-1) * w];
		
	func _init() -> void:
		pass;

class PreviousPass:
	var data: Array[TileType]
	
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
	
	func update(ctx: Context) -> void:
		wall_c = ctx.get_at(data) == TileType.WALL
		wall_n = ctx.get_at_offset(data, 0, 1) == TileType.WALL
		wall_nn = ctx.get_at_offset(data, 0, 2) == TileType.WALL
		wall_s = ctx.get_at_offset(data, 0, -1) == TileType.WALL
		wall_ss = ctx.get_at_offset(data, 0, -2) == TileType.WALL
		wall_e = ctx.get_at_offset(data, 1, 0) == TileType.WALL
		wall_ee = ctx.get_at_offset(data, 2, 0) == TileType.WALL
		wall_w = ctx.get_at_offset(data, -1, 0) == TileType.WALL
		wall_ww = ctx.get_at_offset(data, -2, 0) == TileType.WALL
		wall_nw = ctx.get_at_offset(data, -1, 1) == TileType.WALL
		wall_ne = ctx.get_at_offset(data, 1, 1) == TileType.WALL
		wall_sw = ctx.get_at_offset(data, -1, -1) == TileType.WALL
		wall_se = ctx.get_at_offset(data, 1, -1) == TileType.WALL

	func _init() -> void:
		pass;
	

class Context:
	var x: int
	var y: int
	var w: int
	var h: int
	var x_flt: float
	var y_flt: float
	var previous_pass: PreviousPass;
	
	func get_at(pass_data: Array[TileType]) -> TileType:
		return pass_data[x + y * w]
	
	func get_at_offset(pass_data: Array[TileType], offset_x: int, offset_y: int) -> TileType:
		var test_x: int = clamp(x + offset_x, 0, (w-1))
		var test_y: int = clamp(y + offset_y, 0, (h-1))
		return pass_data[test_x + test_y * w]
	
	func random() -> float:
		var seed_value = hash(Vector2i(int(x), int(y)))
		var rng = RandomNumberGenerator.new()
		rng.seed = seed_value
		return rng.randf()

func to_color(tile_type: TileType) -> Color:
	match tile_type:
		TileType.EMPTY:
			return Color(0,0,1)
		TileType.CEILING_LIGHT:
			return Color(0,1,1)
		TileType.WALL:
			return Color(0,0,0)
	return Color(0,0,0)

func generate_map_image(width: int, height: int) -> Image:
	var image = Image.create(width, height, false, Image.FORMAT_RGB8)
		
	var map: Section = generate_map(0, 0, width, height);
	for y in range(0, height):
		for x in range(0, width):
			image.set_pixel(x, y, to_color(map.get_tile(x, y)))
	
	return image;
	

func generate_map(x0: int, y0: int, x1: int, y1: int) -> Section:
	var retval: Section = Section.new();
	var size: int = (x1-x0) * (y1-y0)
	retval.x = x0;
	retval.y = y0;
	retval.w = x1-x0;
	retval.h = y1-y0;
	retval.data.resize(size);

	var pass_a: Array[TileType] = []
	var pass_b: Array[TileType] = []
	pass_a.resize(size)
	
	_run_pass(x0, y0, x1, y1, pass_b, 0, pass_a);
	print("Pass: " + str(0))
	retval.data = pass_b
			
	for index in range(1, _NUM_PASSES):
		if index & 1 == 0:
			_run_pass(x0, y0, x1, y1, pass_b, index, pass_a);
			retval.data = pass_b
		else:
			_run_pass(x0, y0, x1, y1, pass_a, index, pass_b);
			retval.data = pass_a
		print("Pass: " + str(index))
	
	return retval;

func _run_pass(x0: int, y0: int, x1: int, y1: int, target: Array[TileType], pass_index: int, previous_pass_array: Array[TileType]) -> void:
	var width: int = x1-x0;
	var context: Context = Context.new()
	context.w = x1-x0;
	context.h = y1-y0;
	context.previous_pass = PreviousPass.new()
	context.previous_pass.data = previous_pass_array
	
	target.resize(context.w * context.h);
	for y in range(y0, y1):
		for x in range(x0, x1):
			context.x = x;
			context.y = y;
			context.x_flt = float(x);
			context.y_flt = float(y);
			context.previous_pass.update(context)
			target[x + y * width] = _mapshader_pass(pass_index, context);
