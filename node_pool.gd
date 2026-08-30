extends Node

#class_name MapGenerator
class_name NodePool

class Pool:
	var counter: int = 0
	var reference_node: Node3D
	var archive_node: Node3D

	func _create() -> Node3D:
		var copy = reference_node.duplicate()
		copy.name = reference_node.name + "_<>_" + str(counter)
		counter = counter+1
		#print("nodecount of: " + reference_node.name + " is: " + str(counter))
		return copy
		
	func get_auto_create() -> Node3D:
		if archive_node.get_child_count() > 0:
			var child = archive_node.get_child(0)
			archive_node.remove_child(child)
			return child
		print("created for: " + str(counter))
		return _create()

	func archive(created_node: Node3D) -> void:
		created_node.reparent(archive_node)
		pass
	
	func _init(node_reference: Node3D) -> void:
		reference_node = node_reference
		archive_node = Node3D.new()
		# pre-allocate
		print("Pre allocating '" + reference_node.name + "'...")
		for i in range(0, 20000):
			var node = _create()
			archive_node.add_child(node)
		print("Pre allocating '" + reference_node.name + "'... Done")
		pass;



var pools: Dictionary = {} # string, Pool

func get_auto_create(reference_node: Node3D) -> Node3D:
	var pool: Pool = _get_pool_auto_create(reference_node)
	return pool.get_auto_create()

func archive(created_node: Node3D) -> void:
	var reference_node_name = created_node.name.split("_<>_")[0]
	if pools.has(reference_node_name):
		var pool = pools[reference_node_name]
		pool.archive(created_node)

func _get_pool_auto_create(reference_node: Node3D) -> Pool:
	var pool: Pool = null
	if pools.has(reference_node.name):
		pool = pools[reference_node.name]
	else:
		pool = Pool.new(reference_node)
		pool.reference_node = reference_node
		pools[reference_node.name] = pool
	return pool

func _init() -> void:
	pass;
