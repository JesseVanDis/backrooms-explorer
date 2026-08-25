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

func _extend_walls(ctx: Context, previous_pass: Array[TileType]) -> bool:
	if ctx.get_at(previous_pass) != TileType.WALL:
		var wall_w =  ctx.get_at_offset(previous_pass, -1, 0);
		var wall_ww = ctx.get_at_offset(previous_pass, -2, 0);
		var wall_e =  ctx.get_at_offset(previous_pass,  1, 0);
		var wall_ee = ctx.get_at_offset(previous_pass,  2, 0);
		var wall_s =  ctx.get_at_offset(previous_pass,  0, -1);
		var wall_ss = ctx.get_at_offset(previous_pass,  0, -2);
		var wall_n =  ctx.get_at_offset(previous_pass,  0, 1);
		var wall_nn = ctx.get_at_offset(previous_pass,  0, 2);
		
		if wall_w && wall_ww && !wall_n && !wall_s: return true
		if wall_e && wall_ee && !wall_n && !wall_s: return true
		if wall_n && wall_nn && !wall_w && !wall_e: return true
		if wall_s && wall_ss && !wall_w && !wall_e: return true
	return false

func _is_isolated_wall_dot(ctx: Context, previous_pass: Array[TileType]) -> bool:
	if ctx.get_at(previous_pass) == TileType.WALL:
		return (ctx.get_at_offset(previous_pass, 1, 0) != TileType.WALL &&
			ctx.get_at_offset(previous_pass, -1, 0) != TileType.WALL && 
			ctx.get_at_offset(previous_pass, 0, 1) != TileType.WALL && 
			ctx.get_at_offset(previous_pass, 0, -1) != TileType.WALL)
	return false

func _is_open_corner(ctx: Context, previous_pass: Array[TileType]) -> bool:
	if ctx.get_at(previous_pass) != TileType.WALL:
		var wall_w =  ctx.get_at_offset(previous_pass, -1, 0)  == TileType.WALL;
		var wall_e =  ctx.get_at_offset(previous_pass,  1, 0)  == TileType.WALL;
		var wall_s =  ctx.get_at_offset(previous_pass,  0, -1) == TileType.WALL;
		var wall_n =  ctx.get_at_offset(previous_pass,  0, 1)  == TileType.WALL;
		#var wall_w =  ctx.get_at_offset(previous_pass, -1, 0)  == TileType.WALL && ctx.get_at_offset(previous_pass, -2, 0) == TileType.WALL;
		#var wall_e =  ctx.get_at_offset(previous_pass,  1, 0)  == TileType.WALL && ctx.get_at_offset(previous_pass,  2, 0) == TileType.WALL;
		#var wall_s =  ctx.get_at_offset(previous_pass,  0, -1) == TileType.WALL && ctx.get_at_offset(previous_pass,  0, -2)== TileType.WALL;
		#var wall_n =  ctx.get_at_offset(previous_pass,  0, 1)  == TileType.WALL && ctx.get_at_offset(previous_pass,  0, 2) == TileType.WALL;
		if (wall_w || wall_e) && (wall_n || wall_s): return true
	return false
	

const _NUM_PASSES: int = 7
	
func _mapshader_pass(pass_index: int, ctx: Context, previous_pass: Array[TileType]) -> TileType:
	match pass_index:
		0:
			if ctx.random() > 0.9:
				return TileType.WALL
			if _ceiling_light(ctx):
				return TileType.CEILING_LIGHT
			return TileType.EMPTY
	
		1:
			if _is_isolated_wall_dot(ctx, previous_pass):
				return TileType.EMPTY
			return ctx.get_at(previous_pass)
		
		2,3,4:
			if _extend_walls(ctx, previous_pass):
				return TileType.WALL
			return ctx.get_at(previous_pass)
			
		5:
			if _is_open_corner(ctx, previous_pass):
				return TileType.WALL
			return ctx.get_at(previous_pass)

	#if(ctx.x == 11 && ctx.y == 11): return TileType.WALL
	#if(ctx.x == 10 && ctx.y == 11): return TileType.WALL
	#if(ctx.x ==  9 && ctx.y == 11): return TileType.WALL
	#if(ctx.x == 12 && ctx.y == 11): return TileType.WALL
	#if(ctx.x == 13 && ctx.y == 11): return TileType.WALL
	#if(ctx.x == 11 && ctx.y == 10): return TileType.WALL
	#if(ctx.x == 11 && ctx.y ==  9): return TileType.WALL
	#if(ctx.x == 11 && ctx.y == 12): return TileType.WALL
	#if(ctx.x == 11 && ctx.y == 13): return TileType.WALL

	if(ctx.x == 9 && (ctx.y >= 9 && ctx.y <= 13)): return TileType.WALL
	if(ctx.x == 13 && (ctx.y >= 9 && ctx.y <= 13)): return TileType.WALL
	if(ctx.y == 9 && (ctx.x >= 9 && ctx.x <= 13)): return TileType.WALL
	if(ctx.y == 13 && (ctx.x >= 9 && ctx.x <= 13)): return TileType.WALL
	if(ctx.x == 11 && ctx.y == 14): return TileType.WALL
	if(ctx.x == 11 && ctx.y == 8): return TileType.WALL
	if(ctx.x == 14 && ctx.y == 11): return TileType.WALL
	if(ctx.x == 8 && ctx.y == 11): return TileType.WALL
	
	if(ctx.x == 8 && ctx.y == 8): return TileType.CEILING_LIGHT
	if(ctx.x == 14 && ctx.y == 8): return TileType.CEILING_LIGHT
	if(ctx.x == 8 && ctx.y == 14): return TileType.CEILING_LIGHT
	if(ctx.x == 14 && ctx.y == 14): return TileType.CEILING_LIGHT
	
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

class Context:
	var x: int
	var y: int
	var w: int
	var h: int
	var x_flt: float
	var y_flt: float
	
	func get_at(pass_data):
		return pass_data[x + y * w]
	
	func get_at_offset(pass_data, offset_x: int, offset_y: int):
		var test_x = clamp(x + offset_x, 0, (w-1))
		var test_y = clamp(y + offset_y, 0, (h-1))
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

func _run_pass(x0: int, y0: int, x1: int, y1: int, target, pass_index: int, previous_pass) -> void:
	var width = x1-x0;
	var context: Context = Context.new()
	context.w = x1-x0;
	context.h = y1-y0;
	target.resize(context.w * context.h);
	for y in range(y0, y1):
		for x in range(x0, x1):
			context.x = x;
			context.y = y;
			context.x_flt = float(x);
			context.y_flt = float(y);
			target[x + y * width] = _mapshader_pass(pass_index, context, previous_pass);
