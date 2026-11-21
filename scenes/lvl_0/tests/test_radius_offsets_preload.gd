## [AI-DOC] Headless regression for asynchronous Level 0 radius-offset table preloading
## spec: scenes/lvl_0/docs/SPEC.md
## status: complete

extends SceneTree

const PRELOAD_TIMEOUT_MSEC: int = 180000

# Starts after script initialization so the test can safely create level instances and await worker progress.
func _initialize() -> void:
	call_deferred("_run_test")


# Exercises one shared async build, owner destruction, complete bucket coverage, conservative candidates, and synchronous reuse.
func _run_test() -> void:
	var first_level: Lvl_0 = Lvl_0.new()
	if first_level == null:
		push_error("Failed to instantiate the first Lvl_0 for radius-offset preload test")
		quit(1)
		return

	var first_poll_completed: bool = first_level._preload_radius_offsets_table(true)
	var shared_thread: Thread = Lvl_0._radius_offsets_preload_thread
	var second_level: Lvl_0 = Lvl_0.new()
	if second_level == null:
		push_error("Failed to instantiate the second Lvl_0 for radius-offset preload test")
		first_level.free()
		quit(1)
		return

	var second_poll_completed: bool = second_level._preload_radius_offsets_table(true)
	if Lvl_0._radius_offsets_preload_thread != shared_thread:
		push_error("Concurrent async requests did not share the radius-offset worker")
		first_level.free()
		second_level.free()
		quit(1)
		return

	first_level.free()
	var preload_deadline_msec: int = Time.get_ticks_msec() + PRELOAD_TIMEOUT_MSEC
	while not first_poll_completed and not second_poll_completed:
		if Time.get_ticks_msec() >= preload_deadline_msec:
			push_error("Timed out waiting for the shared radius-offset table worker")
			second_level.free()
			quit(1)
			return
		await process_frame
		second_poll_completed = second_level._preload_radius_offsets_table(true)

	if not second_poll_completed and not first_poll_completed:
		push_error("Async radius-offset preload never reported completion")
		second_level.free()
		quit(1)
		return

	if not _assert_all_angle_buckets_cached():
		second_level.free()
		quit(1)
		return
	if not _assert_candidates_cover_bucket_boundaries(second_level):
		second_level.free()
		quit(1)
		return
	if not second_level._preload_radius_offsets_table(false):
		push_error("Synchronous radius-offset preload did not reuse the completed table")
		second_level.free()
		quit(1)
		return
	if Lvl_0._radius_offsets_preload_thread != shared_thread:
		push_error("Synchronous radius-offset preload replaced the completed worker")
		second_level.free()
		quit(1)
		return

	second_level.free()
	print("TEST: PASS")
	quit(0)


# Confirms every rounded heading has a published candidate array before preload reports completion.
func _assert_all_angle_buckets_cached() -> bool:
	for player_yaw_rounded: int in range(0, 360, Lvl_0.RADIUS_OFFSETS_ANGLE_STEP_DEGREES):
		var cache_key: Vector3i = Vector3i(Lvl_0.VIEW_DISTANCE_AA, player_yaw_rounded, 1)
		if not Lvl_0._radius_offsets_cache.has(cache_key):
			push_error("Radius-offset table is missing angle bucket " + str(player_yaw_rounded))
			return false
		var offsets: Array[Vector2i] = Lvl_0._radius_offsets_cache[cache_key]
		if offsets.is_empty():
			push_error("Radius-offset table has no candidates for angle bucket " + str(player_yaw_rounded))
			return false
	return true


# Checks every potentially visible offset against the bucket start and end headings to catch candidate omissions at quantization boundaries.
func _assert_candidates_cover_bucket_boundaries(level: Lvl_0) -> bool:
	for player_yaw_rounded: int in range(0, 360, Lvl_0.RADIUS_OFFSETS_ANGLE_STEP_DEGREES):
		var boundary_angles: Array[float] = [float(player_yaw_rounded), float(player_yaw_rounded) + float(Lvl_0.RADIUS_OFFSETS_ANGLE_STEP_DEGREES) - 0.0001]
		for angle_degrees: float in boundary_angles:
			var cache_key: Vector3i = Vector3i(Lvl_0.VIEW_DISTANCE_AA, player_yaw_rounded, 1)
			var offsets: Array[Vector2i] = Lvl_0._radius_offsets_cache[cache_key]
			var candidate_offsets: Dictionary = {}
			for offset: Vector2i in offsets:
				candidate_offsets[offset] = true

			var angle_radians: float = deg_to_rad(angle_degrees)
			level._cached_forward_direction = Vector2(cos(angle_radians), sin(angle_radians))
			for offset_y: int in range(-Lvl_0.VIEW_DISTANCE_AA, Lvl_0.VIEW_DISTANCE_AA + 1):
				for offset_x: int in range(-Lvl_0.VIEW_DISTANCE_AA, Lvl_0.VIEW_DISTANCE_AA + 1):
					var distance_squared: int = offset_x * offset_x + offset_y * offset_y
					if distance_squared >= Lvl_0.VIEW_DISTANCE_AA * Lvl_0.VIEW_DISTANCE_AA:
						continue
					if distance_squared >= int(Lvl_0.TILE_VISIBILITY_FOV_RADIUS * Lvl_0.TILE_VISIBILITY_FOV_RADIUS) and abs(offset_x) >= int(Lvl_0.TILE_VISIBILITY_FORWARD_WIDTH) and abs(offset_y) >= int(Lvl_0.TILE_VISIBILITY_FORWARD_WIDTH):
						continue

					var offset: Vector2i = Vector2i(offset_x, offset_y)
					if level._is_tile_visible(offset, Vector2i.ZERO) and not candidate_offsets.has(offset):
						push_error("Visibility candidate missing at angle " + str(angle_degrees) + " for offset " + str(offset))
						return false
	return true