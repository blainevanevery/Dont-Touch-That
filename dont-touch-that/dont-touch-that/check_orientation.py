import json

with open("house_layout.json") as f:
    data = json.load(f)

print("Dimensions:", data.get("dimensions"))
for fl in data.get("floors", []):
    print(f"\nFloor {fl.get('floor_number')}:")
    print("  Rooms:")
    for r in fl.get("rooms", []):
        print(f"    - {r.get('name')}: x={r.get('x')}, z={r.get('z')}, w={r.get('width')}, d={r.get('depth')}")
