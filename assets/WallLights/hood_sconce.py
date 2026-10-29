"""MSH_Light_HoodSconce_A: wood plate, hexagonal swan-neck arm, copper dome shade, glowing bulb.
Wall at y = 0, fixture reaches toward -Y, pivot = back centre of the plate."""

import math

import doors_toolkit as tk

PLATE_W, PLATE_H, PLATE_T = 1.0, 1.85, 0.26
SHADE_Y, BRIM_Z = -1.42, -0.25
DOME_R, DOME_H = 0.66, 0.60
BRIM_R, BRIM_T = 0.74, 0.06
ARM_R = 0.11

PALETTE = {
	"plate": ("#4A3024", "Wood"),
	"boss": ("#4A3024", "Wood"),
	"arm": ("#4A3024", "Wood"),
	"shade": ("#B98368", "Metal"),
	"brim": ("#B98368", "Metal"),
	"bulb": ("#FFD58A", "Neon"),
}
REGIONS = {"plate": "wood", "boss": "wood", "arm": "wood"}


def arm_path():
	return tk.turtle((0, -0.33, -0.25), (0, -1, 0), (1, 0, 0), [
		("f", 0.12), ("t", -45), ("f", 1.1), ("t", 45), ("f", 0.08), ("t", 45), ("f", 0.54),
	])


def build():
	m = tk.Mesh()
	tk.slab(m, tk.oct_poly(PLATE_W, PLATE_H, 0.25), 0.0, PLATE_T, "plate", c=0.04)
	tk.chamfer_box(m, (-0.17, -0.42, -0.42), (0.17, -0.24, -0.08), 0.03, "boss")
	tk.tube(m, arm_path(), ARM_R, "arm")
	# dome: 5 evenly spaced rings from the brim to the pole
	prof = [(DOME_R * math.cos(math.radians(a)), DOME_H * math.sin(math.radians(a)))
			for a in (0, 22.5, 45, 67.5, 90)]
	tk.lathe(m, prof, "shade", center=(0, SHADE_Y, BRIM_Z))
	tk.lathe(m, [(BRIM_R, -BRIM_T), (BRIM_R, 0.0)], "brim", center=(0, SHADE_Y, BRIM_Z))
	# bulb: top ring tucked 0.01 into the brim's underside
	tk.lathe(m, [(0.19, -0.58), (0.30, -0.47), (0.30, -0.40), (0.20, -0.30)],
			 "bulb", center=(0, SHADE_Y, 0))
	return m
