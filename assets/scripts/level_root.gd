class_name LevelRoot
extends Node

var _player: Player = null
var player: Player: 
	get: return _player
	

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("RREADY!!!")
	# Try to find the player in the scene tree via group
	var tree: SceneTree = get_tree()
	if _player == null:
		_player = tree.get_first_node_in_group("player")
	
	# Fallback: search by class if group is not set
	if _player == null:
		var players: Array[Node] = tree.get_nodes_in_group("player")
		if not players.is_empty():
			_player = players[0] as Player
		
	# Last resort: deep search
	if _player == null:
		for node in tree.get_root().find_children("*", "CharacterBody3D", true, false):
			if node is Player:
				_player = node as Player
				break
			
	if _player == null:
		push_error("Player not found in scene tree")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(_delta: float) -> void:
#	pass
	
