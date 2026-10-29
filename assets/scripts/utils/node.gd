## [AI-DOC] Static scene tree lookup helpers that recursively find a mesh, animation player, camera or hands node, and locate the player
## spec: docs/ai/systems/utils.md
## status: implemented

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

static func find_node_with_name_recursive(root_node: Node, node_name: String) -> Node:
	if root_node.name == node_name:
		return root_node
	
	for child in root_node.get_children():
		var result = find_node_with_name_recursive(child, node_name)
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

static func find_hands_recursive(root_node: Node) -> PlayerHands:
	if root_node is PlayerHands:
		return root_node
	
	for child in root_node.get_children():
		var result: PlayerHands = find_hands_recursive(child)
		if result:
			return result
			
	return null


static func set_shader_param(node: Node, path_to_mesh_instance_3d: NodePath, uniform_name: StringName, value: Variant, make_material_unique: bool = true, unique_material_cache: Dictionary = {}) -> void:
	var mesh_instance := node.get_node_or_null(path_to_mesh_instance_3d) as MeshInstance3D
	if mesh_instance == null:
		push_warning("MeshInstance3D not found: " + str(path_to_mesh_instance_3d))
		return
	#var instance_uniform: Variant = mesh_instance.get_instance_shader_parameter(uniform_name)
	#if instance_uniform != null:
		#mesh_instance.set_instance_shader_parameter(uniform_name, value)
		#return
	#push_warning("uniform '" + uniform_name + "' in node: " + str(path_to_mesh_instance_3d) + " seems not to be a instance uniform. please use 'instance uniform' in you shader instead of just 'uniform'. Using fallback by creating an entire new material with the correct uniform value")
	
	var material := mesh_instance.material_override as ShaderMaterial

	if material == null:
		material = mesh_instance.get_active_material(0) as ShaderMaterial

	if material == null:
		push_warning("No ShaderMaterial found on: " + str(path_to_mesh_instance_3d))
		return

	if make_material_unique:
		var key: String = str(path_to_mesh_instance_3d) + ":" + str(uniform_name) + "=" + str(value)
		var cached_material: ShaderMaterial = unique_material_cache.get(key)
		if cached_material:
			mesh_instance.material_override = cached_material
			return
		material = material.duplicate() as ShaderMaterial
		mesh_instance.material_override = material
		unique_material_cache[key] = material
		
	if material.get_shader_parameter(uniform_name) == null:
		push_error("Shader numiform name '" + uniform_name + "' doest not exist for object '" + str(mesh_instance.name) + "'.")
	material.set_shader_parameter(uniform_name, value)

static func print_node_children_recursive(node: Node, indent: int = 0) -> void:
	if node == null:
		return
	print("\t".repeat(indent) + str(node.name))
	for child in node.get_children():
		print_node_children_recursive(child, indent + 1)

# UNTESTED!!
static func merge_meshes(nodes: Array[Node3D]) -> Node3D:
	var root := Node3D.new()
	var output := MeshInstance3D.new()
	var mesh := ArrayMesh.new()

	# Use the first input as the coordinate-space reference.
	var reference := nodes[0].global_transform if not nodes.is_empty() else Transform3D.IDENTITY
	root.global_transform = reference

	# One surface per source mesh surface/material.
	var surfaces: Dictionary = {}

	for source in nodes:
		if source == null:
			continue

		var instances: Array[Node] = []
		if source is MeshInstance3D:
			instances.append(source)
		instances.append_array(
			source.find_children("*", "MeshInstance3D", true, false)
		)

		for item in instances:
			var mi := item as MeshInstance3D
			if mi.mesh == null:
				continue

			var relative := reference.affine_inverse() * mi.global_transform

			for s in range(mi.mesh.get_surface_count()):
				var source_mesh := mi.mesh as ArrayMesh
				if source_mesh == null:
					continue
				if source_mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
					continue
					
				var source_arrays := mi.mesh.surface_get_arrays(s)
				var src_vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
				var src_normals: PackedVector3Array = source_arrays[Mesh.ARRAY_NORMAL]
				var src_uvs: PackedVector2Array = source_arrays[Mesh.ARRAY_TEX_UV]
				var src_indices: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]

				# Group by material resource and surface material override.
				var material: Material = mi.get_active_material(s)
				var key: Material = material

				if not surfaces.has(key):
					surfaces[key] = {
						"vertices": PackedVector3Array(),
						"normals": PackedVector3Array(),
						"uvs": PackedVector2Array(),
						"indices": PackedInt32Array(),
						"material": material
					}

				var data: Dictionary = surfaces[key]
				var verts: PackedVector3Array = data["vertices"]
				var norms: PackedVector3Array = data["normals"]
				var uvs: PackedVector2Array = data["uvs"]
				var inds: PackedInt32Array = data["indices"]
				var offset := verts.size()
				var normal_xform := relative.basis.inverse().transposed()

				for i in range(src_vertices.size()):
					verts.append(relative * src_vertices[i])

					if src_normals.size() == src_vertices.size():
						norms.append((normal_xform * src_normals[i]).normalized())
					else:
						norms.append(Vector3.UP)

					if src_uvs.size() == src_vertices.size():
						uvs.append(src_uvs[i])
					else:
						uvs.append(Vector2.ZERO)

				if src_indices.is_empty():
					for i in range(src_vertices.size()):
						inds.append(offset + i)
				else:
					for i in src_indices:
						inds.append(offset + i)

				data["vertices"] = verts
				data["normals"] = norms
				data["uvs"] = uvs
				data["indices"] = inds
				surfaces[key] = data

	for material: Material in surfaces:
		var data: Dictionary = surfaces[material]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
		arrays[Mesh.ARRAY_NORMAL] = data["normals"]
		arrays[Mesh.ARRAY_TEX_UV] = data["uvs"]
		arrays[Mesh.ARRAY_INDEX] = data["indices"]

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		var surface_idx := mesh.get_surface_count() - 1
		if material != null:
			mesh.surface_set_material(surface_idx, material)

	output.mesh = mesh
	root.add_child(output)
	return root
