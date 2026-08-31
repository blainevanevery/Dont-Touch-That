@tool
extends Node3D

## level_builder.gd  — Dont Touch That
## Parses res://house_layout.json and procedurally builds the full 3D property:
##   • Flat front yard  (Y = 0)
##   • Sloped backyard  (drops -1.83m by Z = -36.58m)
##   • Asphalt driveway (right side)
##   • Basement level   (Y = -3.048 to 0.0) — walk-out storm entry only
##   • 1st & 2nd floor  (Y = 0.0 to 6.096m)
##
## World coordinate system:
##   +X = lot width  (0 → 13.72m / 45 ft)
##   -Z = lot depth  (0 = street → -36.58m = back fence)
##   +Y = up
##
## House root is offset to Vector3(0.91, 0.0, -3.05).
## All wall/door/window JSON coords are LOCAL to that root.

@export var rebuild: bool = false:
	set(val):
		if val:
			build_level()

func _ready() -> void:
	build_level()

# ─────────────────────────────────────────────────────────────────────────────
func build_level() -> void:
	for child in get_children():
		if child.name != "Camera3D" and child.name != "WorldEnvironment":
			child.queue_free()
			remove_child(child)

	# ── Load JSON ─────────────────────────────────────────────────────────────
	var file = FileAccess.open("res://house_layout.json", FileAccess.READ)
	if not file:
		push_error("level_builder: cannot open house_layout.json"); return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("level_builder: JSON parse error – " + json.get_error_message()); return

	var data       = json.get_data()
	var dims       = data.get("dimensions", {})
	var yard_z     : float = dims.get("yard", [36.58, 13.72])[0]
	var yard_x     : float = dims.get("yard", [36.58, 13.72])[1]
	var house_z    : float = dims.get("house",[18.59, 7.62])[0]
	var house_x    : float = dims.get("house",[18.59, 7.62])[1]
	var wall_h     : float = dims.get("wall_height",   3.0)
	var def_thick  : float = dims.get("wall_thickness",0.1016)

	var ho         : Array = dims.get("house_offset",[0.91,0.0,-3.05])
	var house_off  := Vector3(ho[0], ho[1], ho[2])

	var drv        : Dictionary = dims.get("driveway",{})
	var ter        : Dictionary = dims.get("terrain",{})
	var bsm        : Dictionary = dims.get("basement",{})

	var flat_z_end  : float = ter.get("flat_z_end",  -16.76)
	var slope_z_end : float = ter.get("slope_z_end", -36.58)
	var slope_drop  : float = ter.get("slope_y_drop", -1.83)
	var bs_y_bot    : float = bsm.get("y_bottom",    -3.048)
	var bs_thick    : float = bsm.get("wall_thickness", 0.2032)

	# ── Materials ─────────────────────────────────────────────────────────────
	var m_grass    = _mat("res://assets/materials/grass.tres",    Color(0.18, 0.40, 0.18))
	var m_asphalt  = _mat("res://assets/materials/driveway.tres", Color(0.22, 0.22, 0.22))
	var m_concrete = _mat("res://assets/materials/concrete.tres", Color(0.52, 0.50, 0.48))
	var m_wall     = _mat("res://assets/materials/wall.tres",     Color(0.82, 0.80, 0.75))
	var m_floor    = _mat("res://assets/materials/wood.tres",     Color(0.48, 0.32, 0.20))
	var m_roof     = _mat("res://assets/materials/roof.tres",     Color(0.22, 0.20, 0.24))
	var m_stone    = _mat("res://assets/materials/stone.tres",    Color(0.40, 0.38, 0.36))
	var m_dirt     = _mat("res://assets/materials/dirt.tres",     Color(0.30, 0.22, 0.14))

	# ── Camera & Sky ──────────────────────────────────────────────────────────
	_setup_camera_env(yard_x, yard_z)

	# ═════════════════════════════════════════════════════════════════════════
	# 1. TERRAIN — Flat front + sloped back
	# ═════════════════════════════════════════════════════════════════════════
	var flat_len   : float = abs(flat_z_end)
	_add_static_box("Ground_Flat", m_grass,
					Vector3(yard_x, 0.30, flat_len),
					Vector3(yard_x*0.5, -0.15, flat_z_end*0.5))

	# Sloped slab: rotated around X-axis, positioned to meet flat section seamlessly
	var run        : float = abs(slope_z_end - flat_z_end)
	var hyp        : float = sqrt(run*run + slope_drop*slope_drop)
	var ang        : float = atan2(abs(slope_drop), run)
	var slope_body : StaticBody3D = _add_static_box("Ground_Slope", m_grass,
					Vector3(yard_x, 0.30, hyp),
					Vector3(yard_x*0.5, slope_drop*0.5 - 0.15, flat_z_end - run*0.5))
	slope_body.rotation.x = ang

	# ═════════════════════════════════════════════════════════════════════════
	# 2. DRIVEWAY  (right-side strip, flat)
	# ═════════════════════════════════════════════════════════════════════════
	var dx1 : float = drv.get("x_start", 8.84)
	var dx2 : float = drv.get("x_end",  12.80)
	var dz1 : float = drv.get("z_start",  0.0)
	var dz2 : float = drv.get("z_end",  -25.9)
	var dh  : float = drv.get("height",   0.05)
	var dw  : float = dx2 - dx1
	var dl  : float = abs(dz2 - dz1)
	_add_static_box("Driveway", m_asphalt,
					Vector3(dw, dh, dl),
					Vector3((dx1+dx2)*0.5, dh*0.5, (dz1+dz2)*0.5))

	# ═════════════════════════════════════════════════════════════════════════
	# 3. HOUSE ROOT — all house geometry is LOCAL to this node
	# ═════════════════════════════════════════════════════════════════════════
	var house_root      = Node3D.new()
	house_root.name     = "HouseRoot"
	house_root.position = house_off
	add_child(house_root)

	var hcx := house_x * 0.5          # local centre X = 3.81
	var hcz := -house_z * 0.5         # local centre Z = -9.295

	# ═════════════════════════════════════════════════════════════════════════
	# 4. BASEMENT  (floor_number = 0, Y = -3.048 to 0.0)
	# ═════════════════════════════════════════════════════════════════════════
	for floor_data in data.get("floors", []):
		var fn    : int   = floor_data.get("floor_number", 1)
		var y_bot : float

		# Basement uses its own y_base from JSON
		if fn == 0:
			y_bot = float(floor_data.get("y_base", bs_y_bot))
		else:
			y_bot = (fn - 1) * wall_h

		var combiner          = CSGCombiner3D.new()
		combiner.name         = "House_Floor_" + str(fn) if fn > 0 else "Basement"
		combiner.use_collision = true
		house_root.add_child(combiner)

		# ── Floor slab ───────────────────────────────────────────────────────
		var slab_mat  = m_stone if fn == 0 else m_floor
		var slab_w    = house_x
		var slab_l    = house_z
		var slab      = CSGBox3D.new()
		slab.name     = "FloorSlab"
		slab.size     = Vector3(slab_w, 0.15, slab_l)
		slab.position = Vector3(hcx, y_bot + 0.075, hcz)
		slab.material = slab_mat
		combiner.add_child(slab)

		# ── Walls ─────────────────────────────────────────────────────────────
		var w_mat = m_stone if fn == 0 else m_wall
		for w in floor_data.get("walls", []):
			var s  : Array = w.get("start", [0.0, 0.0])
			var e  : Array = w.get("end",   [0.0, 0.0])
			var th : float = w.get("thickness", def_thick)
			_build_wall(Vector2(s[0],s[1]), Vector2(e[0],e[1]),
						y_bot, wall_h, th, combiner, w_mat)

		# ── Door cutouts ──────────────────────────────────────────────────────
		for d in floor_data.get("doors", []):
			var dw2 : float = d.get("width",  0.9)
			var dh2 : float = d.get("height", 2.1)
			var rot : float = d.get("rotation", 0.0)
			var cut = CSGBox3D.new()
			cut.operation = CSGShape3D.OPERATION_SUBTRACTION
			cut.size = Vector3(dw2, dh2, 0.5) if rot == 0.0 else Vector3(0.5, dh2, dw2)
			cut.position = Vector3(d.get("x",0.0), y_bot + dh2*0.5, d.get("z",0.0))
			combiner.add_child(cut)

		# ── Window cutouts ────────────────────────────────────────────────────
		for win in floor_data.get("windows", []):
			var ww  : float = win.get("width",  1.0)
			var wh  : float = win.get("height", 1.2)
			var wy  : float = win.get("y_offset", 0.9)
			var rot : float = win.get("rotation", 0.0)
			var cut = CSGBox3D.new()
			cut.operation = CSGShape3D.OPERATION_SUBTRACTION
			cut.size = Vector3(ww, wh, 0.5) if rot == 0.0 else Vector3(0.5, wh, ww)
			cut.position = Vector3(win.get("x",0.0), y_bot + wy + wh*0.5, win.get("z",0.0))
			combiner.add_child(cut)

		# ── Staircases ────────────────────────────────────────────────────────
		for st in floor_data.get("stairs", []):
			var is_ext : bool = st.get("is_exterior", false)
			var s_mat         = m_concrete if is_ext else m_floor
			_build_stairs(
				st.get("x", 0.0), st.get("z", 0.0),
				st.get("width", 1.2), st.get("length", 3.0),
				y_bot, y_bot + wall_h,
				st.get("direction", [0.0, -1.0]),
				combiner, s_mat
			)

		# ── Basement-specific: exterior bilco stairwell enclosure ─────────────
		if fn == 0:
			_build_bilco_stairwell(house_root, m_concrete, bs_y_bot)

		# ── Gameplay interactables (basement) ─────────────────────────────────
		if fn == 0:
			for trigger in floor_data.get("interactables", []):
				_spawn_interactable(house_root, trigger, y_bot)

		# ── Searchable containers ─────────────────────────────────────────────
		for room in floor_data.get("rooms", []):
			var rn : String = room.get("name","").to_lower()
			var rx : float  = room.get("x",0.0)
			var rz : float  = room.get("z",0.0)
			if "kitchen" in rn:
				_spawn_container(house_root, "Kitchen_Cupboard_F"+str(fn),
								 rx+0.3, y_bot+0.9, rz+0.3,
								 Vector3(0.7,0.8,0.45), Vector3(0,90,0))
			elif "bath" in rn:
				_spawn_container(house_root, "Bath_Cabinet_F"+str(fn),
								 rx+0.2, y_bot+0.9, rz+0.2,
								 Vector3(0.5,0.65,0.35), Vector3.ZERO)
			elif "bedroom" in rn:
				_spawn_container(house_root, "Footlocker_F"+str(fn)+"_"+rn.replace(" ",""),
								 rx+0.5, y_bot+0.3, rz+0.5,
								 Vector3(0.9,0.5,0.55), Vector3(90,0,0))
			elif "cellar" in rn or "storage" in rn:
				_spawn_container(house_root, "StorageShelf_F"+str(fn),
								 rx+0.5, y_bot+0.7, rz+0.5,
								 Vector3(0.6, 1.5, 0.35), Vector3.ZERO)
			elif "porch" in rn:
				var rail      = CSGBox3D.new()
				rail.name     = "Porch_Rail_F"+str(fn)
				rail.size     = Vector3(room.get("width",2.4), 1.0, room.get("depth",1.5))
				rail.position = Vector3(rx, y_bot+0.5, rz)
				rail.material = m_concrete
				combiner.add_child(rail)

		# ── Back porch landing at grade seam (Floor 1 only) ──────────────────
		if fn == 1:
			var landing      = CSGBox3D.new()
			landing.name     = "BackPorch_Landing"
			landing.size     = Vector3(2.4, 0.15, 1.2)
			landing.position = Vector3(hcx, -0.075, 0.6)
			landing.material = m_concrete
			house_root.add_child(landing)

	# ── Roof ──────────────────────────────────────────────────────────────────
	var roof      = CSGBox3D.new()
	roof.name     = "Roof"
	roof.size     = Vector3(house_x, 0.2, house_z)
	roof.position = Vector3(hcx, wall_h * 2.0 + 0.1, hcz)
	roof.material = m_roof
	house_root.add_child(roof)

