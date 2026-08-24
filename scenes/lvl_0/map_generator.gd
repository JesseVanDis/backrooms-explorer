extends Node

class_name MapGenerator

enum TileType {
	EMPTY,
	CEILING_LIGHT,
	WALL,
}

class PlotData:
	var x: int
	var y: int
	var color: Color

	func _init(_x: int, _y: int, _color: Color) -> void:
		x = _x
		y = _y
		color = _color

class Context:
	var x: int
	var y: int
	
	func random() -> float:
		var seed_value = hash(Vector2i(int(x), int(y)))
		var rng = RandomNumberGenerator.new()
		rng.seed = seed_value
		return rng.randf()

func _mapshader_standard(context: Context) -> TileType:
	if context.random() > 0.5:
		return TileType.WALL
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
	
	var cb: Callable = func(context: Context, tile_type: TileType) -> void:
		image.set_pixel(context.x, context.y, to_color(tile_type))
	
	generate_map(0, 0, width, height, cb);
	return image;
	

func generate_map(x0: int, y0: int, x1: int, y1: int, cb: Callable) -> void:
	var context: Context = Context.new()
	for y in range(x0, x1):
		for x in range(y0, y1):
			context.x = x;
			context.y = y;
			var pixel = _mapshader_standard(context);
			cb.call(context, pixel);
