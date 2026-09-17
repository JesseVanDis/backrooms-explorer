extends Node

class_name UtilsNode

static func find_mesh_recursive(root_node: Node) -> MeshInstance3D:
	if root_node is MeshInstance3D:
		return root_node
	
	for child in root_node.get_children():
		var result: MeshInstance3D = find_mesh_recursive(child)
		if result:
			return result
			
	return null

static func find_animation_player_recursive(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node
	
	for child in root_node.get_children():
		var result: AnimationPlayer = find_animation_player_recursive(child)
		if result:
			return result
			
	return null

static func find_camera_recursive(root_node: Node) -> Camera3D:
	if root_node is Camera3D:
		return root_node
	
	for child in root_node.get_children():
		var result: Camera3D = find_camera_recursive(child)
		if result:
			return result
			
	return null

static func find_player(tree: SceneTree) -> Player:
	# Try to find the player in the scene tree via group
	var player: Player = tree.get_first_node_in_group("player")
	if player:
		return player
	
	# Fallback: search by class if group is not set
	var players: Array[Node] = tree.get_nodes_in_group("player")
	if not players.is_empty():
		return players[0] as Player
		
	# Last resort: deep search
	for node in tree.get_root().find_children("*", "CharacterBody3D", true, false):
		if node is Player:
			return node as Player
			
	return null
