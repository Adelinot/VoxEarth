extends RefCounted
class_name Chunk

const CHUNK_SIZE = 16
const CHUNK_SIZE_SQ = 256

var chunk_pos: Vector3i
var data: PackedInt32Array
var world

var body: StaticBody3D
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D

func _init(pos: Vector3i, world_node):
	self.chunk_pos = pos
	self.world = world_node
	data.resize(4096)
	data.fill(0)

func get_flat_index(x: int, y: int, z: int) -> int:
	return x + (z * CHUNK_SIZE) + (y * CHUNK_SIZE_SQ)

func update_mesh(high_priority: bool = false):
	if world.mesh_build_queue.has(self):
		if high_priority:
			world.mesh_build_queue.erase(self)
			world.mesh_build_queue.push_front(self)
	else:
		if high_priority:
			world.mesh_build_queue.push_front(self)
		else:
			world.mesh_build_queue.append(self)

func free_nodes():
	if is_instance_valid(collision_shape):
		collision_shape.shape = null
	if is_instance_valid(body):
		body.queue_free()
		body = null
		mesh_instance = null
		collision_shape = null

func generate_mesh_immediate():
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	# --- 1. UP FACE (+Y) ---
	for y in range(CHUNK_SIZE):
		var mask = PackedInt32Array()
		mask.resize(CHUNK_SIZE_SQ)
		
		for z in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var block_type = data[get_flat_index(x, y, z)]
				if block_type == 0: continue
				
				var visible = false
				if y + 1 < CHUNK_SIZE:
					visible = (data[get_flat_index(x, y + 1, z)] == 0)
				else:
					var global_pos = Vector3i(x, y + 1, z) + (chunk_pos * CHUNK_SIZE)
					visible = (world.get_global_block(global_pos) == 0)
					
				if visible:
					mask[x + z * CHUNK_SIZE] = block_type
		_mesh_mask(mask, vertices, normals, uvs, indices, y, "UP")

	# --- 2. DOWN FACE (-Y) ---
	for y in range(CHUNK_SIZE):
		var mask = PackedInt32Array()
		mask.resize(CHUNK_SIZE_SQ)
		
		for z in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var block_type = data[get_flat_index(x, y, z)]
				if block_type == 0: continue
				
				var visible = false
				if y - 1 >= 0:
					visible = (data[get_flat_index(x, y - 1, z)] == 0)
				else:
					var global_pos = Vector3i(x, y - 1, z) + (chunk_pos * CHUNK_SIZE)
					visible = (world.get_global_block(global_pos) == 0)
					
				if visible:
					mask[x + z * CHUNK_SIZE] = block_type
		_mesh_mask(mask, vertices, normals, uvs, indices, y, "DOWN")

	# --- 3. NORTH FACE (-Z) ---
	for z in range(CHUNK_SIZE):
		var mask = PackedInt32Array()
		mask.resize(CHUNK_SIZE_SQ)
		
		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var block_type = data[get_flat_index(x, y, z)]
				if block_type == 0: continue
				
				var visible = false
				if z - 1 >= 0:
					visible = (data[get_flat_index(x, y, z - 1)] == 0)
				else:
					var global_pos = Vector3i(x, y, z - 1) + (chunk_pos * CHUNK_SIZE)
					visible = (world.get_global_block(global_pos) == 0)
					
				if visible:
					mask[x + y * CHUNK_SIZE] = block_type
		_mesh_mask(mask, vertices, normals, uvs, indices, z, "NORTH")

	# --- 4. SOUTH FACE (+Z) ---
	for z in range(CHUNK_SIZE):
		var mask = PackedInt32Array()
		mask.resize(CHUNK_SIZE_SQ)
		
		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var block_type = data[get_flat_index(x, y, z)]
				if block_type == 0: continue
				
				var visible = false
				if z + 1 < CHUNK_SIZE:
					visible = (data[get_flat_index(x, y, z + 1)] == 0)
				else:
					var global_pos = Vector3i(x, y, z + 1) + (chunk_pos * CHUNK_SIZE)
					visible = (world.get_global_block(global_pos) == 0)
					
				if visible:
					mask[x + y * CHUNK_SIZE] = block_type
		_mesh_mask(mask, vertices, normals, uvs, indices, z, "SOUTH")

	# --- 5. EAST FACE (+X) ---
	for x in range(CHUNK_SIZE):
		var mask = PackedInt32Array()
		mask.resize(CHUNK_SIZE_SQ)
		
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				var block_type = data[get_flat_index(x, y, z)]
				if block_type == 0: continue
				
				var visible = false
				if x + 1 < CHUNK_SIZE:
					visible = (data[get_flat_index(x + 1, y, z)] == 0)
				else:
					var global_pos = Vector3i(x + 1, y, z) + (chunk_pos * CHUNK_SIZE)
					visible = (world.get_global_block(global_pos) == 0)
					
				if visible:
					mask[z + y * CHUNK_SIZE] = block_type
		_mesh_mask(mask, vertices, normals, uvs, indices, x, "EAST")

	# --- 6. WEST FACE (-X) ---
	for x in range(CHUNK_SIZE):
		var mask = PackedInt32Array()
		mask.resize(CHUNK_SIZE_SQ)
		
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				var block_type = data[get_flat_index(x, y, z)]
				if block_type == 0: continue
				
				var visible = false
				if x - 1 >= 0:
					visible = (data[get_flat_index(x - 1, y, z)] == 0)
				else:
					var global_pos = Vector3i(x - 1, y, z) + (chunk_pos * CHUNK_SIZE)
					visible = (world.get_global_block(global_pos) == 0)
					
				if visible:
					mask[z + y * CHUNK_SIZE] = block_type
		_mesh_mask(mask, vertices, normals, uvs, indices, x, "WEST")

	var arr_mesh = ArrayMesh.new()
	if vertices.size() > 0:
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		
	_apply_mesh_data(arr_mesh)

