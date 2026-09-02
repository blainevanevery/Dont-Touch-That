@tool
extends MeshInstance3D

var mat_hardwood: StandardMaterial3D
var mat_siding: StandardMaterial3D
var mat_drywall: StandardMaterial3D

func _ready():
	print("=== STEP 3 PIPELINE: FINALIZING STAIRS, RAILINGS, AND CUBBY ===")
	build_first_floor()
	install_doors()

func create_pbr_material(albedo_path: String, normal_path: String, roughness_path: String, tint: Color, uv_scale: Vector3) -> StandardMaterial3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = tint
		
		if albedo_path != "" and ResourceLoader.exists(albedo_path):
			mat.albedo_enables = load(albedo_path)
		
		if normal_path != "" and ResourceLoader.exists(normal_path):
			mat.normal_enabled = true
			mat.normal_texture = load(normal_path)
		if roughness_path != "" and ResourceLoader.exists(roughness_path):
			mat.roughness_enabled = true 
			mat.roughness_texture = load(roughness_path)

		mat.uv1_triplanar = true
		mat.uv1_scale = uv_scale
		mat.uv1_triplaner_sharpness = 10.0
		return mat

func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, _expected_normal: Vector3, mat: StandardMaterial3D):
	st.set_material(mat)
	
	# Explicit mathematical normal calculation
	st.set_smooth_group(0)
	var face_normal = (b - a).cross(c - a).normalized()
	st.set_normal(face_normal)

	# Triangle 1: a -> c -> b (Reversed Winding)
	st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(1, 1)); st.add_vertex(c)
	st.set_uv(Vector2(1, 0)); st.add_vertex(b)

	# Triangle 2: a -> d -> c (Reversed Winding)
	st.set_normal(face_normal)
	st.set_uv(Vector2(0, 0)); st.add_vertex(a)
	st.set_uv(Vector2(0, 1)); st.add_vertex(d)
	st.set_uv(Vector2(1, 1)); st.add_vertex(c)


func add_spindle_railing_x(st, x1, x2, z, y_base, height, mats):
	add_box(st, x1, x2, y_base + 0.2, y_base + 0.35, z - 0.1, z + 0.1, mats)
	add_box(st, x1, x2, y_base + height - 0.15, y_base + height, z - 0.1, z + 0.1, mats)
	var count = int(abs(x2 - x1) / 0.4)
	for i in range(count + 1):
		var sx = minf(x1, x2) + (i * 0.4)
		add_box(st, sx - 0.06, sx + 0.06, y_base + 0.35, y_base + height - 0.15, z - 0.06, z + 0.06, mats)

func add_spindle_railing_z(st, z1, z2, x, y_base, height, mats):
	add_box(st, x - 0.1, x + 0.1, y_base + 0.2, y_base + 0.35, z1, z2, mats)
	add_box(st, x - 0.1, x + 0.1, y_base + height - 0.15, y_base + height, z1, z2, mats)
	var count = int(abs(z2 - z1) / 0.4)
	for i in range(count + 1):
		var sz = minf(z1, z2) + (i * 0.4)
		add_box(st, x - 0.06, x + 0.06, y_base + 0.35, y_base + height - 0.15, sz - 0.06, sz + 0.06, mats)
func add_box(st: SurfaceTool, x1: float, x2: float, y1: float, y2: float, z1: float, z2: float, mats: Dictionary):
	var x_min = minf(x1, x2)
	var x_max = maxf(x1, x2)
	var y_bottom = minf(y1, y2)
	var y_top = maxf(y1, y2)
	var z_min = minf(z1, z2)
	var z_max = maxf(z1, z2)

	# Prevent zero-volume boxes (e.g. railing posts can be thin but not zero)
	if is_equal_approx(x_min, x_max) or is_equal_approx(y_bottom, y_top) or is_equal_approx(z_min, z_max):
		return

	var v0 = Vector3(x_min, y_bottom, z_min)
	var v1 = Vector3(x_max, y_bottom, z_min)
	var v2 = Vector3(x_max, y_top,    z_min)
	var v3 = Vector3(x_min, y_top,    z_min)
	var v4 = Vector3(x_min, y_bottom, z_max)
	var v5 = Vector3(x_max, y_bottom, z_max)
	var v6 = Vector3(x_max, y_top,    z_max)
	var v7 = Vector3(x_min, y_top,    z_max)

	var get_mat = func(face: String) -> StandardMaterial3D:
		return mats[face] if mats.has(face) else mats.get("default", mat_drywall)

	add_quad(st, v1, v0, v3, v2, Vector3(0, 0, -1), get_mat.call("south")) # South Face (-Z)
	add_quad(st, v4, v5, v6, v7, Vector3(0, 0, 1), get_mat.call("north"))  # North Face (+Z)
	add_quad(st, v0, v4, v7, v3, Vector3(-1, 0, 0), get_mat.call("west"))  # West Face (-X)
	add_quad(st, v5, v1, v2, v6, Vector3(1, 0, 0), get_mat.call("east"))   # East Face (+X)
	add_quad(st, v7, v6, v2, v3, Vector3(0, 1, 0), get_mat.call("top"))    # Top Face (+Y)
	add_quad(st, v0, v1, v5, v4, Vector3(0, -1, 0), get_mat.call("bottom"))# Bottom Face (-Y)

