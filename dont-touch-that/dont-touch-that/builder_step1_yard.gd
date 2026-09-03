@tool
extends MeshInstance3D

func _ready():
	print("=== STEP 1 PIPELINE: RELOCATING BILCO TERRAIN EXCAVATION TO REAR-LEFT (X: 1.0 to 6.0) ===")
	build_yard()
func create_pbr_material(albedo_path: String, normal_path: String, roughness_path: String, tint: Color, uv_scale: Vector3) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = tint
	
	if albedo_path != "" and ResourceLoader.exists(albedo_path):
		mat.albedo_texture = load(albedo_path)
	if normal_path != "" and ResourceLoader.exists(normal_path):
		mat.normal_enabled = true
		mat.normal_texture = load(normal_path)
	if  roughness_path != "" and ResourceLoader.exists(roughness_path):
		mat.roughness_enabled = true
		mat.roughness_texture = load(roughness_path)
	
	mat.uv1_triplanar = true
	mat.uv1_scale = uv_scale
	mat.uv1_triplanar_sharpness = 10.0
	return mat
	
	if albedo_path != "" and ResourceLoader.exists(albedo_path):
		mat.albedo_texture = load(albedo_path)
	if normal_path != "" and ResourceLoader.exists(normal_path):
		mat.normal_enabled = true
		mat.normal_texture = load(normal_path)
	if roughness_path != "" and ResourceLoader.exists(roughness_path):
		mat.roughness_enabled = true
		mat.normal_texture = load(roughness_path)

		mat.uv1_triplaner = true
		mat.uv1_scale = uv_scale
		mat.uv1_triplanar_sharpness = 10.0
		return mat