# ─────────────────────────────────────────────────────────────────────────────
# Exterior Bilco / Storm Stairwell (concrete enclosure protruding into slope)
# ─────────────────────────────────────────────────────────────────────────────
func _build_bilco_stairwell(parent: Node, mat: Material, bs_y_bot: float) -> void:
	# Enclosure walls around the open stairwell pit
	# Local coords from JSON: storm vestibule X:14→24.5, local_z: -(70.5-10) to -(80.5-10)
	# = local X: (17-3)*FT=4.267 to (27-3)*FT=7.315, local Z: -18.44 to -21.49
	const FT : float = 0.3048
	var ex1 : float = (18.0 - 3.0) * FT     # 4.572
	var ex2 : float = (27.0 - 3.0) * FT     # 7.315
	var ez1 : float = -(70.5 - 10.0) * FT   # -18.44
	var ez2 : float = -(80.5 - 10.0) * FT   # -21.49
	var ew  : float = ex2 - ex1
	var el  : float = abs(ez2 - ez1)
	var ec  : float = 0.2032  # 8-inch concrete

	# Left wall
	_add_wall_box(parent, mat, Vector3(ec, 3.0, el),
				  Vector3(ex1, bs_y_bot+1.5, (ez1+ez2)*0.5))
	# Right wall
	_add_wall_box(parent, mat, Vector3(ec, 3.0, el),
				  Vector3(ex2, bs_y_bot+1.5, (ez1+ez2)*0.5))
	# Far end wall
	_add_wall_box(parent, mat, Vector3(ew, 3.0, ec),
				  Vector3((ex1+ex2)*0.5, bs_y_bot+1.5, ez2))

	# Concrete stair steps descending into basement (8 steps)
	const STEPS := 8
	var step_d : float = el / float(STEPS)
	var step_h : float = abs(bs_y_bot) / float(STEPS)
	for i in range(STEPS):
		var s  = CSGBox3D.new()
		s.name = "BilcoStep_%d" % i
		s.use_collision = true
		s.material = mat
		s.size     = Vector3(ew - ec, step_h * (i+1), step_d)
		s.position = Vector3((ex1+ex2)*0.5,
							 bs_y_bot + step_h*(i+1)*0.5,
							 ez1 - step_d*i - step_d*0.5)
		parent.add_child(s)

