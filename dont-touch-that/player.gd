extends CharacterBody3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_speed: float = 5.0
var last_w_press_time: float = 0.0
var is_fast_walking: bool = false

var camera: Camera3D
var interact_ray: RayCast3D

func _ready():
	# Generate CollisionShape3D if missing
	var collision = null
	for child in get_children():
		if child is CollisionShape3D:
			collision = child
			break
	if not collision:
		collision = CollisionShape3D.new()
		var shape = CapsuleShape3D.new()
		collision.shape = shape
		add_child(collision)
		collision.position.y = 1.0 # Lift half capsule height

	# Generate Camera3D if missing
	camera = null
	for child in get_children():
		if child is Camera3D:
			camera = child
			camera.current = true
			break
	if not camera:
		camera = Camera3D.new()
		add_child(camera)
		camera.position.y = 1.5 # Eye level
		camera.current = true

	# Generate RayCast3D
	interact_ray = RayCast3D.new()
	interact_ray.target_position = Vector3(0, 0, -4.0)
	camera.add_child(interact_ray)

	# Auto-map InputMap
	var add_action_key = func(action: String, keycode: Key):
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key = InputEventKey.new()
			key.keycode = keycode
			InputMap.action_add_event(action, key)

	add_action_key.call("move_forward", KEY_W)
	add_action_key.call("move_backward", KEY_S)
	add_action_key.call("move_left", KEY_A)
	add_action_key.call("move_right", KEY_D)
	add_action_key.call("run", KEY_SHIFT)
	add_action_key.call("interact", KEY_E)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	global_position = Vector3(18.0, 8.0, 55.0)

	var settings_menu = load("res://graphics_menu.gd").new()
	get_tree().current_scene.call_deferred("add_child", settings_menu)

	for child in get_tree().current_scene.get_children():
		if child is DirectionalLight3D or child is OmniLight3D:
			child.add_to_group("lights")

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_sensitivity: float = 0.002
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		
	if event.is_action_pressed("interact"):
		if interact_ray.is_colliding():
			var target = interact_ray.get_collider()
			if target.is_in_group("interactable") and target.has_method("interact"):
				target.interact()
				
	if event.is_action_pressed("move_forward"):
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_w_press_time < 0.3:
			is_fast_walking = true
		last_w_press_time = current_time
	elif event.is_action_released("move_forward"):
		is_fast_walking = false
		
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_pressed("run"):
		current_speed = 14.0
	elif is_fast_walking:
		current_speed = 8.5
	else:
		current_speed = 5.0

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
