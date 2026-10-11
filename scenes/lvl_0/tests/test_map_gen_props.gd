## [AI-DOC] Headless test script that asserts the chair/trash-bin prop annotation pass of MapGenerator is deterministic, seam-stable and respects its placement rules
## spec: docs/ai/systems/map_generation.md
## status: implemented

extends SceneTree

const SAMPLE_SIZE: int = 256
const MARGIN: int = 8

var _gen: MapGenerator
var _failures: Array[String] = []

func _init() -> void:
	print("Starting MapGenerator prop annotation test...")
	var gen_script: GDScript = load("res://scenes/lvl_0/map_generator.gd")
	if not gen_script:
		push_error("Failed to load map_generator.gd")
		quit(1)
		return

	_gen = gen_script.new()

	_check_determinism()
	_check_overlap_consistency()
	_check_placement_invariants()
	_check_density()

	if _failures.size() > 0:
		for failure: String in _failures:
			push_error(failure)
		print("MapGenerator prop annotation test FAILED (" + str(_failures.size()) + " failure(s))")
		quit(1)
		return

	print("MapGenerator prop annotation test passed")
	quit(0)

func _fail(message: String) -> void:
	_failures.append(message)

func _check_determinism() -> void:
	var section_a: MapGenerator.Section = _gen.generate_map(0, 0, SAMPLE_SIZE, SAMPLE_SIZE, MARGIN)
	var section_b: MapGenerator.Section = _gen.generate_map(0, 0, SAMPLE_SIZE, SAMPLE_SIZE, MARGIN)
	for y in range(0, SAMPLE_SIZE):
		for x in range(0, SAMPLE_SIZE):
			var prop_a: MapGenerator.Pixel = MapGenerator.get_prop(section_a.get_pixel(x, y))
			var prop_b: MapGenerator.Pixel = MapGenerator.get_prop(section_b.get_pixel(x, y))
			if prop_a != prop_b:
				_fail("determinism: prop mismatch at (%d, %d): %s vs %s" % [x, y, prop_a, prop_b])
				return

func _check_overlap_consistency() -> void:
	# two overlapping sections, offset so their overlap is generated through different margins
	var section_a: MapGenerator.Section = _gen.generate_map(0, 0, SAMPLE_SIZE, SAMPLE_SIZE, MARGIN)
	var offset: int = 64
	var section_b: MapGenerator.Section = _gen.generate_map(offset, offset, offset + SAMPLE_SIZE, offset + SAMPLE_SIZE, MARGIN)

	var overlap_x0: int = offset
	var overlap_y0: int = offset
	var overlap_x1: int = SAMPLE_SIZE
	var overlap_y1: int = SAMPLE_SIZE

	var mismatches: int = 0
	for y in range(overlap_y0, overlap_y1):
		for x in range(overlap_x0, overlap_x1):
			var prop_a: MapGenerator.Pixel = MapGenerator.get_prop(section_a.get_pixel(x, y))
			var prop_b: MapGenerator.Pixel = MapGenerator.get_prop(section_b.get_pixel(x, y))
			if prop_a != prop_b:
				mismatches += 1
	if mismatches > 0:
		_fail("overlap consistency: %d pixel(s) disagree on their prop marker in the overlapping region" % mismatches)

