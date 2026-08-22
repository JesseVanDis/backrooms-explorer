extends Node

## Generates a black & white maze PNG.
## white background (1.0), black pixels = walls (0.0)
func generate_map(width: int, height: int, map_seed: int, debug_png_filename: String) -> void:
	seed(map_seed)
	
	# Create image
	var image := Image.create(width, height, false, Image.FORMAT_L8)
	image.fill(Color.WHITE) # Background is white
	
	# Maze generation (Recursive Backtracking on a grid)
	# We'll use a grid where each cell is 2x2 pixels to ensure walls are 1 pixel thick.
	# Or better, we just use a standard grid and draw walls.
	# Actually, to fit 512x512 exactly, let's just do a pixel-based approach.
	
	# Simple randomized DFS for maze generation.
	# We will treat the image as a grid of "cells" and "walls".
	# For simplicity in a 512x512 image, let's use a cell size of 2.
	# Cells at (odd, odd), walls at (even, any) and (any, even).
	
	# Fill with black first (all walls), then carve out white paths.
	image.fill(Color.BLACK)
	
	var grid_width := width / 2
	var grid_height := height / 2
	
	var stack := []
	var visited := []
	for i in range(grid_width):
		var row := []
		for j in range(grid_height):
			row.append(false)
		visited.append(row)
	
	var start_x := 0
	var start_y := 0
	visited[start_x][start_y] = true
	stack.push_back(Vector2i(start_x, start_y))
	
	# Carve the start point
	image.set_pixel(start_x * 2 + 1, start_y * 2 + 1, Color.WHITE)
	
	while stack.size() > 0:
		var current = stack[stack.size() - 1]
		var neighbors := []
		
		# Check neighbors (Up, Down, Left, Right)
		var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
		for dir in directions:
			var nx = current.x + dir.x
			var ny = current.y + dir.y
			if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
				if not visited[nx][ny]:
					neighbors.append(dir)
		
		if neighbors.size() > 0:
			var dir = neighbors[randi() % neighbors.size()]
			var next = current + dir
			
			visited[next.x][next.y] = true
			
			# Carve the path in the image
			# Cell is at (x*2+1, y*2+1)
			# Wall between current and next is at current*2+1 + dir
			var nx_pixel: int = next.x * 2 + 1
			var ny_pixel: int = next.y * 2 + 1
			var wx_pixel: int = current.x * 2 + 1 + dir.x
			var wy_pixel: int = current.y * 2 + 1 + dir.y
			
			if nx_pixel < width and ny_pixel < height:
				image.set_pixel(nx_pixel, ny_pixel, Color.WHITE)
			if wx_pixel < width and wy_pixel < height:
				image.set_pixel(wx_pixel, wy_pixel, Color.WHITE)
			
			stack.push_back(next)
		else:
			stack.pop_back()
			
	# Ensure borders are black (walls) - though they should be by default
	
	# Save image
	var err := image.save_png(debug_png_filename)
	if err != OK:
		push_error("Failed to save maze image: " + str(err))
