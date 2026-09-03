@tool
extends Node3D

# Procedural Apartment Building Generator
# Yard: 120 ft x 45 ft -> (36.58m length x 13.72m width)
# House Footprint: 60 ft x 24 ft -> (18.29m length x 7.32m width)
# Floor Heights: 3.0m per story

@export var rebuild: bool = false:
	set(val):
		if val:
			generate_layout()

const FT_TO_M = 0.3048

# Helper to convert feet to meters
func ft(val: float) -> float:
	return val * FT_TO_M

# Local coordinate conversions (centered at house Y=30, X=12)
func get_x(x_ft: float) -> float:
	return (x_ft - 12.0) * FT_TO_M

func get_z(y_ft: float) -> float:
	return (y_ft - 30.0) * FT_TO_M

func _ready():
	generate_layout()

func generate_layout():
	# Clear existing children except Camera3D and WorldEnvironment
	for child in get_children():
		if child.name != "Camera3D" and child.name != "WorldEnvironment":
			child.queue_free()
			remove_child(child)
	
	# Setup Camera3D and DirectionalLight3D if they exist
	var camera = get_node_or_null("Camera3D")
	if camera:
		camera.position = Vector3(0, 15, 25)
		camera.look_at(Vector3(0, 2.5, 0), Vector3.UP)
		
		var light = camera.get_node_or_null("DirectionalLight3D")
		if light:
			light.global_rotation_degrees = Vector3(-45, 45, 0)
			light.light_energy = 1.0
			light.shadow_enabled = true
			
	# Setup WorldEnvironment
	var env = get_node_or_null("WorldEnvironment")
	if not env:
		env = WorldEnvironment.new()
		env.name = "WorldEnvironment"
		add_child(env)
	
	var env_res = Environment.new()
	env_res.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky.sky_material = sky_material
	env_res.sky = sky
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	env.environment = env_res

	# Create yard floor
	var yard = CSGBox3D.new()
	yard.name = "Yard"
	yard.use_collision = true
	yard.size = Vector3(13.72, 0.2, 36.58)
	yard.position = Vector3(0, -0.1, 0)
	
	# Grass-like material
	var yard_mat = StandardMaterial3D.new()
	yard_mat.albedo_color = Color(0.15, 0.35, 0.15)
	yard.material = yard_mat
	add_child(yard)
	
	# CSG Combiner for the building to handle cutouts
	var house_combiner = CSGCombiner3D.new()
	house_combiner.name = "HouseStructure"
	house_combiner.use_collision = true
	add_child(house_combiner)
	
	# Floor plates (1st floor, 2nd floor, roof) - exactly 60 ft long
	var floor1_plate = CSGBox3D.new()
	floor1_plate.name = "Floor1_Plate"
	floor1_plate.size = Vector3(ft(24), 0.2, ft(60))
	floor1_plate.position = Vector3(0, 0.1, 0) # Centered
	floor1_plate.material = get_wood_material()
	house_combiner.add_child(floor1_plate)
	
	var floor2_plate = CSGBox3D.new()
	floor2_plate.name = "Floor2_Plate"
	floor2_plate.size = Vector3(ft(24), 0.2, ft(60))
	floor2_plate.position = Vector3(0, 3.0, 0)
	floor2_plate.material = get_wood_material()
	house_combiner.add_child(floor2_plate)
	
	var roof_plate = CSGBox3D.new()
	roof_plate.name = "Roof_Plate"
	roof_plate.size = Vector3(ft(24), 0.2, ft(60))
	roof_plate.position = Vector3(0, 6.0, 0)
	roof_plate.material = get_roof_material()
	house_combiner.add_child(roof_plate)

	# --- WALL SHAPES (ADDITIONS) ---
	var wall_material = get_wall_material()
	
	# Floor 1 Walls (0 to 60 ft scale)
	# Exterior
	add_wall_ft(0, 10, 0, 60, 0.1, 3.0, 0.2, house_combiner, wall_material) # Left
	add_wall_ft(24, 10, 24, 60, 0.1, 3.0, 0.2, house_combiner, wall_material) # Right
	add_wall_ft(0, 10, 24, 10, 0.1, 3.0, 0.2, house_combiner, wall_material) # Back outer
	add_wall_ft(0, 60, 24, 60, 0.1, 3.0, 0.2, house_combiner, wall_material) # Front outer
	
	# 1st Floor Interior
	add_wall_ft(0, 26, 16, 26, 0.1, 3.0, 0.15, house_combiner, wall_material)
	add_wall_ft(0, 30, 24, 30, 0.1, 3.0, 0.15, house_combiner, wall_material)
	add_wall_ft(12, 10, 12, 46, 0.1, 3.0, 0.15, house_combiner, wall_material)
	add_wall_ft(12, 20, 18, 20, 0.1, 3.0, 0.15, house_combiner, wall_material)
	add_wall_ft(18, 10, 18, 22, 0.1, 3.0, 0.15, house_combiner, wall_material)
	add_wall_ft(18, 22, 24, 22, 0.1, 3.0, 0.15, house_combiner, wall_material)
	add_wall_ft(12, 38, 24, 38, 0.1, 3.0, 0.15, house_combiner, wall_material)
	add_wall_ft(4, 46, 24, 46, 0.1, 3.0, 0.15, house_combiner, wall_material)
	add_wall_ft(4, 30, 4, 60, 0.1, 3.0, 0.15, house_combiner, wall_material)
	add_wall_ft(18, 46, 18, 60, 0.1, 3.0, 0.15, house_combiner, wall_material)
	add_wall_ft(18, 52, 24, 52, 0.1, 3.0, 0.15, house_combiner, wall_material)
	
	# 1st Floor Back Porch Railing / Half Wall
	add_wall_ft(0, 0, 0, 10, 0.1, 1.2, 0.2, house_combiner, wall_material)
	add_wall_ft(0, 0, 24, 0, 0.1, 1.2, 0.2, house_combiner, wall_material)
	add_wall_ft(24, 0, 24, 10, 0.1, 1.2, 0.2, house_combiner, wall_material)

	# Floor 2 Walls (0 to 60 ft scale)
	# Exterior
	add_wall_ft(0, 8, 0, 60, 3.1, 6.0, 0.2, house_combiner, wall_material)
	add_wall_ft(24, 8, 24, 60, 3.1, 6.0, 0.2, house_combiner, wall_material)
	add_wall_ft(0, 8, 24, 8, 3.1, 6.0, 0.2, house_combiner, wall_material)
	add_wall_ft(0, 60, 24, 60, 3.1, 6.0, 0.2, house_combiner, wall_material)
	
	# 2nd Floor Interior
	add_wall_ft(12, 8, 12, 36, 3.1, 6.0, 0.15, house_combiner, wall_material)
	add_wall_ft(0, 20, 12, 20, 3.1, 6.0, 0.15, house_combiner, wall_material)
	add_wall_ft(0, 36, 24, 36, 3.1, 6.0, 0.15, house_combiner, wall_material)
	add_wall_ft(0, 52, 24, 52, 3.1, 6.0, 0.15, house_combiner, wall_material)
	add_wall_ft(4, 52, 4, 60, 3.1, 6.0, 0.15, house_combiner, wall_material)
	add_wall_ft(20, 52, 20, 60, 3.1, 6.0, 0.15, house_combiner, wall_material)
	add_wall_ft(20, 56, 24, 56, 3.1, 6.0, 0.15, house_combiner, wall_material)
	add_wall_ft(4, 56, 20, 56, 3.1, 6.0, 0.15, house_combiner, wall_material)
	
	# 2nd Floor Back Porch Railing / Half Wall
	add_wall_ft(4, 0, 4, 8, 3.1, 4.2, 0.2, house_combiner, wall_material)
	add_wall_ft(4, 0, 24, 0, 3.1, 4.2, 0.2, house_combiner, wall_material)
	add_wall_ft(24, 0, 24, 8, 3.1, 4.2, 0.2, house_combiner, wall_material)

	# --- CUTOUTS (SUBTRACTIONS) ---
	# Doors
	# Floor 1
	add_door_ft(12, 0, 0.0, true, house_combiner) # Back porch outer
	add_door_ft(12, 10, 0.1, true, house_combiner) # House back wall
	add_door_ft(15, 20, 0.1, true, house_combiner) # Bathroom
	add_door_ft(20, 22, 0.1, true, house_combiner) # Closet D
	add_door_ft(20, 30, 0.1, true, house_combiner) # Kitchen
	add_door_ft(12, 44, 0.1, false, house_combiner) # Bedroom A
	add_door_ft(14, 46, 0.1, true, house_combiner) # Dining
	add_door_ft(20, 46, 0.1, true, house_combiner) # Front Porch inner
	
	# Floor 2
	add_door_ft(12, 8, 3.1, true, house_combiner) # House back wall
	add_door_ft(12, 12, 3.1, false, house_combiner) # Bathroom
	add_door_ft(8, 36, 3.1, true, house_combiner) # Bedroom B
	add_door_ft(14, 36, 3.1, true, house_combiner) # Kitchen/Dining
	add_door_ft(8, 52, 3.1, true, house_combiner) # Bedroom A
	add_door_ft(20, 52, 3.1, true, house_combiner) # Front Porch
	add_door_ft(4, 50, 3.1, false, house_combiner) # Stairwell

	# Windows
	# Floor 1
	add_window_ft(4, 0, 0.0, true, house_combiner)
	add_window_ft(24, 5, 0.1, false, house_combiner)
	add_window_ft(0, 18, 0.1, false, house_combiner)
	add_window_ft(0, 38, 0.1, false, house_combiner)
	add_window_ft(0, 44, 0.1, false, house_combiner)
	add_window_ft(8, 60, 0.1, true, house_combiner)
	add_window_ft(14, 60, 0.1, true, house_combiner)
	add_window_ft(24, 15, 0.1, false, house_combiner)
	add_window_ft(24, 22, 0.1, false, house_combiner)
	add_window_ft(24, 29, 0.1, false, house_combiner)
	add_window_ft(24, 35, 0.1, false, house_combiner)
	add_window_ft(24, 42, 0.1, false, house_combiner)
	add_window_ft(24, 48, 0.1, false, house_combiner)
	
	# Floor 2
	add_window_ft(8, 0, 3.1, true, house_combiner)
	add_window_ft(12, 0, 3.1, true, house_combiner)
	add_window_ft(18, 0, 3.1, true, house_combiner)
	add_window_ft(0, 14, 3.1, false, house_combiner)
	add_window_ft(0, 28, 3.1, false, house_combiner)
	add_window_ft(0, 44, 3.1, false, house_combiner)
	add_window_ft(8, 60, 3.1, true, house_combiner)
	add_window_ft(14, 60, 3.1, true, house_combiner)
	add_window_ft(24, 14, 3.1, false, house_combiner)
	add_window_ft(24, 22, 3.1, false, house_combiner)
	add_window_ft(24, 30, 3.1, false, house_combiner)
	add_window_ft(24, 38, 3.1, false, house_combiner)
	add_window_ft(24, 46, 3.1, false, house_combiner)

	# --- STAIRCASES ---
	# Back stairs (top-left, Y=0 to Y=10, X=0 to X=4)
	build_stairs_ft(0, 0, 4, 10, 0.1, 3.1, 15, house_combiner)
	
	# Front stairs (bottom-left, Y=46 to Y=60, X=0 to X=4)
	build_stairs_ft(0, 46, 4, 60, 0.1, 3.1, 15, house_combiner)

