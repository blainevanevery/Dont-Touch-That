import xml.etree.ElementTree as ET
import json
import re

FT_TO_M = 0.3048

def parse_svg(svg_path, floor_num):
	tree = ET.parse(svg_path)
	root = tree.getroot()
	ns = {'svg': 'http://www.w3.org/2000/svg'}
	
	view_box_str = root.get('viewBox', '')
	vb_min_x, vb_min_y, vb_w, vb_h = -5.0, -15.0, 55.0, 145.0
	if view_box_str:
		parts = [float(p) for p in view_box_str.split()]
		if len(parts) == 4:
			vb_min_x, vb_min_y, vb_w, vb_h = parts

	rooms = []
	walls = []
	doors = []
	windows = []
	stairs = []
	porches = []
	interactables = []
	
	# Unified Site Transform & Coordinate Mapping:
	# Site Origin (0,0) in SVG is Property Line Front-Left corner (45x120 lot).
	# All blueprints (yard, basement, 1st floor, 2nd floor) share the same site grid:
	#   House Footprint: X = 1.5 to 26.5 (25' wide), Y = 39.0 to 110.0 (71' long)
	#   Main House Base (Local 0,0 relative to house footprint): X = 1.5, Y = 39.0 (Back-Left corner)
	#
	# In Godot 3D World Coordinates (1 unit = 1 meter):
	#   Site Lot: X in [0.0, 13.716m], Z in [0.0, -36.576m] (0 = rear lot line, -36.576 = front street line)
	#   House Footprint: X in [0.4572m, 8.0772m], Z in [-11.8872m, -33.528m]
	#
	# Conversion helper (Site SVG -> Site Godot 3D relative to House Base):
	#   godot_x = (x_svg - 1.5) * 0.3048
	#   godot_z = -(y_svg - 39.0) * 0.3048
	def to_godot_x(x_svg):
		return (x_svg - 1.5) * FT_TO_M
		
	def to_godot_z(y_svg):
		return -(y_svg - 39.0) * FT_TO_M

	# 1. Parse <rect> elements
	for rect in root.findall('.//svg:rect', ns):
		stroke = rect.get('stroke', '')
		fill = rect.get('fill', '')
		stroke_w = rect.get('stroke-width', '')
		x = float(rect.get('x', 0))
		y = float(rect.get('y', 0))
		w = float(rect.get('width', 0))
		h = float(rect.get('height', 0))
		
		# Ignore outer property line rect
		if w >= 40 and h >= 100:
			continue

		# Main Exterior Boundary Shell (House 25x71)
		if (stroke in ['#4da6ff', '#00e5ff']) and w >= 20 and h >= 60:
			th = 0.2032 if floor_num == 0 else 0.1524
			walls.append({"start": [to_godot_x(x), to_godot_z(y)], "end": [to_godot_x(x), to_godot_z(y + h)], "thickness": th})
			walls.append({"start": [to_godot_x(x + w), to_godot_z(y)], "end": [to_godot_x(x + w), to_godot_z(y + h)], "thickness": th})
			walls.append({"start": [to_godot_x(x), to_godot_z(y)], "end": [to_godot_x(x + w), to_godot_z(y)], "thickness": th})
			walls.append({"start": [to_godot_x(x), to_godot_z(y + h)], "end": [to_godot_x(x + w), to_godot_z(y + h)], "thickness": th})
		
		# Windows (<rect ... fill='#00e5ff'>)
		elif fill == '#00e5ff' and w < 10:
			cx = x + w / 2.0
			cy = y + h / 2.0
			is_horiz = w >= h
			rot = 0.0 if is_horiz else 90.0
			windows.append({
				"x": round(to_godot_x(cx), 4),
				"z": round(to_godot_z(cy), 4),
				"y_offset": 2.1 if floor_num == 0 else 0.9,
				"width": round(max(w, h) * FT_TO_M, 4),
				"height": 0.4 if floor_num == 0 else 1.2,
				"rotation": rot
			})
			
		# Porch Decks (e.g. Raised Back Porch, Front Porch)
		elif (stroke in ['#00e5ff', '#4da6ff']) and fill == '#14243b' and w < 20:
			porches.append({
				"x": round(to_godot_x(x + w / 2.0), 4),
				"z": round(to_godot_z(y + h / 2.0), 4),
				"width": round(w * FT_TO_M, 4),
				"depth": round(h * FT_TO_M, 4),
				"is_raised": (y < 39.0)
			})

		# Exterior Driveway Stairs (rect fill='#0a1424')
		elif y < 39.0 and fill == '#0a1424':
			stairs.append({
				"x": round(to_godot_x(x + w / 2.0), 4),
				"z": round(to_godot_z(y + h / 2.0), 4),
				"width": round(w * FT_TO_M, 4),
				"length": round(h * FT_TO_M, 4),
				"direction": [1.0, 0.0],
				"is_exterior": True
			})

		# Interior Partition Wall Enclosures (stroke-width=0.33)
		elif stroke == '#ffffff' and stroke_w == '0.33':
			walls.append({"start": [to_godot_x(x), to_godot_z(y)], "end": [to_godot_x(x), to_godot_z(y + h)], "thickness": 0.1016})
			walls.append({"start": [to_godot_x(x + w), to_godot_z(y)], "end": [to_godot_x(x + w), to_godot_z(y + h)], "thickness": 0.1016})
			walls.append({"start": [to_godot_x(x), to_godot_z(y)], "end": [to_godot_x(x + w), to_godot_z(y)], "thickness": 0.1016})
			walls.append({"start": [to_godot_x(x), to_godot_z(y + h)], "end": [to_godot_x(x + w), to_godot_z(y + h)], "thickness": 0.1016})

	# 2. Parse <line> elements
	for line in root.findall('.//svg:line', ns):
		stroke = line.get('stroke', '')
		stroke_w = line.get('stroke-width', '')
		if stroke == '#ffffff' and stroke_w == '0.33':
			x1, y1 = float(line.get('x1')), float(line.get('y1'))
			x2, y2 = float(line.get('x2')), float(line.get('y2'))
			if x1 < -1.0 or x2 < -1.0 or y1 > 125.0 or y2 > 125.0:
				continue
			walls.append({
				"start": [round(to_godot_x(x1), 4), round(to_godot_z(y1), 4)],
				"end": [round(to_godot_x(x2), 4), round(to_godot_z(y2), 4)],
				"thickness": 0.1016
			})

	# 3. Parse <path> elements (Door swings)
	for path in root.findall('.//svg:path', ns):
		stroke = path.get('stroke', '')
		d = path.get('d', '')
		if stroke == '#00ff66':
			nums = [float(n) for n in re.findall(r"[-+]?\d*\.\d+|\d+", d)]
			if len(nums) >= 4:
				x1, y1, x2, y2 = nums[0], nums[1], nums[2], nums[3]
				cx = (x1 + x2) / 2.0
				cy = (y1 + y2) / 2.0
				is_horiz = abs(y2 - y1) < 0.1
				rot = 0.0 if is_horiz else 90.0
				door_obj = {
					"x": round(to_godot_x(cx), 4),
					"z": round(to_godot_z(cy), 4),
					"width": 0.9,
					"height": 2.1,
					"rotation": rot
				}
				if floor_num == 0 and cy <= 39.0:
					door_obj["requires_key"] = "key3"
				doors.append(door_obj)

	# 4. Parse <text> elements
	for text in root.findall('.//svg:text', ns):
		val = text.text
		if not val:
			continue
		tx = float(text.get('x', 0))
		ty = float(text.get('y', 0))
		if ty < 0.0 or ty > 125.0:
			continue
		rooms.append({
			"name": val,
			"x": round(to_godot_x(tx), 4),
			"z": round(to_godot_z(ty), 4),
			"width": 3.0,
			"depth": 3.0
		})

	if floor_num == 0:
		stairs.append({
			"x": round(to_godot_x(14.0), 4),
			"z": round(to_godot_z(36.0), 4),
			"width": round(5.0 * FT_TO_M, 4),
			"length": round(6.0 * FT_TO_M, 4),
			"direction": [0.0, -1.0],
			"is_exterior": True
		})
		interactables = [
			{"type": "BreakerBox",   "x": round(to_godot_x(25.8), 4), "z": round(to_godot_z(41.0), 4), "room": "Utility/Breaker"},
			{"type": "Workbench",    "x": round(to_godot_x(3.5), 4),  "z": round(to_godot_z(43.0), 4), "room": "Workshop/Tool Storage"},
			{"type": "CastIronBar",  "x": round(to_godot_x(5.5), 4),  "z": round(to_godot_z(49.0), 4), "room": "Workshop/Tool Storage"},
			{"type": "StorageShelf", "x": round(to_godot_x(3.5), 4),  "z": round(to_godot_z(64.0), 4), "room": "Storage Cellar"},
			{"type": "OccultAltar",  "x": round(to_godot_x(6.5), 4),  "z": round(to_godot_z(91.0), 4), "room": "Cold Vault"}
		]
	elif floor_num == 1:
		stairs.append({"x": round(to_godot_x(5.25), 4), "z": round(to_godot_z(43.5), 4), "width": 1.5, "length": 3.0, "direction": [0.0, 1.0]})
		stairs.append({"x": round(to_godot_x(4.75), 4), "z": round(to_godot_z(92.75), 4), "width": 1.5, "length": 3.0, "direction": [0.0, -1.0]})

	res = {
		"floor_number": floor_num,
		"view_box": [vb_min_x, vb_min_y, vb_w, vb_h],
		"rooms": rooms,
		"walls": walls,
		"doors": doors,
		"windows": windows,
		"stairs": stairs,
		"porches": porches
	}
	if floor_num == 0:
		res["y_base"] = -2.4384  # EL -8.0 ft
		res["interactables"] = interactables

	return res