func add_wall_x(st: SurfaceTool, x1: float, x2: float, z1: float, z2: float, mats: Dictionary):
	add_box(st, x1, x2, 0.0, 9.0, z1, z2, mats)

func add_wall_z(st: SurfaceTool, x1: float, x2: float, z1: float, z2: float, mats: Dictionary):
	add_box(st, x1, x2, 0.0, 9.0, z1, z2, mats)

func add_door_x(st: SurfaceTool, x1: float, x2: float, z1: float, z2: float, y_header: float, mats: Dictionary):
	add_box(st, x1, x2, y_header, 9.0, z1, z2, mats)

func add_door_z(st: SurfaceTool, x1: float, x2: float, z1: float, z2: float, y_header: float, mats: Dictionary):
	add_box(st, x1, x2, y_header, 9.0, z1, z2, mats)

func add_window_x(st: SurfaceTool, x1: float, x2: float, z1: float, z2: float, y_sill: float, y_header: float, mats: Dictionary):
	add_box(st, x1, x2, 0.0, y_sill, z1, z2, mats)
	add_box(st, x1, x2, y_header, 9.0, z1, z2, mats)

func add_window_z(st: SurfaceTool, x1: float, x2: float, z1: float, z2: float, y_sill: float, y_header: float, mats: Dictionary):
	add_box(st, x1, x2, 0.0, y_sill, z1, z2, mats)
	add_box(st, x1, x2, y_header, 9.0, z1, z2, mats)