# ─────────────────────────────────────────────────────────────────────────────
# Spawn gameplay interactable trigger nodes (BreakerBox, Workbench, etc.)
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_interactable(parent: Node, cfg: Dictionary, y_bot: float) -> void:
	var itype : String = cfg.get("type", "")
	var ix    : float  = cfg.get("x", 0.0)
	var iz    : float  = cfg.get("z", 0.0)

	var node  = Area3D.new()
	node.name = itype

	var prompt := ""
	var box_sz := Vector3(0.5, 0.8, 0.3)
	var col    := Color(0.5, 0.5, 0.5)

	match itype:
		"BreakerBox":
			prompt = "Inspect Breaker Box"
			box_sz = Vector3(0.4, 0.6, 0.1)
			col    = Color(0.6, 0.05, 0.05)
		"Workbench":
			prompt = "Search Workbench"
			box_sz = Vector3(1.2, 0.85, 0.55)
			col    = Color(0.35, 0.22, 0.10)
		"CastIronBar":
			prompt = "Pick up Cast Iron Bar"
			box_sz = Vector3(0.08, 0.08, 0.75)
			col    = Color(0.20, 0.20, 0.20)
		"StorageShelf":
			prompt = "Search Shelf"
			box_sz = Vector3(1.0, 1.6, 0.35)
			col    = Color(0.35, 0.22, 0.10)
		"OccultAltar":
			prompt = "Examine Altar"
			box_sz = Vector3(0.9, 0.85, 0.55)
			col    = Color(0.15, 0.05, 0.20)

	# Try to load Interactable script for proper detection
	var script = load("res://Interactable.gd")
	if script:
		node.set_script(script)
		node.set("prompt_message", prompt)

	node.collision_layer = 4
	node.collision_mask  = 0
	node.position        = Vector3(ix, y_bot + box_sz.y * 0.5, iz)

	var mi   = MeshInstance3D.new()
	var bm   = BoxMesh.new()
	bm.size  = box_sz
	mi.mesh  = bm
	var m    = StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	node.add_child(mi)

	var cs  = CollisionShape3D.new()
	var bs  = BoxShape3D.new()
	bs.size = box_sz
	cs.shape = bs
	node.add_child(cs)
	parent.add_child(node)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────
