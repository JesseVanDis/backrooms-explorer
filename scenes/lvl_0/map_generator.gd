extends Node

class_name MapGenerator

enum Pixel {
	BIOME_DEFAULT 		= 1 << 1,
	BIOME_PILLARS 		= 1 << 2,
	TILE_EMPTY			= 1 << 16,
	TILE_CEILING_LIGHT	= 2 << 16,
	TILE_WALL			= 3 << 16,
	INVALID				= 1 << 31
}

const BIOME_MASK = (1 << 16) - 1
const TILE_MASK  = ((1 << 16) - 1) << 16

func _ceiling_light(ctx: Context, misplacement_chance: float) -> bool:
	#if(posmod(ctx.x, 5) == 1 && posmod(ctx.y, 5) == 1):
	#	return true
	
	const grid_size = 5
	@warning_ignore("integer_division")
	var grid_x = ctx.x / grid_size as int
	@warning_ignore("integer_division")
	var grid_y = ctx.y / grid_size as int
	@warning_ignore("integer_division")
	var light_pos_x = (abs(grid_x) * grid_size) + grid_size / 2
	@warning_ignore("integer_division")
	var light_pos_y = (abs(grid_y) * grid_size) + grid_size / 2
	var random = ctx.random_with_seed(hash(Vector2i(grid_x, grid_y)))
	if random < misplacement_chance:
		if random < 0.25 * misplacement_chance:
			light_pos_x = light_pos_x+1
		elif random < 0.5 * misplacement_chance:
			light_pos_y = light_pos_y+1
		elif random < 0.75 * misplacement_chance:
			light_pos_x = light_pos_x-1
		else:
			light_pos_y = light_pos_y-1
		
	if abs(ctx.x) == light_pos_x && abs(ctx.y) == light_pos_y:
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
	var data: Array[Pixel] = ctx.previous_pass.data
	if (ctx.get_at_offset(data, offset_x, offset_y) & TILE_MASK) == Pixel.TILE_WALL:
		var wall_w: bool =  ctx.previous_pass.wall_w;
		var wall_e: bool =  ctx.previous_pass.wall_e;
		var wall_s: bool =  ctx.previous_pass.wall_s;
		var wall_n: bool =  ctx.previous_pass.wall_n;
		if(wall_w && !wall_n && !wall_s && !wall_e): return true
		if(!wall_w && wall_n && !wall_s && !wall_e): return true
		if(!wall_w && !wall_n && wall_s && !wall_e): return true
		if(!wall_w && !wall_n && !wall_s && wall_e): return true
	return false


const NUM_PASSES_IN_GEN_BIOMES = 1 # change this everytime you change the amount of cases in 'match pass_index' below
func _gen_biomes(pass_index: int, ctx: Context) -> Pixel:	
	match pass_index:
		0:
			var grid_low_x = ctx.x / 40
			var grid_low_y = ctx.y / 40
			var random_low = ctx.random_with_seed(hash(Vector2i(grid_low_x, grid_low_y)))
			if random_low < 0.2:
				return Pixel.BIOME_PILLARS
			else:
				return Pixel.BIOME_DEFAULT
	return Pixel.INVALID

func _gen(pass_index: int, ctx: Context) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	if pass_index < NUM_PASSES_IN_GEN_BIOMES:
		return _gen_biomes(pass_index, ctx)
	else:
		var biome_pass_index: int = pass_index - NUM_PASSES_IN_GEN_BIOMES
		match pp.biome_c:
			Pixel.BIOME_DEFAULT:
				var huh = _gen_biome_default(biome_pass_index, ctx)
				return huh
			Pixel.BIOME_PILLARS:
				return _gen_biome_pillars(biome_pass_index, ctx)
	
	return Pixel.INVALID

func _gen_biome_default(pass_index: int, ctx: Context) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	var num_neighbour_walls: int = 0;
	if pp.wall_w: num_neighbour_walls = num_neighbour_walls + 1
	if pp.wall_e: num_neighbour_walls = num_neighbour_walls + 1
	if pp.wall_s: num_neighbour_walls = num_neighbour_walls + 1
	if pp.wall_n: num_neighbour_walls = num_neighbour_walls + 1
	
	match pass_index:
		0:
			if ctx.random() > 0.9:
				return pp.biome_c | Pixel.TILE_WALL
			if _ceiling_light(ctx, 0.7):
				return pp.biome_c | Pixel.TILE_CEILING_LIGHT
			return pp.biome_c | Pixel.TILE_EMPTY
	
		1:
			if num_neighbour_walls > 0 && !pp.wall_c:
				if ctx.random() > 0.75:
					return pp.biome_c | Pixel.TILE_WALL
			return pp.pixel_c
			
		2:
			if _is_isolated_wall_dot(ctx):
				return pp.biome_c | Pixel.TILE_EMPTY
			return pp.pixel_c
		
		3,4,5,6,7,8,9,10:
			if ctx.random() > 0.1:
				if _extend_walls(ctx):
					return pp.biome_c | Pixel.TILE_WALL
			return pp.pixel_c
		
	return Pixel.INVALID