# Helper to add wall
func add_wall_ft(x1_ft: float, z1_ft: float, x2_ft: float, z2_ft: float, y_bottom: float, y_top: float, thickness_m: float, parent: Node, material: Material):
	var w = CSGBox3D.new()
	w.use_collision = true
	w.material = material
	
	var x1 = get_x(x1_ft)
	var z1 = get_z(z1_ft)
	var x2 = get_x(x2_ft)
	var z2 = get_z(z2_ft)
	
	var dx = abs(x2 - x1)
	var dz = abs(z2 - z1)
	var dy = y_top - y_bottom
	
	if dx < 0.01: # Vertical wall (aligned with Z-axis)
		w.size = Vector3(thickness_m, dy, dz)
		w.position = Vector3(x1, y_bottom + dy/2.0, (z1 + z2)/2.0)
	elif dz < 0.01: # Horizontal wall (aligned with X-axis)
		w.size = Vector3(dx, dy, thickness_m)
		w.position = Vector3((x1 + x2)/2.0, y_bottom + dy/2.0, z1)
	else:
		w.size = Vector3(dx, dy, dz)
		w.position = Vector3((x1 + x2)/2.0, y_bottom + dy/2.0, (z1 + z2)/2.0)
		
	parent.add_child(w)

# Helper to add door cutout
func add_door_ft(x_ft: float, z_ft: float, y_bottom: float, is_horiz: bool, parent: Node):
	var door = CSGBox3D.new()
	door.operation = CSGShape3D.OPERATION_SUBTRACTION
	door.size = Vector3(0.9, 2.1, 0.5) if is_horiz else Vector3(0.5, 2.1, 0.9)
	door.position = Vector3(get_x(x_ft), y_bottom + 1.05, get_z(z_ft))
	parent.add_child(door)

