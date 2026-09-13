extends Node

class_name UtilsMesh

static func find_mesh_recursive(root_node: Node) -> MeshInstance3D:
	if root_node is MeshInstance3D:
		return root_node
	
	for child in root_node.get_children():
		var result: MeshInstance3D = find_mesh_recursive(child)
		if result:
			return result
			
	return null
