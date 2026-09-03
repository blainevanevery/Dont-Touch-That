import numpy as np
from PIL import Image
import math

size = 1024
num_slats = 8 # 8 horizontal siding panels
pixels_per_slat = size // num_slats

# Normal map
normal = np.zeros((size, size, 3), dtype=np.uint8)
normal[:, :, 2] = 255 # Z channel (Blue) defaults to straight up

for y in range(size):
    slat_y = y % pixels_per_slat
    # Siding profile: mostly flat with a slight angle, then a sharp tuck at the bottom
    # We'll map this to a normal vector.
    # From top to bottom (0 to pixels_per_slat):
    # Top 90%: gentle slope outwards (pointing slightly up/down depending on orientation)
    # Bottom 10%: sharp tuck inwards
    
    progress = slat_y / pixels_per_slat
    
    if progress < 0.85:
        # flat, slightly angled down to catch light
        ny = 0.1 # slightly pointing down (or up, depending on godot Y-up/down)
    else:
        # sharp bevel tucking back in
        ny = -0.8
        
    # Normalize with Z
    nz = math.sqrt(1.0 - ny*ny)
    
    # Convert to 0-255 RGB
    # R (X) = 128 (no horizontal slope)
    # G (Y) = mapped from -1..1 to 0..255 (Godot uses Y+ up or Y- down, we can try Y+)
    # B (Z) = mapped from 0..1 to 128..255
    r = 128
    g = int((ny + 1.0) * 127.5)
    b = int((nz + 1.0) * 127.5)
    
    normal[y, :, 0] = r
    normal[y, :, 1] = g
    normal[y, :, 2] = b

img_normal = Image.fromarray(normal)
img_normal.save("vinyl_siding_normal.png")

# Albedo (just a base color we can tint, maybe some ambient occlusion)
albedo = np.zeros((size, size, 3), dtype=np.uint8)
albedo.fill(240) # Off-white base

for y in range(size):
    slat_y = y % pixels_per_slat
    progress = slat_y / pixels_per_slat
    
    ao = 1.0
    if progress > 0.85:
        ao = 1.0 - ((progress - 0.85) / 0.15)
        ao = max(0.2, ao)
    elif progress < 0.05:
        ao = 0.5 + (progress / 0.05) * 0.5
        
    albedo[y, :, :] = int(240 * ao)

img_albedo = Image.fromarray(albedo)
img_albedo.save("vinyl_siding_albedo.png")

print("Generated vinyl_siding_normal.png and vinyl_siding_albedo.png")
