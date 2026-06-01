extends Node3D

@export var player: Node3D

# POTATO PC OPTIMIZATION: Dropping render distances slightly keeps object counts low
@export var render_distance: int = 3
@export var vertical_render_distance: int = 2

const CHUNKS_PER_FRAME: int = 1
const MESHES_PER_FRAME: int = 1

const MIN_CHUNK_Y: int = -7   
const MAX_CHUNK_Y: int = 2   

var loaded_chunks = {}
var chunk_load_queue: Array[Vector3i] = []
var mesh_build_queue: Array[Chunk] = []

var noise = FastNoiseLite.new()
var last_player_chunk_pos: Vector3i = Vector3i(9999, 9999, 9999)

func _ready():
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	noise.seed = randi()

func _process(_delta):
	if player:
		var current_player_chunk_pos = Vector3i(
			floor(player.global_position.x / 16),
			floor(player.global_position.y / 16),
			floor(player.global_position.z / 16)
		)
		
		if current_player_chunk_pos != last_player_chunk_pos:
			last_player_chunk_pos = current_player_chunk_pos
			update_chunks_around_player(current_player_chunk_pos)
		
	var chunks_built = 0
	while chunk_load_queue.size() > 0 and chunks_built < CHUNKS_PER_FRAME:
		var next_chunk_pos = chunk_load_queue.pop_front()
		if not loaded_chunks.has(next_chunk_pos):
			spawn_chunk(next_chunk_pos)
			chunks_built += 1
			
	var meshes_compiled = 0
	while mesh_build_queue.size() > 0 and meshes_compiled < MESHES_PER_FRAME:
		var chunk_to_render = mesh_build_queue.pop_front()
		if is_instance_valid(chunk_to_render):
			chunk_to_render.generate_mesh_immediate()
			meshes_compiled += 1

func update_chunks_around_player(player_chunk_pos: Vector3i):
	var active_keys = []
	var new_chunks_to_queue = []
	
	for x in range(-render_distance, render_distance + 1):
		for y in range(-vertical_render_distance, vertical_render_distance + 1):
			for z in range(-render_distance, render_distance + 1):
				var target_pos = Vector3i(player_chunk_pos.x + x, player_chunk_pos.y + y, player_chunk_pos.z + z)
				
				if target_pos.y < MIN_CHUNK_Y or target_pos.y > MAX_CHUNK_Y:
					continue
					
				active_keys.append(target_pos)
				
				if not loaded_chunks.has(target_pos) and not target_pos in chunk_load_queue:
					new_chunks_to_queue.append(target_pos)
	
	if new_chunks_to_queue.size() > 0:
		new_chunks_to_queue.sort_custom(func(a, b):
			var dist_a = Vector3(a.x, a.y * 2.0, a.z).distance_to(Vector3(player_chunk_pos.x, player_chunk_pos.y - 1, player_chunk_pos.z))
			var dist_b = Vector3(b.x, b.y * 2.0, b.z).distance_to(Vector3(player_chunk_pos.x, player_chunk_pos.y - 1, player_chunk_pos.z))
			return dist_a < dist_b
		)
		for chunk_pos in new_chunks_to_queue:
			chunk_load_queue.append(chunk_pos)
					
	for key in loaded_chunks.keys():
		if not key in active_keys:
			if loaded_chunks[key] in mesh_build_queue:
				mesh_build_queue.erase(loaded_chunks[key])
			loaded_chunks[key].free_nodes() 
			loaded_chunks.erase(key)