func _setup_camera_env(yard_x: float, yard_z: float) -> void:
	var cam = get_node_or_null("Camera3D")
	if cam:
		cam.position = Vector3(yard_x*0.5, 18.0, 8.0)
		cam.look_at(Vector3(yard_x*0.5, 0.0, -yard_z*0.5), Vector3.UP)
		var light = cam.get_node_or_null("DirectionalLight3D")
		if light:
			light.global_rotation_degrees = Vector3(-50.0, 30.0, 0.0)
			light.light_energy   = 1.0
			light.shadow_enabled = true
	var env_node = get_node_or_null("WorldEnvironment")
	if not env_node:
		env_node      = WorldEnvironment.new()
		env_node.name = "WorldEnvironment"
		add_child(env_node)
	var env_res  = Environment.new()
	env_res.background_mode      = Environment.BG_SKY
	var sky      = Sky.new()
	sky.sky_material             = ProceduralSkyMaterial.new()
	env_res.sky                  = sky
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	env_res.ambient_light_energy = 0.4
	env_node.environment         = env_res

func _add_static_box(body_name: String, mat: Material, sz: Vector3, pos: Vector3) -> StaticBody3D:
	var body  = StaticBody3D.new()
	body.name = body_name
	var mi    = MeshInstance3D.new()
	var bm    = BoxMesh.new()
	bm.size   = sz
	mi.mesh   = bm
	mi.material_override = mat
	body.add_child(mi)
	var cs  = CollisionShape3D.new()
	var shp = BoxShape3D.new()
	shp.size = sz
	cs.shape = shp
	body.add_child(cs)
	body.position = pos
	add_child(body)
	return body

