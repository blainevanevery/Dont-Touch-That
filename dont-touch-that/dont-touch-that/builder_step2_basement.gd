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

	# Rear Top Caps (Splits around Rear-Left Bilco Channel at X: 1.0 to 6.0)
	add_quad.call(Vector3(0.0, 2.5, 39.7), Vector3(1.0, 2.5, 39.7), Vector3(0.0, 2.5, 39.0), Vector3(1.0, 2.5, 39.0), Vector3.UP) # Rear Far-Left Top Cap
	add_quad.call(Vector3(6.0, 2.5, 39.7), Vector3(27.0, 2.5, 39.7), Vector3(6.0, 2.5, 39.0), Vector3(27.0, 2.5, 39.0), Vector3.UP) # Rear Main Top Cap (X: 6.0 to 27.0)

	# Exterior Wall Faces (Y: 2.5 to -8.0)
	add_quad.call(Vector3(0.0, 2.5, 110.0), Vector3(27.0, 2.5, 110.0), Vector3(0.0, -8.0, 110.0), Vector3(27.0, -8.0, 110.0), Vector3.FORWARD) # Front Ext
	add_quad.call(Vector3(0.0, 2.5, 39.0), Vector3(0.0, 2.5, 110.0), Vector3(0.0, -8.0, 39.0), Vector3(0.0, -8.0, 110.0), Vector3.LEFT) # Left Ext
	add_quad.call(Vector3(27.0, 2.5, 110.0), Vector3(27.0, 2.5, 39.0), Vector3(27.0, -8.0, 110.0), Vector3(27.0, -8.0, 39.0), Vector3.RIGHT) # Right Ext

	# Rear Exterior Walls with CCW Winding & Vector3.BACK normal (Z = 39.0)
	add_quad.call(Vector3(1.0, 2.5, 39.0), Vector3(0.0, 2.5, 39.0), Vector3(1.0, -8.0, 39.0), Vector3(0.0, -8.0, 39.0), Vector3.BACK) # Far Left Ext
	add_quad.call(Vector3(27.0, 2.5, 39.0), Vector3(6.0, 2.5, 39.0), Vector3(27.0, -8.0, 39.0), Vector3(6.0, -8.0, 39.0), Vector3.BACK) # Main Rear Ext (X: 6.0 to 27.0)

	# Interior Wall Faces (Y: 2.5 to -7.6)
	add_quad.call(Vector3(26.3, 2.5, 109.3), Vector3(0.7, 2.5, 109.3), Vector3(26.3, -7.6, 109.3), Vector3(0.7, -7.6, 109.3), Vector3.BACK) # Front Int
	add_quad.call(Vector3(0.7, 2.5, 109.3), Vector3(0.7, 2.5, 39.7), Vector3(0.7, -7.6, 109.3), Vector3(0.7, -7.6, 39.7), Vector3.RIGHT) # Left Int
	add_quad.call(Vector3(26.3, 2.5, 39.7), Vector3(26.3, 2.5, 109.3), Vector3(26.3, -7.6, 39.7), Vector3(26.3, -7.6, 109.3), Vector3.LEFT) # Right Int

	# Rear Interior Walls (Z = 39.7)
	add_quad.call(Vector3(1.0, 2.5, 39.7), Vector3(0.7, 2.5, 39.7), Vector3(1.0, -7.6, 39.7), Vector3(0.7, -7.6, 39.7), Vector3.FORWARD) # Far Left Int
	add_quad.call(Vector3(26.3, 2.5, 39.7), Vector3(6.0, 2.5, 39.7), Vector3(26.3, -7.6, 39.7), Vector3(6.0, -7.6, 39.7), Vector3.FORWARD) # Main Rear Int

	# Inner Channel Walls around Bilco Entry (Z: 39.0 to 39.7, X: 1.0 to 6.0)
	add_quad.call(Vector3(1.0, 2.5, 39.7), Vector3(1.0, 2.5, 39.0), Vector3(1.0, -7.6, 39.7), Vector3(1.0, -8.0, 39.0), Vector3.RIGHT) # Left side of channel
	add_quad.call(Vector3(6.0, 2.5, 39.0), Vector3(6.0, 2.5, 39.7), Vector3(6.0, -8.0, 39.0), Vector3(6.0, -7.6, 39.7), Vector3.LEFT) # Right side of channel

	# Basement Floor Plane (Thickness Y: -7.6 to -8.0)
	add_quad.call(Vector3(0.7, -7.6, 109.3), Vector3(26.3, -7.6, 109.3), Vector3(0.7, -7.6, 39.7), Vector3(26.3, -7.6, 39.7), Vector3.UP) # Inside Floor Top
	add_quad.call(Vector3(0.0, -8.0, 39.0), Vector3(27.0, -8.0, 39.0), Vector3(0.0, -8.0, 110.0), Vector3(27.0, -8.0, 110.0), Vector3.DOWN) # True Bottom Foundation Slab

	# --- CONCRETE BASEMENT EXIT STAIRS (X: 1.0 to 6.0, Z: 31.0 to 39.0) ---
	var num_steps = 15
	for i in range(num_steps):
		var z_start = 39.0 - (float(i) * (8.0 / num_steps))
		var z_end = 39.0 - (float(i + 1) * (8.0 / num_steps))
		var y_bottom = -7.6
		var y_top = -7.6 + (float(i + 1) * (10.1 / num_steps)) # reaches Y = 2.5
		
		# Step Top face
		add_quad.call(Vector3(1.0, y_top, z_start), Vector3(6.0, y_top, z_start), Vector3(1.0, y_top, z_end), Vector3(6.0, y_top, z_end), Vector3.UP)
		# Step Front face
		add_quad.call(Vector3(1.0, y_top, z_end), Vector3(6.0, y_top, z_end), Vector3(1.0, y_top - (10.1 / num_steps), z_end), Vector3(6.0, y_top - (10.1 / num_steps), z_end), Vector3.BACK)

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
