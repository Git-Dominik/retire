"""MSH_Light_DomeSconce_B: cut-corner oak plate, round iron boss, hexagonal iron arm that rises
and hooks down into a collar on a low copper dome, pull-switch stub, faceted glowing bulb.
Wall at y = 0, fixture reaches toward -Y, pivot = back centre of the plate."""

import math

from mathutils import Vector

import doors_toolkit as tk

PLATE_W, PLATE_H, PLATE_T, PLATE_CUT = 0.95, 1.6, 0.26, 0.18
ARM_Z = -0.15  # arm leaves the lower half of the plate
ARM_R = 0.09
DOME_R, DOME_H = 0.75, 0.56
BRIM_R, BRIM_T = 0.83, 0.06
COLLAR_R, COLLAR_Z0, COLLAR_Z1 = 0.14, 0.50, 0.69  # above the brim; bottom sunk into the dome
ARM_BURY = 0.09

PALETTE = {
	"plate": ("#4A3024", "Wood"),
	"boss": ("#3A2D28", "Metal"),
	"arm": ("#3A2D28", "Metal"),
	"collar": ("#3A2D28", "Metal"),
	"switch": ("#3A2D28", "Metal"),
	"shade": ("#A8714F", "Metal"),
	"brim": ("#A8714F", "Metal"),
	"bulb": ("#FFD58A", "Neon"),
}
# exported regions: the iron pieces share one MeshPart
REGIONS = {"boss": "iron", "arm": "iron", "collar": "iron", "switch": "iron", "plate": "wood"}
JOINTS = [  # (part, host, allowed bury depth)
	("boss", "plate", 0.03),
	("arm", "boss", 0.13),
	("arm", "collar", ARM_BURY + 0.02),
	("collar", "shade", 0.05),
	("switch", "collar", 0.07),
	("shade", "brim", 0.03),
	("bulb", "brim", 0.02),
	("arm", "plate", 0.004),
	("arm", "shade", 0.004),
]


def arm_path():
	return tk.turtle((0, -0.30, ARM_Z), (0, -1, 0), (1, 0, 0), [
		("f", 0.2), ("t", -45), ("f", 0.8), ("t", 45), ("f", 0.15), ("t", 45), ("f", 0.12),
		("t", 45), ("f", 0.15),
	])


def out_of_wall(m, tag, profile, center):
	"""Lathe about +Z, then tip it so its axis points out of the wall (-Y)."""
	tmp = tk.Mesh()
	tk.lathe(tmp, profile, tag)
	vs, fs = tmp.parts[tag]
	cx, cy, cz = center
	m.add(tag, [(v.x + cx, -v.z + cy, v.y + cz) for v in vs], fs)


def build():
	pts = arm_path()
	shade_y = pts[-1].y
	brim_z = pts[-1].z + ARM_BURY - COLLAR_Z1
	m = tk.Mesh()
	tk.slab(m, tk.oct_poly(PLATE_W, PLATE_H, PLATE_CUT), 0.0, PLATE_T, "plate", c=0.04)
	out_of_wall(m, "boss", [(0.2, 0.0), (0.2, 0.13), (0.17, 0.16)], (0, -PLATE_T + 0.02, ARM_Z))
	tk.tube(m, pts, ARM_R, "arm")
	c = (0, shade_y, brim_z)
	# dome: 5 evenly spaced rings from just inside the brim to the pole
	prof = [(DOME_R * math.cos(math.radians(a)), DOME_H * math.sin(math.radians(a)))
			for a in (0, 22.5, 45, 67.5, 90)]
	prof[0] = (DOME_R, -0.02)
	tk.lathe(m, prof, "shade", center=c)
	tk.lathe(m, [(BRIM_R, -BRIM_T), (BRIM_R, 0.0)], "brim", center=c)
	tk.lathe(m, [(COLLAR_R, COLLAR_Z0), (COLLAR_R, COLLAR_Z1 - 0.03), (COLLAR_R - 0.03, COLLAR_Z1)],
			 "collar", center=c)
	sz = brim_z + (COLLAR_Z0 + COLLAR_Z1) / 2 - 0.02
	tk.tube(m, [Vector((0.08, shade_y, sz)), Vector((0.24, shade_y, sz))], 0.045, "switch",
			axis=(0, 1, 0))
	# bulb: top ring tucked 0.01 into the brim's underside
	tk.lathe(m, [(0.16, -0.05), (0.27, -0.16), (0.27, -0.29), (0.15, -0.41)], "bulb", center=c)
	return m