func _mesh_mask(mask: PackedInt32Array, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, slice_coord: int, face: String):
	for j in range(CHUNK_SIZE):
		for i in range(CHUNK_SIZE):
			var b = mask[i + j * CHUNK_SIZE]
			if b == 0: continue
			
			# Find combined width
			var w = 1
			while i + w < CHUNK_SIZE and mask[(i + w) + j * CHUNK_SIZE] == b:
				w += 1
				
			# Find combined height
			var h = 1
			var h_ok = true
			while j + h < CHUNK_SIZE:
				for k in range(w):
					if mask[(i + k) + (j + h) * CHUNK_SIZE] != b:
						h_ok = false
						break
				if not h_ok: break
				h += 1
				
			# Clear evaluated mask spaces
			for sj in range(h):
				for si in range(w):
					mask[(i + si) + (j + sj) * CHUNK_SIZE] = 0
					
			# Generate geometry boundaries matching your original winding orientations
			var v0 = Vector3.ZERO; var v1 = Vector3.ZERO; var v2 = Vector3.ZERO; var v3 = Vector3.ZERO
			var normal = Vector3.ZERO
			
			match face:
				"UP":
					v0 = Vector3(i, slice_coord + 1, j + h)
					v1 = Vector3(i + w, slice_coord + 1, j + h)
					v2 = Vector3(i + w, slice_coord + 1, j)
					v3 = Vector3(i, slice_coord + 1, j)
					normal = Vector3.UP
				"DOWN":
					v0 = Vector3(i, slice_coord, j)
					v1 = Vector3(i + w, slice_coord, j)
					v2 = Vector3(i + w, slice_coord, j + h)
					v3 = Vector3(i, slice_coord, j + h)
					normal = Vector3.DOWN
				"NORTH":
					v0 = Vector3(i + w, j, slice_coord)
					v1 = Vector3(i, j, slice_coord)
					v2 = Vector3(i, j + h, slice_coord)
					v3 = Vector3(i + w, j + h, slice_coord)
					normal = Vector3.FORWARD
				"SOUTH":
					v0 = Vector3(i, j, slice_coord + 1)
					v1 = Vector3(i + w, j, slice_coord + 1)
					v2 = Vector3(i + w, j + h, slice_coord + 1)
					v3 = Vector3(i, j + h, slice_coord + 1)
					normal = Vector3.BACK
				"EAST":
					v0 = Vector3(slice_coord + 1, j, i + w)
					v1 = Vector3(slice_coord + 1, j, i)
					v2 = Vector3(slice_coord + 1, j + h, i)
					v3 = Vector3(slice_coord + 1, j + h, i + w)
					normal = Vector3.RIGHT
				"WEST":
					v0 = Vector3(slice_coord, j, i)
					v1 = Vector3(slice_coord, j, i + w)
					v2 = Vector3(slice_coord, j + h, i + w)
					v3 = Vector3(slice_coord, j + h, i)
					normal = Vector3.LEFT

			_add_quad(vertices, normals, uvs, indices, v0, v1, v2, v3, normal, BlockDB.get_block_uvs(b, face))

func _add_quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, uv_arr: Array[Vector2]):
	var v_start = vertices.size()
	
	vertices.append(v0)
	vertices.append(v1)
	vertices.append(v2)
	vertices.append(v3)
	
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	
	uvs.append(uv_arr[0]); uvs.append(uv_arr[1])
	uvs.append(uv_arr[2]); uvs.append(uv_arr[3])
	
	# Retain exact original face winding layout
	indices.append(v_start + 0)
	indices.append(v_start + 2)
	indices.append(v_start + 1)
	
	indices.append(v_start + 0)
	indices.append(v_start + 3)
	indices.append(v_start + 2)

func _apply_mesh_data(arr_mesh: ArrayMesh):
	if arr_mesh.get_surface_count() > 0:
		if not is_instance_valid(body):
			body = StaticBody3D.new()
			mesh_instance = MeshInstance3D.new()
			collision_shape = CollisionShape3D.new()
			
			body.add_child(mesh_instance)
			body.add_child(collision_shape)
			mesh_instance.material_override = preload("res://voxel_material.tres")
			body.position = Vector3(chunk_pos * CHUNK_SIZE)
			world.add_child(body)
			
		mesh_instance.mesh = arr_mesh
		collision_shape.shape = arr_mesh.create_trimesh_shape()
	else:
		free_nodes()