func _gen_biome_pillars(pass_index: int, ctx: Context) -> Pixel:
	var pp: PreviousPass = ctx.previous_pass
	
	match pass_index:
		0:
			if _ceiling_light(ctx, 0.1):
				return pp.biome_c | Pixel.TILE_CEILING_LIGHT
			return pp.biome_c | Pixel.TILE_EMPTY
			
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
	
	var pixel_c = Pixel
	var tile_c = Pixel
	var biome_c = Pixel
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
		pixel_c = ctx.get_at(data)
		biome_c = TileUtils.get_biome(pixel_c)
		tile_c = pixel_c - biome_c
		wall_c = (ctx.get_at(data) & TILE_MASK) == Pixel.TILE_WALL
		wall_n = (ctx.get_at_offset(data, 0, 1) & TILE_MASK) == Pixel.TILE_WALL
		wall_nn = (ctx.get_at_offset(data, 0, 2) & TILE_MASK) == Pixel.TILE_WALL
		wall_s = (ctx.get_at_offset(data, 0, -1) & TILE_MASK) == Pixel.TILE_WALL
		wall_ss = (ctx.get_at_offset(data, 0, -2) & TILE_MASK) == Pixel.TILE_WALL
		wall_e = (ctx.get_at_offset(data, 1, 0) & TILE_MASK) == Pixel.TILE_WALL
		wall_ee = (ctx.get_at_offset(data, 2, 0) & TILE_MASK) == Pixel.TILE_WALL
		wall_w = (ctx.get_at_offset(data, -1, 0) & TILE_MASK) == Pixel.TILE_WALL
		wall_ww = (ctx.get_at_offset(data, -2, 0) & TILE_MASK) == Pixel.TILE_WALL
		wall_nw = (ctx.get_at_offset(data, -1, 1) & TILE_MASK) == Pixel.TILE_WALL
		wall_ne = (ctx.get_at_offset(data, 1, 1) & TILE_MASK) == Pixel.TILE_WALL
		wall_sw = (ctx.get_at_offset(data, -1, -1) & TILE_MASK) == Pixel.TILE_WALL
		wall_se = (ctx.get_at_offset(data, 1, -1) & TILE_MASK) == Pixel.TILE_WALL

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
	
	func random_with_seed(seed_val: int) -> float:
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
	
	var was_valid = true
	var pass_index = 1
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
	var all_pixels_set_to_count = true
	
	target.resize(context.w * context.h);
	for y in range(y0, y1):
		var ly: int = y - y0
		context.ly = ly
		for x in range(x0, x1):
			var lx: int = x - x0
			var index = lx + ly * width
			context.x = x;
			context.y = y;
			context.lx = lx
			context.x_flt = float(x);
			context.y_flt = float(y);
			context.previous_pass.update(context)
			var pixel = _gen(pass_index, context);
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
		match pixel:
			Pixel.BIOME_DEFAULT: 					return Color(0.887, 0.975, 1.0, 1.0)
			Pixel.BIOME_PILLARS: 					return Color(0.811, 1.0, 0.792, 1.0)
			Pixel.BIOME_DEFAULT | Pixel.TILE_EMPTY: return Color(0.587, 0.723, 1.0, 1.0)
			Pixel.BIOME_PILLARS | Pixel.TILE_EMPTY: return Color(0.0, 0.886, 0.522, 1.0)
		
		match pixel & TILE_MASK:
			Pixel.TILE_CEILING_LIGHT:				return Color(0,1,1)
			Pixel.TILE_WALL:						return Color(0,0,0)
		
		var h := fmod(abs(sin(float(pixel) * 12.9898) * 43758.5453), 1.0)
		return Color.from_hsv(h, 0.7, 1.0)
		
		# return Color(1,0,1)