func _check_placement_invariants() -> void:
	var section: MapGenerator.Section = _gen.generate_map(0, 0, SAMPLE_SIZE, SAMPLE_SIZE, MARGIN)

	var spawn_exclusion: int = 12 # mirrors PROP_SPAWN_EXCLUSION_RADIUS
	var chair_positions: Array[Vector2i] = []
	var bin_positions: Array[Vector2i] = []

	for y in range(0, SAMPLE_SIZE):
		for x in range(0, SAMPLE_SIZE):
			var pixel: MapGenerator.Pixel = section.get_pixel(x, y)
			var prop: MapGenerator.Pixel = MapGenerator.get_prop(pixel)
			if prop == MapGenerator.Pixel.NONE:
				continue

			if (pixel & MapGenerator.TILE_MASK) != MapGenerator.Pixel.TILE_EMPTY:
				_fail("placement: prop at (%d, %d) is not on a TILE_EMPTY tile" % [x, y])

			if absi(x) < spawn_exclusion && absi(y) < spawn_exclusion:
				_fail("placement: prop at (%d, %d) is inside the spawn exclusion zone" % [x, y])

			if prop == MapGenerator.Pixel.PROP_CHAIR:
				chair_positions.append(Vector2i(x, y))
			elif prop == MapGenerator.Pixel.PROP_TRASH_BIN:
				bin_positions.append(Vector2i(x, y))
				var wall_count: int = 0
				if (section.get_pixel(x, y - 1) & MapGenerator.TILE_MASK) == MapGenerator.Pixel.TILE_WALL: wall_count += 1
				if (section.get_pixel(x, y + 1) & MapGenerator.TILE_MASK) == MapGenerator.Pixel.TILE_WALL: wall_count += 1
				if (section.get_pixel(x + 1, y) & MapGenerator.TILE_MASK) == MapGenerator.Pixel.TILE_WALL: wall_count += 1
				if (section.get_pixel(x - 1, y) & MapGenerator.TILE_MASK) == MapGenerator.Pixel.TILE_WALL: wall_count += 1
				if wall_count != 1:
					_fail("placement: trash bin at (%d, %d) does not have exactly one adjacent wall (has %d)" % [x, y, wall_count])
			else:
				_fail("placement: unexpected prop value %s at (%d, %d)" % [prop, x, y])

	_check_min_spacing(chair_positions, 6, "chair")
	_check_min_spacing(bin_positions, 6, "trash bin")

func _check_min_spacing(positions: Array[Vector2i], min_distance: int, label: String) -> void:
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var dist: float = Vector2(positions[i]).distance_to(Vector2(positions[j]))
			if dist < min_distance:
				_fail("spacing: two %ss are closer than %d tiles: %s and %s (dist %.2f)" % [label, min_distance, positions[i], positions[j], dist])
				return

func _check_density() -> void:
	var section: MapGenerator.Section = _gen.generate_map(0, 0, SAMPLE_SIZE, SAMPLE_SIZE, MARGIN)
	var chair_count: int = 0
	var bin_count: int = 0
	var prop_on_same_tile_as_other_prop: int = 0

	for y in range(0, SAMPLE_SIZE):
		for x in range(0, SAMPLE_SIZE):
			var prop: MapGenerator.Pixel = MapGenerator.get_prop(section.get_pixel(x, y))
			if prop == MapGenerator.Pixel.PROP_CHAIR:
				chair_count += 1
			elif prop == MapGenerator.Pixel.PROP_TRASH_BIN:
				bin_count += 1
			elif prop != MapGenerator.Pixel.NONE:
				prop_on_same_tile_as_other_prop += 1

	print("sample %dx%d -> chairs: %d, trash bins: %d" % [SAMPLE_SIZE, SAMPLE_SIZE, chair_count, bin_count])

	if chair_count == 0:
		_fail("density: no chairs found in a %dx%d sample" % [SAMPLE_SIZE, SAMPLE_SIZE])
	if bin_count == 0:
		_fail("density: no trash bins found in a %dx%d sample" % [SAMPLE_SIZE, SAMPLE_SIZE])
	if prop_on_same_tile_as_other_prop > 0:
		_fail("density: %d tile(s) carry an unrecognised combination of prop bits" % prop_on_same_tile_as_other_prop)

	var total_tiles: int = SAMPLE_SIZE * SAMPLE_SIZE
	var total_props: int = chair_count + bin_count
	if float(total_props) > (float(total_tiles) * 0.05):
		_fail("density: props are not sparse - %d of %d tiles carry a prop" % [total_props, total_tiles])