func spawn_chunk(pos: Vector3i):
	var chunk = Chunk.new(pos, self)
	loaded_chunks[pos] = chunk
	
	var id_air = BlockDB.get_int_id("air")
	var id_grass = BlockDB.get_int_id("grass")
	var id_dirt = BlockDB.get_int_id("dirt")
	var id_stone = BlockDB.get_int_id("stone")
	var id_coal = BlockDB.get_int_id("coal_ore")
	var id_iron = BlockDB.get_int_id("iron_ore")
	var id_diamond = BlockDB.get_int_id("diamond_ore")
	
	for x in range(16):
		for z in range(16):
			var global_x = (pos.x * 16) + x
			var global_z = (pos.z * 16) + z
			
			var surface_y = 0 + int(remap(noise.get_noise_2d(global_x, global_z), -1, 1, -8, 12))
			
			for y in range(16):
				var global_y = (pos.y * 16) + y
				var idx = x + (z * 16) + (y * 256)
				
				if global_y == surface_y:
					chunk.data[idx] = id_grass
				elif global_y < surface_y and global_y >= surface_y - 3:
					chunk.data[idx] = id_dirt
				elif global_y < surface_y - 3:
					var roll = randf()
					if global_y <= -60 and roll < 0.015:
						chunk.data[idx] = id_diamond
					elif global_y <= -30 and roll < 0.035:
						chunk.data[idx] = id_iron
					elif global_y <= -5 and roll < 0.06:
						chunk.data[idx] = id_coal
					else:
						chunk.data[idx] = id_stone
				else:
					chunk.data[idx] = id_air
					
	chunk.update_mesh(false)
	
	var neighbors = [
		pos + Vector3i(1,0,0), pos + Vector3i(-1,0,0),
		pos + Vector3i(0,1,0), pos + Vector3i(0,-1,0),
		pos + Vector3i(0,0,1), pos + Vector3i(0,0,-1)
	]
	for n_pos in neighbors:
		if loaded_chunks.has(n_pos):
			var n_chunk = loaded_chunks[n_pos]
			if is_instance_valid(n_chunk.body):
				n_chunk.update_mesh(false)

func get_global_block(global_pos: Vector3i) -> int:
	var chunk_pos = Vector3i(
		floor(float(global_pos.x) / 16),
		floor(float(global_pos.y) / 16),
		floor(float(global_pos.z) / 16)
	)
	if loaded_chunks.has(chunk_pos):
		var local_x = posmod(global_pos.x, 16)
		var local_y = posmod(global_pos.y, 16)
		var local_z = posmod(global_pos.z, 16)
		return loaded_chunks[chunk_pos].data[local_x + (local_z * 16) + (local_y * 256)]
	return 0

func modify_block(global_pos: Vector3i, new_type: int):
	var chunk_pos = Vector3i(
		floor(float(global_pos.x) / 16),
		floor(float(global_pos.y) / 16),
		floor(float(global_pos.z) / 16)
	)
	if loaded_chunks.has(chunk_pos):
		var local_x = posmod(global_pos.x, 16)
		var local_y = posmod(global_pos.y, 16)
		var local_z = posmod(global_pos.z, 16)
		
		var chunk_ref = loaded_chunks[chunk_pos]
		var idx = local_x + (local_z * 16) + (local_y * 256)
		
		chunk_ref.data[idx] = new_type
		
		# FIX: Force high priority update so player modifications happen instantly
		chunk_ref.update_mesh(true)
		
		if local_x == 0: update_neighbor_mesh(chunk_pos + Vector3i(-1,0,0))
		if local_x == 15: update_neighbor_mesh(chunk_pos + Vector3i(1,0,0))
		if local_y == 0: update_neighbor_mesh(chunk_pos + Vector3i(0,-1,0))
		if local_y == 15: update_neighbor_mesh(chunk_pos + Vector3i(0,1,0))
		if local_z == 0: update_neighbor_mesh(chunk_pos + Vector3i(0,0,-1))
		if local_z == 15: update_neighbor_mesh(chunk_pos + Vector3i(0,0,1))

func update_neighbor_mesh(pos: Vector3i):
	# FIX: Neighbor updates triggered by block placement are also treated as high priority
	if loaded_chunks.has(pos): loaded_chunks[pos].update_mesh(true)