func _add_wall_box(parent: Node, mat: Material, sz: Vector3, pos: Vector3) -> void:
	var box           = CSGBox3D.new()
	box.use_collision = true
	box.material      = mat
	box.size          = sz
	box.position      = pos
	parent.add_child(box)

func _mat(path: String, fallback: Color) -> StandardMaterial3D:
	if ResourceLoader.exists(path):
		return load(path) as StandardMaterial3D
	var m = StandardMaterial3D.new()
	m.albedo_color = fallback
	return m

func _build_wall(p1: Vector2, p2: Vector2,
				 y_bot: float, height: float, thick: float,
				 parent: Node, mat: Material) -> void:
	var a   = Vector3(p1.x, 0.0, p1.y)
	var b   = Vector3(p2.x, 0.0, p2.y)
	var dir = b - a
	var len = dir.length()
	if len < 0.02:
		return
	var mid = (a + b) * 0.5
	var box           = CSGBox3D.new()
	box.use_collision = true
	box.material      = mat
	box.size          = Vector3(thick, height, len)
	box.position      = Vector3(mid.x, y_bot + height*0.5, mid.z)
	box.rotation.y    = atan2(dir.x, dir.z)
	parent.add_child(box)

func _build_stairs(x: float, z: float, width: float, length: float,
				   y_start: float, y_end: float,
				   direction: Array, parent: Node, mat: Material) -> void:
	const STEPS := 14
	var step_d : float = length / float(STEPS)
	var step_h : float = abs(y_end - y_start) / float(STEPS)
	var dx     : float = float(direction[0])
	var dz     : float = float(direction[1])
	for i in range(STEPS):
		var s           = CSGBox3D.new()
		s.use_collision = true
		s.material      = mat
		s.size          = Vector3(width, step_h * (i+1), step_d)
		var offset      = i * step_d + step_d*0.5 - length*0.5
		s.position      = Vector3(x + dx*offset,
								  y_start + step_h*(i+1)*0.5,
								  z + dz*offset)
		parent.add_child(s)

func _spawn_container(parent: Node, c_name: String,
					  px: float, py: float, pz: float,
					  box_size: Vector3, open_rot: Vector3) -> void:
	var script = load("res://SearchableContainer.gd")
	if not script:
		return
	var node = Area3D.new()
	node.set_script(script)
	node.name     = c_name
	node.position = Vector3(px, py, pz)
	node.set("open_rotation_offset", open_rot)
	node.set("prompt_message", "Search " + c_name.replace("_"," "))
	var mi  = MeshInstance3D.new()
	var bm  = BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	var m   = StandardMaterial3D.new()
	m.albedo_color = Color(0.28, 0.14, 0.06)
	mi.material_override = m
	node.add_child(mi)
	var cs  = CollisionShape3D.new()
	var bs  = BoxShape3D.new()
	bs.size = box_size
	cs.shape = bs
	node.add_child(cs)
	parent.add_child(node)