# Helper to add window cutout
func add_window_ft(x_ft: float, z_ft: float, y_bottom: float, is_horiz: bool, parent: Node):
	var win = CSGBox3D.new()
	win.operation = CSGShape3D.OPERATION_SUBTRACTION
	win.size = Vector3(1.0, 1.2, 0.5) if is_horiz else Vector3(0.5, 1.2, 1.0)
	win.position = Vector3(get_x(x_ft), y_bottom + 0.9 + 0.6, get_z(z_ft))
	parent.add_child(win)

# Helper to build stairs
func build_stairs_ft(x1_ft: float, z1_ft: float, x2_ft: float, z2_ft: float, y_start: float, y_end: float, num_steps: int, parent: Node):
	var x1 = get_x(x1_ft)
	var z1 = get_z(z1_ft)
	var x2 = get_x(x2_ft)
	var z2 = get_z(z2_ft)
	
	var step_width = abs(x2 - x1)
	var total_run = abs(z2 - z1)
	var step_depth = total_run / num_steps
	var step_height = (y_end - y_start) / num_steps
	
	for i in range(num_steps):
		var step = CSGBox3D.new()
		step.use_collision = true
		step.size = Vector3(step_width, step_height * (i + 1), step_depth)
		
		# Direction logic (rising from front to back or back to front)
		var current_z = z2 - step_depth * i - step_depth / 2.0 if z1 < z2 else z2 + step_depth * i + step_depth / 2.0
		step.position = Vector3(
			(x1 + x2) / 2.0,
			y_start + (step_height * (i + 1)) / 2.0,
			current_z
		)
		step.material = get_wood_material()
		parent.add_child(step)

# Materials
func get_wall_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.8)
	return mat

func get_wood_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.2)
	return mat

func get_roof_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.25)
	return mat
