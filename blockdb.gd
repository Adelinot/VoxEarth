extends Node

const ATLAS_COLUMNS: float = 3.0
const ATLAS_ROWS: float = 4.0

# Storage for block configurations
var block_registry = {}
# Bidirectional maps for performance (String ID <-> Integer ID)
var string_to_int = {}
var int_to_string = {}
var _next_int_id = 0

func _ready():
	# 1. Register base system blocks
	register_block("air", 0.0, {})
	
	# 2. Register surface terrain blocks (Row 0)
	register_block("grass", 1.0, {
		"UP": Vector2(1, 0),     # Grass Top
		"DOWN": Vector2(2, 0),   # Dirt
		"DEFAULT": Vector2(0, 0) # Grass Side
	})
	register_block("dirt", 1.0, {"DEFAULT": Vector2(2, 0)})
	
	# 3. Register mid-tier blocks (Row 1)
	register_block("sand", 0.8, {"DEFAULT": Vector2(0, 1)})
	register_block("stone", 3.5, {"DEFAULT": Vector2(1, 1)})
	register_block("coal_ore", 4.0, {"DEFAULT": Vector2(2, 1)})
	
	# 4. Register deep earth precious ores (Row 2)
	register_block("iron_ore", 5.0, {"DEFAULT": Vector2(0, 2)})
	register_block("gold_ore", 5.5, {"DEFAULT": Vector2(1, 2)})
	register_block("diamond_ore", 7.0, {"DEFAULT": Vector2(2, 2)})

# Highly scalable registration wrapper
func register_block(string_id: String, hardness: float, uv_dict: Dictionary):
	var int_id = _next_int_id
	_next_int_id += 1
	
	string_to_int[string_id] = int_id
	int_to_string[int_id] = string_id
	
	block_registry[int_id] = {
		"string_id": string_id,
		"hardness": hardness,
		"uvs": uv_dict
	}

# Quick utility to get numerical ID from string name
func get_int_id(string_id: String) -> int:
	return string_to_int.get(string_id, 0) # Fallback to Air if missing

func get_block_uvs(int_id: int, face: String) -> Array[Vector2]:
	if not block_registry.has(int_id) or int_id == 0:
		return [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
		
	var uv_map = block_registry[int_id]["uvs"]
	var pos = uv_map.get(face, uv_map.get("DEFAULT", Vector2.ZERO))
	
	var u_min = pos.x / ATLAS_COLUMNS
	var u_max = (pos.x + 1.0) / ATLAS_COLUMNS
	var v_min = pos.y / ATLAS_ROWS
	var v_max = (pos.y + 1.0) / ATLAS_ROWS
	
	return [
		Vector2(u_min, v_max),
		Vector2(u_max, v_max),
		Vector2(u_max, v_min),
		Vector2(u_min, v_min)
	]
