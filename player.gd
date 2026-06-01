extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 5.5
const MOUSE_SENSITIVITY = 0.002
const REACH_DISTANCE = 5.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var camera = $Camera3D
var raycast: RayCast3D
@onready var world = get_node("/root/World")

var world_ready = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	raycast = RayCast3D.new()
	raycast.target_position = Vector3(0, 0, -REACH_DISTANCE)
	camera.add_child(raycast)
	
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center_container)
	var crosshair = ColorRect.new()
	crosshair.custom_minimum_size = Vector2(4, 4)
	crosshair.color = Color.WHITE
	center_container.add_child(crosshair)

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and world_ready:
		if event.is_action_pressed("click_left"):
			handle_block_interaction(true)
		elif event.is_action_pressed("click_right"):
			handle_block_interaction(false)

func handle_block_interaction(is_mining: bool):
	if raycast.is_colliding():
		var hit_point = raycast.get_collision_point()
		var hit_normal = raycast.get_collision_normal()
		
		var target_pos = hit_point - (hit_normal * 0.1) if is_mining else hit_point + (hit_normal * 0.1)
		var block_grid_pos = Vector3i(floor(target_pos.x), floor(target_pos.y), floor(target_pos.z))
		
		if is_mining:
			world.modify_block(block_grid_pos, BlockDB.get_int_id("air"))
		else:
			# Precise AABB overlap validation to disable block building inside yourself
			var player_aabb = AABB(global_position - Vector3(0.4, 0.0, 0.4), Vector3(0.8, 1.8, 0.8))
			var block_aabb = AABB(Vector3(block_grid_pos), Vector3(1.0, 1.0, 1.0))
			
			if player_aabb.intersects(block_aabb):
				return 
						
			world.modify_block(block_grid_pos, BlockDB.get_int_id("grass"))

func _physics_process(delta):
	if not world_ready:
		var check_pos = Vector3i(floor(global_position.x), floor(global_position.y - 2.0), floor(global_position.z))
		var chunk_pos = Vector3i(floor(float(check_pos.x)/16), floor(float(check_pos.y)/16), floor(float(check_pos.z)/16))
		
		if world.loaded_chunks.has(chunk_pos):
			world_ready = true
		else:
			velocity = Vector3.ZERO
			return

	# Void safeguard limit adjusted to match the bottom limit (-100 blocks)
	if global_position.y < -105:
		global_position = Vector3(8, 20, 8)
		velocity = Vector3.ZERO

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
