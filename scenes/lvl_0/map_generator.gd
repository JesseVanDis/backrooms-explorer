extends Node

class_name MapGenerator

enum TileType {
	EMPTY,
	CEILING_LIGHT,
	WALL,
}

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
	
	func _init() -> void:
		pass;

class Context:
	var x: int
	var y: int
	
	func random() -> float:
		var seed_value = hash(Vector2i(int(x), int(y)))
		var rng = RandomNumberGenerator.new()
		rng.seed = seed_value
		return rng.randf()

func _mapshader_standard(context: Context) -> TileType:
	if context.random() > 0.9:
		return TileType.CEILING_LIGHT
	return TileType.EMPTY

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
	retval.x = x0;
	retval.y = y0;
	retval.w = x1-x0;
	retval.h = y1-y0;
	retval.data.resize(retval.w * retval.h);
	var cb: Callable = func(context: Context, data: PlotData) -> void:
		retval.set_tile(context.x, context.y, data.tile_type);
	_handle_shaders(x0, y0, x1, y1, cb);
	
	return retval;

func _handle_shaders(x0: int, y0: int, x1: int, y1: int, cb: Callable) -> void:
	var context: Context = Context.new()
	var cb_data: PlotData = PlotData.new()
	for y in range(x0, x1):
		for x in range(y0, y1):
			context.x = x;
			context.y = y;
			cb_data.tile_type = _mapshader_standard(context);
			cb.call(context, cb_data);
