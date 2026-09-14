extends Node

class_name UtilsScreen

static func fade_in(root_node: Node, duration: float, callback: Callable) -> void:
	if root_node == null:
		push_error("root_node is null")
		return
		
	var canvas_layer: CanvasLayer = root_node.get_node("CanvasLayer")
	if canvas_layer == null:
		push_error("CanvasLayer not found in node: " + root_node.name)
		callback.call()
		return

	for child in canvas_layer.get_children():
		if "modulate" in child:
			child.modulate.a = 0.0
	
	var tween: Tween = root_node.create_tween()
	for child in canvas_layer.get_children():
		if "modulate" in child:
			tween.parallel().tween_property(child, "modulate:a", 1.0, duration)
	
	tween.tween_callback(callback)


static func fade_in_loading_screen(tree: SceneTree, callback: Callable) -> Node:
	const DURATION = 0.3
	const LOADING_SCREEN_PATH: String = "res://scenes/menu_loading/menu_loading.tscn"
	var loading_scene: PackedScene = load(LOADING_SCREEN_PATH)
	if loading_scene == null:
		push_error("Failed to load loading screen scene")
		callback.call()
		return null
	
	var loading_screen: Node = loading_scene.instantiate()
	if loading_screen == null:
		push_error("Failed to instantiate loading screen")
		callback.call()
		return null
	
	tree.root.add_child(loading_screen)
	fade_in(loading_screen, DURATION, callback)
	return loading_screen


static func fade_out(root_node: Node, duration: float, callback: Callable) -> void:
	if root_node == null:
		push_error("root_node is null")
		return
		
	var canvas_layer: CanvasLayer = root_node.get_node("CanvasLayer")
	if canvas_layer == null:
		push_error("CanvasLayer not found in node: " + root_node.name)
		callback.call()
		return
	
	var tween: Tween = root_node.create_tween()
	for child in canvas_layer.get_children():
		if "modulate" in child:
			tween.parallel().tween_property(child, "modulate:a", 0.0, duration)
	
	tween.tween_callback(callback)


static func fade_out_loading_screen(tree: SceneTree) -> void:
	const DURATION = 0.3
	var loading_screen: Node = tree.root.get_node_or_null("MenuLoading")
	if loading_screen == null:
		# It's okay if it's not there
		return
	
	fade_out(loading_screen, DURATION, loading_screen.queue_free)