basement = parse_svg("/home/blaine/dont-touch-that/blueprints/basement_foundation_plan.svg", 0)
floor1   = parse_svg("/home/blaine/dont-touch-that/blueprints/1st_floor_plan.svg", 1)
floor2   = parse_svg("/home/blaine/dont-touch-that/blueprints/2nd_floor_plan.svg", 2)

layout = {
	"dimensions": {
		"yard": [36.576, 13.716],
		"house": [21.6408, 7.62],
		"wall_height": 3.048,   # 10 ft walls
		"wall_thickness": 0.1016,
		"house_offset": [0.4572, 0.0, -11.8872], # House footprint base at X: 1.5', Y: 39.0'
		"driveway": {"x_start": 9.4488, "x_end": 13.1064, "z_start": -10.3632, "z_end": -36.576, "height": 0.05},
		"terrain": {"flat_z_end": -10.3632, "slope_z_end": -36.576, "slope_y_drop": -2.4384}, # EL 0.0 to EL -8.0 ft
		"basement": {"y_bottom": -2.4384, "y_top": 0.0, "wall_thickness": 0.2032}
	},
	"floors": [basement, floor1, floor2]
}

with open("/home/blaine/dont-touch-that/house_layout.json", "w") as f:
	json.dump(layout, f, indent=2)

print("Regenerated house_layout.json using site-aligned SVG blueprints!")