func build_yard():
	var grass_mat = create_pbr_material("", "", "", Color(0.22, 0.52, 0.18), Vector3(0.1, 0.1, 0.1))    
	grass_mat.albedo_color = Color(0.22, 0.52, 0.18)
	grass_mat.roughness = 0.85

	var dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.32, 0.24, 0.16)
	dirt_mat.roughness = 0.95

	var asphalt_mat = create_pbr_material("res://textures/asphalt.jpg", "", "", Color(0.6, 0.6, 0.6), Vector3(0.2, 0.2, 0.2))
	asphalt_mat.albedo_color = Color(0.18, 0.18, 0.20)
	asphalt_mat.roughness = 0.75

	var get_yard_height = func(z: float) -> float:
		var t = clampf((120.0 - z) / 120.0, 0.0, 1.0)
		var smooth_t = t * t * (3.0 - 2.0 * t)
		return lerpf(0.0, -4.5, smooth_t)

	# 1. Expanded Yard Surface Mesh (X: -3.0 to 45.0, 0.5ft Spacing)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(grass_mat)

	var step_size = 0.5
	var nx = int(48.0 / step_size)
	var nz = int(120.0 / step_size)

	for i in range(nx):
		for j in range(nz):
			var x0 = -3.0 + float(i) * step_size
			var x1 = -3.0 + float(i + 1) * step_size
			var z0 = float(j) * step_size
			var z1 = float(j + 1) * step_size

			# Expanded 27-ft House Excavation Footprint (X: 0.0 to 27.0, Z: 39.0 to 110.0)
			var inside_house0 = (x0 >= 0.0 and x0 <= 27.0 and z0 >= 39.0 and z0 <= 110.0)
			var inside_house1 = (x1 >= 0.0 and x1 <= 27.0 and z1 >= 39.0 and z1 <= 110.0)

			# REAR-LEFT BILCO WALK-OUT ENTRANCE (X: 1.0 to 6.0, Z: 34.0 to 39.0)
			var inside_bilco0 = (x0 >= 1.0 and x0 <= 6.0 and z0 >= 34.0 and z0 <= 39.0)
			var inside_bilco1 = (x1 >= 1.0 and x1 <= 6.0 and z1 >= 34.0 and z1 <= 39.0)

			if (inside_house0 and inside_house1) or (inside_bilco0 and inside_bilco1):
				continue

			var y00 = get_yard_height.call(z0)
			var y10 = get_yard_height.call(z0)
			var y01 = get_yard_height.call(z1)
			var y11 = get_yard_height.call(z1)

			var u0 = (x0 + 3.0) / 48.0
			var u1 = (x1 + 3.0) / 48.0
			var v0 = z0 / 120.0
			var v1 = z1 / 120.0

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u0, v0)); st.add_vertex(Vector3(x0, y00, z0))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(Vector3(x1, y10, z0))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(Vector3(x0, y01, z1))

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(Vector3(x1, y10, z0))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(Vector3(x1, y11, z1))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(Vector3(x0, y01, z1))

	st.index()
	st.generate_normals()
	st.generate_tangents()

	self.mesh = st.commit()
	self.create_trimesh_collision()

	# 2. Excavated Dirt Floor (X: 0.0 to 27.0) & Retaining Wall (Along X = 27.0)
	var st_cut = SurfaceTool.new()
	st_cut.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_cut.set_material(dirt_mat)

	st_cut.set_normal(Vector3.UP)
	st_cut.set_uv(Vector2(0, 0)); st_cut.add_vertex(Vector3(0.0, -8.0, 39.0))
	st_cut.set_uv(Vector2(1, 0)); st_cut.add_vertex(Vector3(27.0, -8.0, 39.0))
	st_cut.set_uv(Vector2(0, 1)); st_cut.add_vertex(Vector3(0.0, -8.0, 110.0))
	st_cut.set_uv(Vector2(1, 0)); st_cut.add_vertex(Vector3(27.0, -8.0, 39.0))
	st_cut.set_uv(Vector2(1, 1)); st_cut.add_vertex(Vector3(27.0, -8.0, 110.0))
	st_cut.set_uv(Vector2(0, 1)); st_cut.add_vertex(Vector3(0.0, -8.0, 110.0))

	# Rear-Left Bilco Dirt Floor (X: 1.0 to 6.0, Z: 33.0 to 39.0)
	# Side walls connecting down to -8.0 from foundation (Y=2.5) down to ground (Y=0.0)
	# Left Side Wall (X = 1.0)
	st_cut.set_normal(Vector3.RIGHT)
	st_cut.add_vertex(Vector3(1.0, -8.0, 39.0))
	st_cut.add_vertex(Vector3(1.0, 2.5, 39.0))
	st_cut.add_vertex(Vector3(1.0, -8.0, 34.0))
	st_cut.add_vertex(Vector3(1.0, 2.5, 39.0))
	st_cut.add_vertex(Vector3(1.0, 0.0, 34.0))
	st_cut.add_vertex(Vector3(1.0, -8.0, 34.0))
	# Right Side Wall (X = 6.0)
	st_cut.set_normal(Vector3.LEFT)
	st_cut.add_vertex(Vector3(6.0, -8.0, 34.0))
	st_cut.add_vertex(Vector3(6.0, 2.5, 39.0))
	st_cut.add_vertex(Vector3(6.0, -8.0, 39.0))
	st_cut.add_vertex(Vector3(6.0, -8.0, 34.0))
	st_cut.add_vertex(Vector3(6.0, 0.0, 34.0))
	st_cut.add_vertex(Vector3(6.0, 2.5, 39.0))
	# Slope Wall (Z = 34.0)
	st_cut.set_normal(Vector3.FORWARD)
	st_cut.add_vertex(Vector3(1.0, -8.0, 34.0))
	st_cut.add_vertex(Vector3(1.0, 0.0, 34.0))
	st_cut.add_vertex(Vector3(6.0, -8.0, 34.0))
	st_cut.add_vertex(Vector3(1.0, 0.0, 34.0))
	st_cut.add_vertex(Vector3(6.0, 0.0, 34.0))
	st_cut.add_vertex(Vector3(6.0, -8.0, 34.0))
	st_cut.add_vertex(Vector3(1.0, -8.0, 33.0))
	st_cut.add_vertex(Vector3(6.0, -8.0, 33.0))
	st_cut.add_vertex(Vector3(1.0, -8.0, 39.0))
	st_cut.add_vertex(Vector3(6.0, -8.0, 33.0))
	st_cut.add_vertex(Vector3(6.0, -8.0, 39.0))
	st_cut.add_vertex(Vector3(1.0, -8.0, 39.0))

	var r_segs = 60
	for s in range(r_segs):
		var za = 39.0 + (float(s) / float(r_segs)) * 71.0
		var zb = 39.0 + (float(s + 1) / float(r_segs)) * 71.0
		var ya = get_yard_height.call(za)
		var yb = get_yard_height.call(zb)

		st_cut.set_normal(Vector3.LEFT)
		st_cut.add_vertex(Vector3(27.0, -8.0, za))
		st_cut.add_vertex(Vector3(27.0, ya, za))
		st_cut.add_vertex(Vector3(27.0, -8.0, zb))

		st_cut.add_vertex(Vector3(27.0, ya, za))
		st_cut.add_vertex(Vector3(27.0, yb, zb))
		st_cut.add_vertex(Vector3(27.0, -8.0, zb))

	st_cut.index()
	st_cut.generate_normals()
	st_cut.generate_tangents()

	var cutout_mesh = MeshInstance3D.new()
	cutout_mesh.name = "Foundation_Excavation"
	cutout_mesh.mesh = st_cut.commit()
	cutout_mesh.create_trimesh_collision()
	add_child(cutout_mesh)

	# 3. Driveway Surface (X: 31.0 to 43.0)
	var st_drive = SurfaceTool.new()
	st_drive.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_drive.set_material(asphalt_mat)

	var drive_segs = 80
	for d in range(drive_segs):
		var za = 34.0 + (float(d) / float(drive_segs)) * 86.0
		var zb = 34.0 + (float(d + 1) / float(drive_segs)) * 86.0
		var ya = get_yard_height.call(za) + 0.06
		var yb = get_yard_height.call(zb) + 0.06

		st_drive.set_normal(Vector3.UP)
		st_drive.set_uv(Vector2(0, float(d)/drive_segs)); st_drive.add_vertex(Vector3(31.0, ya, za))
		st_drive.set_uv(Vector2(1, float(d)/drive_segs)); st_drive.add_vertex(Vector3(43.0, ya, za))
		st_drive.set_uv(Vector2(0, float(d+1)/drive_segs)); st_drive.add_vertex(Vector3(31.0, yb, zb))

		st_drive.set_uv(Vector2(1, float(d)/drive_segs)); st_drive.add_vertex(Vector3(43.0, ya, za))
		st_drive.set_uv(Vector2(1, float(d+1)/drive_segs)); st_drive.add_vertex(Vector3(43.0, yb, zb))
		st_drive.set_uv(Vector2(0, float(d+1)/drive_segs)); st_drive.add_vertex(Vector3(31.0, yb, zb))

	st_drive.index()
	st_drive.generate_normals()
	st_drive.generate_tangents()

	var drive_mesh = MeshInstance3D.new()
	drive_mesh.name = "Paved_Driveway_Surface"
	drive_mesh.mesh = st_drive.commit()
	drive_mesh.create_trimesh_collision()
	add_child(drive_mesh)

	print("=== BUILDER STEP 1: BILCO TERRAIN CUTOUT RELOCATED TO REAR-LEFT (X: 1.0 to 6.0) ===")