func build_first_floor():
	for child in get_children():
		child.queue_free()

	mat_hardwood = create_pbr_material("", "", "", Color(0.62, 0.48, 0.35), Vector3(1.0, 1.0, 1.0))
	mat_siding = create_pbr_material("", "", "", Color(0.76, 0.696, 0.522, 1.0), Vector3(1.0, 1.0, 1.0))
	mat_drywall = create_pbr_material("", "", "", Color(0.753, 0.753, 0.705, 1.0), Vector3(1.0, 1.0, 1.0))
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var m_int = {"default": mat_drywall, "top": mat_hardwood}
	var m_floor = {"default": mat_drywall, "top": mat_hardwood}
	var m_ext_front = create_pbr_material("res://textures/horizontal_siding.jpg", "", "", Color(0.92, 0.91, 0.87), Vector3(0.5, 0.2, 0.5))
	var m_deck = create_pbr_material("res://textures/weathered_wood.jpg", "", "", Color(0.76, 0.60, 0.42), Vector3(0.3, 0.3, 0.3))

	# Floor Gap Patch: Make sure there's no overlap
	add_box(st, 11.2, 27.0, -0.5, 0.0, 39.0, 110.0, m_floor) # Main right
	add_box(st, 0.0, 11.2, -0.5, 0.0, 45.6, 110.0, m_floor) # Front section
	add_box(st, 0.0, 11.2, -0.5, 0.0, 39.0, 39.5, m_floor) # Rear strip
	
	# Back Deck
	add_box(st, 9.5, 22.0, -0.5, 0.0, 34.0, 39.0, m_deck)

	# --- FRONT PORCH LANDING (Z: 110.0 to 114.0) ---
	
	# --- FRONT ENTRY SOLID STEPS DOWN TO GRADE (Y: 0.0 down to -3.5) ---
	var step_count = 5
	for i in range(step_count):
			var z_start = 109.5 + (i * 0.91)
			var z_end = z_start + 0.91
			var y_top = -(i + 1) * 0.6
			var y_bottom = -3.5
			add_box(st, 1.0, 7.0, y_bottom, y_top, z_start, z_end, m_deck)

	# --- BACK PORCH STEPS DOWN TO GRADE (EXITING RIGHT) ---var back_step_count = 5
	var back_step_count = 5 
	for i in range(back_step_count):
			var x_start = 22.0 + (i * 1.0)
			var x_end = x_start + 1.0
			var y_top = -(i + 1) * 0.7
			var y_bottom = y_top - 0.1
			add_box(st, x_start, x_end, y_bottom, y_top, 34.0, 39.0, m_deck)

	# --- FRONT PORCH RAILINGS ---
	add_spindle_railing_z(st, 110.0, 114.0, 1.1, 0.0, 3.0, m_deck)
	add_spindle_railing_z(st, 110.0, 114.0, 6.9, 0.0, 3.0, m_deck)

	# --- L-SHAPED BACK DECK SPINDLE RAILINGS ---
	# Left side of deck
	add_spindle_railing_z(st, 34.0, 39.0, 9.6, 0.0, 3.0, m_deck)
	# Front side of deck (facing the backyard)
	add_spindle_railing_x(st, 9.5, 22.0, 34.1, 0.0, 3.0, m_deck)

	# Raised Awning above Front Door
	add_box(st, 0.0, 8.0, 7.0, 7.8, 110.0, 114.0, m_ext_front)

	# 2. SOLID EXTERIOR SHELL (Y: 0.0 to 9.0)
	var ext_left_mats = {"default": mat_drywall, "west": mat_siding}
	var ext_rear_mats = {"default": mat_drywall, "south": mat_siding}
	var ext_right_mats = {"default": mat_drywall, "east": mat_siding}

	# --- Left Wall ---
	add_wall_z(st, 0.0, 0.5, 39.0, 63.0, ext_left_mats)
	add_window_z(st, 0.0, 0.5, 63.0, 66.0, 3.0, 6.5, ext_left_mats)
	add_wall_z(st, 0.0, 0.5, 66.0, 83.0, ext_left_mats)
	add_window_z(st, 0.0, 0.5, 83.0, 86.0, 3.0, 6.5, ext_left_mats)
	add_wall_z(st, 0.0, 0.5, 86.0, 89.0, ext_left_mats)
	add_window_z(st, 0.0, 0.5, 89.0, 92.0, 3.0, 6.5, ext_left_mats)
	add_wall_z(st, 0.0, 0.5, 92.0, 110.0, ext_left_mats)

	# --- Rear Exterior Wall ---
	add_wall_x(st, 0.5, 12.5, 39.0, 39.5, ext_rear_mats)
	add_door_x(st, 12.5, 15.5, 39.0, 39.5, 7.0, ext_rear_mats)
	add_wall_x(st, 15.5, 16.5, 39.0, 39.5, ext_rear_mats)
	add_window_x(st, 16.5, 19.5, 39.0, 39.5, 3.0, 6.5, ext_rear_mats)
	add_wall_x(st, 19.5, 27.0, 39.0, 39.5, ext_rear_mats)

	# --- Right Wall ---
	add_wall_z(st, 26.5, 27.0, 39.5, 42.0, ext_right_mats)
	add_window_z(st, 26.5, 27.0, 42.0, 45.0, 3.0, 6.5, ext_right_mats)
	add_wall_z(st, 26.5, 27.0, 45.0, 47.0, ext_right_mats)
	add_window_z(st, 26.5, 27.0, 47.0, 50.0, 3.0, 6.5, ext_right_mats)
	add_wall_z(st, 26.5, 27.0, 50.0, 64.0, ext_right_mats)
	add_window_z(st, 26.5, 27.0, 64.0, 67.5, 3.0, 6.5, ext_right_mats)
	add_wall_z(st, 26.5, 27.0, 67.5, 81.0, ext_right_mats)
	add_window_z(st, 26.5, 27.0, 81.0, 84.0, 3.0, 6.5, ext_right_mats)
	add_wall_z(st, 26.5, 27.0, 84.0, 88.0, ext_right_mats)
	add_window_z(st, 26.5, 27.0, 88.0, 91.0, 3.0, 6.5, ext_right_mats)
	add_wall_z(st, 26.5, 27.0, 91.0, 94.0, ext_right_mats)

	# --- Inset Porch Back Wall ---
	add_wall_x(st, 18.0, 20.5, 93.5, 94.0, ext_rear_mats)
	add_door_x(st, 20.5, 23.5, 93.5, 94.0, 7.0, ext_rear_mats)
	add_wall_x(st, 23.5, 26.5, 93.5, 94.0, ext_rear_mats)

	# --- Inset Porch Left Wall ---
	add_wall_z(st, 18.0, 18.5, 94.0, 109.5, ext_right_mats)

	# --- Front Wall ---
	add_wall_x(st, 0.5, 1.5, 109.5, 110.0, m_ext_front)
	add_door_x(st, 1.5, 4.5, 109.5, 110.0, 7.0, m_ext_front)
	add_wall_x(st, 4.5, 7.5, 109.5, 110.0, m_ext_front)
	add_window_x(st, 7.5, 11.0, 109.5, 110.0, 3.0, 6.5, m_ext_front)
	add_wall_x(st, 11.0, 13.0, 109.5, 110.0, m_ext_front)
	add_window_x(st, 13.0, 16.5, 109.5, 110.0, 3.0, 6.5, m_ext_front)
	add_wall_x(st, 16.5, 18.5, 109.5, 110.0, m_ext_front)
	
	# --- Porch Corner Support Columns ---
	var column_mats = {"default": mat_siding}
	add_box(st, 26.3, 27.0, 0.0, 9.0, 109.3, 110.0, column_mats)
	add_box(st, 26.3, 27.0, 0.0, 9.0, 101.7, 102.3, column_mats)
	add_box(st, 26.3, 27.0, 0.0, 9.0, 94.2, 94.8, column_mats)

	# 3. STAIRS & PARTITION WALLS (Thickness = 0.4 ft)
	add_wall_x(st, 0.5, 11.2, 45.2, 45.6, m_int) # Side wall
	add_door_z(st, 10.8, 11.2, 39.5, 42.3, 7.0, m_int) # Entrance
	add_wall_z(st, 10.8, 11.2, 42.3, 42.7, m_int)
	
	# UNDER-STAIR CUBBY FIX: Removed the lower support box under the upper flight 
	# leaving the top open to create the cubby space below.
	
	add_wall_x(st, 4.5, 10.8, 42.3, 42.7, m_int)
	add_box(st, 0.5, 4.5, 0.0, 4.55, 39.5, 45.2, m_int)
	
	# --- Bath / Closet D / Nook Cluster ---
	add_wall_x(st, 0.5, 16.5, 48.6, 49.0, m_int)
	add_wall_z(st, 16.1, 16.5, 49.0, 59.6, m_int)
	add_wall_z(st, 20.6, 21.0, 53.5, 59.6, m_int)

	add_wall_x(st, 16.5, 22.5, 53.1, 53.5, m_int)
	add_door_x(st, 22.5, 25.5, 53.1, 53.5, 7.0, m_int)
	add_wall_x(st, 25.5, 26.5, 53.1, 53.5, m_int)

	# North Core Wall
	add_wall_x(st, 0.5, 11.6, 59.6, 60.0, m_int)
	add_wall_x(st, 11.6, 12.0, 59.6, 60.0, m_int)
	add_door_x(st, 12.0, 15.0, 59.6, 60.0, 7.0, m_int)
	add_wall_x(st, 15.0, 17.5, 59.6, 60.0, m_int)
	add_door_x(st, 17.5, 20.5, 59.6, 60.0, 7.0, m_int)
	add_wall_x(st, 20.5, 21.0, 59.6, 60.0, m_int)

	# --- ALIGNED CENTRAL SPINE PARTITION ---
	add_wall_z(st, 11.6, 12.0, 60.0, 61.5, m_int)
	add_door_z(st, 11.6, 12.0, 61.5, 64.5, 7.0, m_int)
	add_wall_z(st, 11.6, 12.0, 64.5, 89.5, m_int)
	add_door_z(st, 11.6, 12.0, 89.5, 92.5, 7.0, m_int)
	add_wall_z(st, 11.6, 12.0, 92.5, 93.6, m_int)

	# --- RESTORED SOUTH/BACK WALL OF BEDROOM B & CLOSETS ---
	add_wall_x(st, 0.5, 6.5, 68.6, 69.0, m_int)
	add_door_x(st, 6.5, 9.5, 68.6, 69.0, 7.0, m_int)
	add_wall_x(st, 9.5, 11.6, 68.6, 69.0, m_int)
	add_wall_z(st, 5.4, 5.8, 69.0, 71.1, m_int)

	add_wall_x(st, 0.5, 1.5, 71.1, 71.5, m_int)
	add_door_x(st, 1.5, 4.5, 71.1, 71.5, 7.0, m_int)
	add_wall_x(st, 4.5, 11.6, 71.1, 71.5, m_int)

	# --- KITCHEN-TO-LIVING CROSS-WALL ONLY ON RIGHT SIDE ---
	add_wall_x(st, 12.0, 21.0, 74.1, 74.5, m_int)
	add_door_x(st, 21.0, 25.5, 74.1, 74.5, 7.0, m_int)
	add_wall_x(st, 25.5, 26.5, 74.1, 74.5, m_int)

	# --- Front Cross Partition ---
	add_wall_x(st, 0.5, 11.6, 93.6, 94.0, m_int)
	add_door_x(st, 12.5, 16.0, 93.6, 94.0, 7.0, m_int)
	add_wall_x(st, 11.6, 12.5, 93.6, 94.0, m_int)
	add_wall_x(st, 16.0, 18.0, 93.6, 94.0, m_int)

	# --- Front-Left Stair Wall ---
	add_wall_z(st, 6.6, 7.0, 94.0, 109.5, m_int)

	# 4. GROUNDED STAIRCASE GEOMETRY
	var stair_mats = {"default": mat_hardwood}
	# --- Rear U-Turn Switchback Staircase ---
	const FLIGHT1_STEPS := 6
	for s in range(FLIGHT1_STEPS):
		var ts = float(s) / float(FLIGHT1_STEPS - 1)
		# STAIR SHADING FIX: Ensure positive widths
		var sx_max = lerpf(11.2, 4.5, ts)
		var sx_min = sx_max - 0.7
		var sy = lerpf(0.0, 4.55, ts)
		add_box(st, sx_min, sx_max, 0.0, sy, 39.5, 42.3, stair_mats)

	add_box(st, 0.5, 4.5, 0.0, 4.55, 39.5, 45.6, stair_mats)

	const FLIGHT2_STEPS := 6
	for s in range(FLIGHT2_STEPS):
		var ts = float(s) / float(FLIGHT2_STEPS - 1)
		# STAIR SHADING FIX: Ensure positive widths
		var sx_min = lerpf(4.5, 11.2, ts)
		var sx_max = sx_min + 0.7
		var sy = lerpf(4.55, 9.0, ts)
		add_box(st, sx_min, sx_max, 4.55, sy, 42.7, 45.6, stair_mats)

	# --- Flipped Front Staircase ---
	const FRONT_STEPS := 10
	for s in range(FRONT_STEPS):
		var ts = float(s) / float(FRONT_STEPS - 1)
		# STAIR SHADING FIX: Ensure positive depths
		var sz_max = lerpf(109.0, 94.5, ts)
		var sz_min = sz_max - 0.8
		var sy = lerpf(0.0, 9.0, ts)
		add_box(st, 0.8, 6.2, 0.0, sy, sz_min, sz_max, stair_mats)

	st.index()
	
	self.mesh = st.commit()
	self.create_trimesh_collision()
	self.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# Raise entire first floor mesh up by 3 feet
	self.position.y = 3.0

func install_doors():
	if Engine.is_editor_hint(): return
	var door_script = load("res://interactive_door.gd")
	if not door_script: return
	
	var doors = [
		[1.5, 109.75, 3.0, 0.0, 1.0],   # Front Entrance
		[12.5, 39.25, 3.0, 0.0, 1.0],   # Back Entrance
		[11.0, 39.5, 2.8, 90.0, 1.0],   # Back Stairs (Z-axis wall)
		[12.0, 59.8, 3.0, 0.0, -1.0],   # Bathroom
		[17.5, 59.8, 3.0, 0.0, -1.0],   # Bedroom A
		[22.5, 53.3, 3.0, 0.0, -1.0],   # Bedroom B
		[11.8, 89.5, 3.0, 90.0, -1.0]   # Kitchen to Hallway (Z-axis wall)
	]

	for d in doors:
		var door = StaticBody3D.new()
		door.set_script(door_script)
		door.position = Vector3(d[0], 0.0, d[1])
		door.set("door_width", d[2])
		door.rotation_degrees.y = d[3]
		door.set("hinge_side", d[4])
		add_child(door)
		door.owner = self.owner
