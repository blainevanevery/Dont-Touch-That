@tool
extends MeshInstance3D

func _ready():
	print("=== STEP 2 PIPELINE: RAISING BASEMENT WALLS TO EXPOSED FOUNDATION HEIGHT (Y: 2.5) ===")
	build_watertight_basement()

func build_watertight_basement():
	for child in get_children():
		child.queue_free()

	var concrete_mat = StandardMaterial3D.new()
	concrete_mat.albedo_color = Color(0.70, 0.70, 0.68)
	concrete_mat.roughness = 0.7

	var steel_mat = StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.30, 0.32, 0.35)
	steel_mat.metallic = 0.8
	steel_mat.roughness = 0.3

	# 1. 27-FOOT WIDE WATERTIGHT MONOLITHIC BASEMENT MESH (X: 0.0 to 27.0, Z: 39.0 to 110.0)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(concrete_mat)

	var add_quad = func(v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, norm: Vector3):
		st.set_normal(norm)
		st.set_uv(Vector2(0, 0)); st.add_vertex(v0)
		st.set_uv(Vector2(1, 0)); st.add_vertex(v1)
		st.set_uv(Vector2(0, 1)); st.add_vertex(v2)

		st.set_normal(norm)
		st.set_uv(Vector2(1, 0)); st.add_vertex(v1)
		st.set_uv(Vector2(1, 1)); st.add_vertex(v3)
		st.set_uv(Vector2(0, 1)); st.add_vertex(v2)

	# Top Caps (Y = 2.5, raised to meet elevated first floor)
	add_quad.call(Vector3(0.0, 2.5, 110.0), Vector3(27.0, 2.5, 110.0), Vector3(0.0, 2.5, 109.3), Vector3(27.0, 2.5, 109.3), Vector3.UP) # Front Top
	add_quad.call(Vector3(0.0, 2.5, 110.0), Vector3(0.0, 2.5, 39.0), Vector3(0.7, 2.5, 110.0), Vector3(0.7, 2.5, 39.0), Vector3.UP) # Left Top
	add_quad.call(Vector3(26.3, 2.5, 110.0), Vector3(26.3, 2.5, 39.0), Vector3(27.0, 2.5, 110.0), Vector3(27.0, 2.5, 39.0), Vector3.UP) # Right Top
	add_quad.call(Vector3(0.0, 2.5, 39.7), Vector3(27.0, 2.5, 39.7), Vector3(0.0, 2.5, 39.0), Vector3(27.0, 2.5, 39.0), Vector3.UP) # Full Rear Top Cap (X: 0.0 to 27.0)

	# Exterior Wall Faces (Y: 2.5 to -8.0)
	add_quad.call(Vector3(0.0, 2.5, 110.0), Vector3(27.0, 2.5, 110.0), Vector3(0.0, -8.0, 110.0), Vector3(27.0, -8.0, 110.0), Vector3.FORWARD) # Front Ext
	add_quad.call(Vector3(0.0, 2.5, 39.0), Vector3(0.0, 2.5, 110.0), Vector3(0.0, -8.0, 39.0), Vector3(0.0, -8.0, 110.0), Vector3.LEFT) # Left Ext
	add_quad.call(Vector3(27.0, 2.5, 110.0), Vector3(27.0, 2.5, 39.0), Vector3(27.0, -8.0, 110.0), Vector3(27.0, -8.0, 39.0), Vector3.RIGHT) # Right Ext

	# Full Solid Rear Exterior Wall (Z = 39.0, X: 0.0 to 27.0, Y: 2.5 down to -8.0)
	add_quad.call(Vector3(27.0, 2.5, 39.0), Vector3(0.0, 2.5, 39.0), Vector3(27.0, -8.0, 39.0), Vector3(0.0, -8.0, 39.0), Vector3.BACK)

	# Interior Wall Faces (Y: 2.5 to -7.6)
	add_quad.call(Vector3(26.3, 2.5, 109.3), Vector3(0.7, 2.5, 109.3), Vector3(26.3, -7.6, 109.3), Vector3(0.7, -7.6, 109.3), Vector3.BACK) # Front Int
	add_quad.call(Vector3(0.7, 2.5, 109.3), Vector3(0.7, 2.5, 39.7), Vector3(0.7, -7.6, 109.3), Vector3(0.7, -7.6, 39.7), Vector3.RIGHT) # Left Int
	add_quad.call(Vector3(26.3, 2.5, 39.7), Vector3(26.3, 2.5, 109.3), Vector3(26.3, -7.6, 39.7), Vector3(26.3, -7.6, 109.3), Vector3.LEFT) # Right Int

	# Full Solid Rear Interior Wall (Z = 39.7, X: 0.7 to 26.3, Y: 2.5 down to -7.6, facing +Z / FORWARD into basement)
	add_quad.call(Vector3(26.3, 2.5, 39.7), Vector3(0.7, 2.5, 39.7), Vector3(26.3, -7.6, 39.7), Vector3(0.7, -7.6, 39.7), Vector3.FORWARD)
	# Additional Interior Rear Surface (Z = 39.0, facing +Z / FORWARD for double-sided coverage)
	add_quad.call(Vector3(27.0, 2.5, 39.0), Vector3(0.0, 2.5, 39.0), Vector3(27.0, -7.6, 39.0), Vector3(0.0, -7.6, 39.0), Vector3.FORWARD)

	# Basement Floor Plane (Thickness Y: -7.6 to -8.0)
	add_quad.call(Vector3(0.7, -7.6, 109.3), Vector3(26.3, -7.6, 109.3), Vector3(0.7, -7.6, 39.7), Vector3(26.3, -7.6, 39.7), Vector3.UP) # Inside Floor Top
	add_quad.call(Vector3(0.0, -8.0, 39.0), Vector3(27.0, -8.0, 39.0), Vector3(0.0, -8.0, 110.0), Vector3(27.0, -8.0, 110.0), Vector3.DOWN) # True Bottom Foundation Slab

	# --- CONCRETE BASEMENT EXIT STAIRS (X: 1.0 to 6.0, Z: 31.0 to 39.0) ---
	# Capped to end flush at subfloor level (Y = 0.0)
	var num_steps = 15
	var step_depth = (39.0 - 31.0) / float(num_steps)
	var step_height = (0.0 - (-7.6)) / float(num_steps)
	for i in range(num_steps):
		var z_high = 39.0 - (float(i) * step_depth)
		var z_low = 39.0 - (float(i + 1) * step_depth)
		var y_tread = -7.6 + (float(i + 1) * step_height) # top step reaches Y = 0.0 flush
		var y_riser_bottom = -7.6 + (float(i) * step_height)
		
		# Step Top horizontal tread face (Y = y_tread, Z: z_low to z_high, X: 1.0 to 6.0)
		add_quad.call(Vector3(1.0, y_tread, z_high), Vector3(6.0, y_tread, z_high), Vector3(1.0, y_tread, z_low), Vector3(6.0, y_tread, z_low), Vector3.UP)
		# Step Front vertical riser face (Z = z_low, Y: y_riser_bottom to y_tread, facing -Z / BACK towards grade)
		add_quad.call(Vector3(6.0, y_tread, z_low), Vector3(1.0, y_tread, z_low), Vector3(6.0, y_riser_bottom, z_low), Vector3(1.0, y_riser_bottom, z_low), Vector3.BACK)

	# --- BASEMENT STAIRS SOLID SIDE SUPPORT / RETAINING WALLS (Z: 31.0 to 39.0, Y: -7.6 to 2.5) ---
	# Left Retaining Wall (X: 0.6 to 1.0)
	# Top Cap
	add_quad.call(Vector3(0.6, 2.5, 39.0), Vector3(1.0, 2.5, 39.0), Vector3(0.6, 2.5, 31.0), Vector3(1.0, 2.5, 31.0), Vector3.UP)
	# Inside Face (facing stairs / +X)
	add_quad.call(Vector3(1.0, 2.5, 31.0), Vector3(1.0, 2.5, 39.0), Vector3(1.0, -7.6, 31.0), Vector3(1.0, -7.6, 39.0), Vector3.RIGHT)
	# Outside Face (facing left / -X)
	add_quad.call(Vector3(0.6, 2.5, 39.0), Vector3(0.6, 2.5, 31.0), Vector3(0.6, -7.6, 39.0), Vector3(0.6, -7.6, 31.0), Vector3.LEFT)
	# Front End Cap (Z = 31.0)
	add_quad.call(Vector3(0.6, 2.5, 31.0), Vector3(1.0, 2.5, 31.0), Vector3(0.6, -7.6, 31.0), Vector3(1.0, -7.6, 31.0), Vector3.BACK)

	# Right Retaining Wall (X: 6.0 to 6.4)
	# Top Cap
	add_quad.call(Vector3(6.0, 2.5, 39.0), Vector3(6.4, 2.5, 39.0), Vector3(6.0, 2.5, 31.0), Vector3(6.4, 2.5, 31.0), Vector3.UP)
	# Inside Face (facing stairs / -X)
	add_quad.call(Vector3(6.0, 2.5, 31.0), Vector3(6.0, 2.5, 39.0), Vector3(6.0, -7.6, 31.0), Vector3(6.0, -7.6, 39.0), Vector3.LEFT)
	# Outside Face (facing right / +X)
	add_quad.call(Vector3(6.4, 2.5, 39.0), Vector3(6.4, 2.5, 31.0), Vector3(6.4, -7.6, 39.0), Vector3(6.4, -7.6, 31.0), Vector3.RIGHT)
	# Front End Cap (Z = 31.0)
	add_quad.call(Vector3(6.0, 2.5, 31.0), Vector3(6.4, 2.5, 31.0), Vector3(6.0, -7.6, 31.0), Vector3(6.4, -7.6, 31.0), Vector3.BACK)

	# --- SPINDLE SAFETY RAILINGS ON BASEMENT STAIR RETAINING WALLS ---
	var add_box_direct = func(bx1: float, bx2: float, by1: float, by2: float, bz1: float, bz2: float):
		var x_min = minf(bx1, bx2)
		var x_max = maxf(bx1, bx2)
		var y_min = minf(by1, by2)
		var y_max = maxf(by1, by2)
		var z_min = minf(bz1, bz2)
		var z_max = maxf(bz1, bz2)
		if is_equal_approx(x_min, x_max) or is_equal_approx(y_min, y_max) or is_equal_approx(z_min, z_max):
			return
		# South Face (-Z)
		add_quad.call(Vector3(x_max, y_min, z_min), Vector3(x_min, y_min, z_min), Vector3(x_max, y_max, z_min), Vector3(x_min, y_max, z_min), Vector3.BACK)
		# North Face (+Z)
		add_quad.call(Vector3(x_min, y_min, z_max), Vector3(x_max, y_min, z_max), Vector3(x_min, y_max, z_max), Vector3(x_max, y_max, z_max), Vector3.FORWARD)
		# West Face (-X)
		add_quad.call(Vector3(x_min, y_min, z_min), Vector3(x_min, y_min, z_max), Vector3(x_min, y_max, z_min), Vector3(x_min, y_max, z_max), Vector3.LEFT)
		# East Face (+X)
		add_quad.call(Vector3(x_max, y_min, z_max), Vector3(x_max, y_min, z_min), Vector3(x_max, y_max, z_max), Vector3(x_max, y_max, z_min), Vector3.RIGHT)
		# Top Face (+Y)
		add_quad.call(Vector3(x_min, y_max, z_max), Vector3(x_max, y_max, z_max), Vector3(x_min, y_max, z_min), Vector3(x_max, y_max, z_min), Vector3.UP)
		# Bottom Face (-Y)
		add_quad.call(Vector3(x_min, y_min, z_min), Vector3(x_max, y_min, z_min), Vector3(x_min, y_min, z_max), Vector3(x_max, y_min, z_max), Vector3.DOWN)

	var add_cylinder_direct = func(center_b: Vector3, rad: float, h: float, segs: int):
		var num_segs = maxi(8, segs)
		var top_c = center_b + Vector3(0, h, 0)
		for i in range(num_segs):
			var a1 = float(i) * TAU / float(num_segs)
			var a2 = float(i + 1) * TAU / float(num_segs)
			var p1_b = center_b + Vector3(cos(a1) * rad, 0, sin(a1) * rad)
			var p2_b = center_b + Vector3(cos(a2) * rad, 0, sin(a2) * rad)
			var p1_t = p1_b + Vector3(0, h, 0)
			var p2_t = p2_b + Vector3(0, h, 0)
			var side_norm = Vector3(cos((a1 + a2) * 0.5), 0, sin((a1 + a2) * 0.5)).normalized()
			add_quad.call(p2_b, p1_b, p2_t, p1_t, side_norm)
			add_quad.call(top_c, p1_t, top_c, p2_t, Vector3.UP)
			add_quad.call(center_b, p2_b, center_b, p1_b, Vector3.DOWN)

	var add_spindle_railing = func(z1: float, z2: float, rx: float, y_base: float, r_height: float):
		add_box_direct.call(rx - 0.1, rx + 0.1, y_base + 0.15, y_base + 0.35, z1, z2)
		add_box_direct.call(rx - 0.12, rx + 0.12, y_base + r_height - 0.2, y_base + r_height, z1, z2)
		# Newel End Posts (8+ sides)
		add_cylinder_direct.call(Vector3(rx, y_base, z1), 0.12, r_height + 0.15, 12)
		add_cylinder_direct.call(Vector3(rx, y_base, z2), 0.12, r_height + 0.15, 12)
		var count = int(abs(z2 - z1) / 0.35)
		for s_idx in range(count + 1):
			var sz = minf(z1, z2) + (s_idx * 0.35)
			add_cylinder_direct.call(Vector3(rx, y_base + 0.35, sz), 0.05, r_height - 0.55, 8)

	# Left side safety railing (along X = 0.8) and Right side safety railing (along X = 6.2) on top of walls (Y = 2.5)
	add_spindle_railing.call(31.0, 39.0, 0.8, 2.5, 3.0)
	add_spindle_railing.call(31.0, 39.0, 6.2, 2.5, 3.0)

	st.index()
	st.generate_normals()
	st.generate_tangents()
	self.mesh = st.commit()
	self.create_trimesh_collision()

	# 2. STEEL BILCO DOOR ASSEMBLIES (Relocated to X: 1.0 to 6.0)
	var st_doors = SurfaceTool.new()
	st_doors.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_doors.set_material(steel_mat)

	var add_steel_quad = func(v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, norm: Vector3):
		st_doors.set_normal(norm)
		st_doors.set_uv(Vector2(0, 0)); st_doors.add_vertex(v0)
		st_doors.set_uv(Vector2(1, 0)); st_doors.add_vertex(v1)
		st_doors.set_uv(Vector2(0, 1)); st_doors.add_vertex(v2)

		st_doors.set_normal(norm)
		st_doors.set_uv(Vector2(1, 0)); st_doors.add_vertex(v1)
		st_doors.set_uv(Vector2(1, 1)); st_doors.add_vertex(v3)
		st_doors.set_uv(Vector2(0, 1)); st_doors.add_vertex(v2)

	# Left Slanted Steel Door (X: 1.0 to 3.5, Z: 31.0 to 39.0)
	# Adjusted top height to 2.5 to match the new foundation height
	var dl_0 = Vector3(1.0, 2.5, 39.0)
	var dl_1 = Vector3(3.5, 2.5, 39.0)
	var dl_2 = Vector3(1.0, 0.5, 31.0)
	var dl_3 = Vector3(3.5, 0.5, 31.0)
	
	var norm_left = (dl_1 - dl_0).cross(dl_2 - dl_0).normalized()
	add_steel_quad.call(dl_1, dl_0, dl_3, dl_2, norm_left)

	# Right Slanted Steel Door (X: 3.5 to 6.0, Z: 31.0 to 39.0)
	# Adjusted top height to 2.5 to match the new foundation height
	var dr_0 = Vector3(3.5, 2.5, 39.0)
	var dr_1 = Vector3(6.0, 2.5, 39.0)
	var dr_2 = Vector3(3.5, 0.5, 31.0)
	var dr_3 = Vector3(6.0, 0.5, 31.0)
	
	var norm_right = (dr_1 - dr_0).cross(dr_2 - dr_0).normalized()
	add_steel_quad.call(dr_1, dr_0, dr_3, dr_2, norm_right)

	# Ground Level Front Header Plate (Z = 31.0)
	add_steel_quad.call(Vector3(1.0, 0.5, 31.0), Vector3(6.0, 0.5, 31.0), Vector3(1.0, 0.0, 31.0), Vector3(6.0, 0.0, 31.0), Vector3.BACK)

	# Sidewalls sealing the steel frame to terrain
	# Adjusted top height to 2.5 to match the new foundation height
	add_steel_quad.call(Vector3(1.0, 2.5, 39.0), Vector3(1.0, 0.5, 31.0), Vector3(1.0, 0.0, 39.0), Vector3(1.0, 0.0, 31.0), Vector3.LEFT)
	add_steel_quad.call(Vector3(6.0, 0.5, 31.0), Vector3(6.0, 2.5, 39.0), Vector3(6.0, 0.0, 31.0), Vector3(6.0, 0.0, 39.0), Vector3.RIGHT)

	st_doors.index()
	st_doors.generate_normals()
	st_doors.generate_tangents()

	var mesh_doors = MeshInstance3D.new()
	mesh_doors.name = "BilcoDoors"
	mesh_doors.mesh = st_doors.commit()
	mesh_doors.create_trimesh_collision()
	add_child(mesh_doors)
	if Engine.is_editor_hint():
		mesh_doors.owner = get_tree().edited_scene_root

	print("=== BUILDER STEP 2: BASEMENT EXPOSED FOUNDATION WALLS RAISED SUCCESSFULLY ===")
