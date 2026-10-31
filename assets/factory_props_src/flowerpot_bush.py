"""Leafy flowerpot (Doors asset guide v24): flowerpot.py's brown pot holding a mini tree, a short
hex trunk carrying a cylindrical canopy, instead of the snake-plant fan.

Run inside Blender (MCP execute). Exports assets/flowerpot_bush/FlowerpotBush.fbx + hand-off and
copies the FBX to assets/factory_fbx/. Same axes, pivot and colour rules as flowerpot.py.
The canopy is one foliage mass, not separate leaves: stacked 8-sided rings, each turned half a step
from the one below, tapering from a wide base to a narrow rounded top. Few rings and flat shading
keep the facets large and the edges crisp. Sides and top are one mesh, the underside a darker one.
"""

import math
import random
import sys

from mathutils import Vector

sys.path.insert(0, "/home/omar/retire/assets/factory_props_src")
import flowerpot as fp  # noqa: E402

tk = fp.tk
OUT = fp.ROOT + "/flowerpot_bush"
NAME = "FlowerpotBush"
SEED = 11
SIDES = 8
TRUNK_R = 0.1
CANOPY_Z0 = fp.SOIL_Z + 0.5  # canopy bottom; ~0.45 of trunk shows above the soil
SCALE = 1.12  # canopy size; rings below are at 1.0
# Canopy rings (radius, height above CANOPY_Z0): tucked under, widest low, tapering to a round top
RINGS = [(0.82, 0.0), (1.12, 0.4), (1.02, 1.4), (0.8, 2.35), (0.48, 2.95)]
APEX = 3.2
JITTER = 0.02  # radial jitter, fraction of the ring radius; small so the facets stay even

REGIONS = dict(fp.REGIONS, trunk="trunk", canopy="canopy", canopy_under="canopy_under")
PALETTE = dict(
	fp.PALETTE,
	trunk=("#4A3426", "Wood"),
	canopy_under=("#26321E", "LeafyGrass"),
	canopy=("#3A4E2C", "LeafyGrass"),
)
ORGANIC = ("soil", "canopy", "canopy_under")


def canopy(m, rng):
	rings = []
	for i, (r, h) in enumerate(RINGS):
		r, h = r * SCALE, h * SCALE
		end = i in (0, len(RINGS) - 1)
		ring = []
		for k in range(SIDES):
			a = 2 * math.pi * (k + 0.5 * i) / SIDES + rng.uniform(-0.03, 0.03)
			rr = r * (1 + rng.uniform(-JITTER, JITTER))
			z = CANOPY_Z0 + h + (0 if end else rng.uniform(-0.02, 0.02))
			ring.append(Vector((rr * math.cos(a), rr * math.sin(a), z)))
		rings.append(ring)
	# Sides: each ring sits half a step round from the one below, so each band is a triangle strip
	verts = [v for ring in rings for v in ring]
	faces = []
	for i in range(len(rings) - 1):
		a, b = i * SIDES, (i + 1) * SIDES
		for k in range(SIDES):
			k1 = (k + 1) % SIDES
			faces += [(a + k, a + k1, b + k), (b + k, a + k1, b + k1)]
	# Top: a fan to the apex in the same mesh, sharing the top ring so the smoothing is unbroken
	top = (len(rings) - 1) * SIDES
	verts.append(Vector((0, 0, CANOPY_Z0 + APEX * SCALE)))
	faces += [(top + k, top + (k + 1) % SIDES, len(verts) - 1) for k in range(SIDES)]
	m.add("canopy", verts, faces)
	# Underside: its own darker fan to a centre point
	low = rings[0]
	centre = Vector((0, 0, CANOPY_Z0 + 0.08))
	m.add("canopy_under", low + [centre], [((k + 1) % SIDES, k, SIDES) for k in range(SIDES)])


def build():
	m = tk.Mesh()
	rng = random.Random(SEED)
	fp.pot(m, rng)
	# Trunk: a plain hex stick, its ends buried in the soil and in the canopy
	tk.tube(m, [(0, 0, fp.SOIL_Z - 0.08), (0, 0, CANOPY_Z0 + 0.4)], TRUNK_R, "trunk", axis=(1, 0, 0))
	canopy(m, rng)
	return m


def run(location=(0, 0, 0)):
	return fp.run(NAME, build, PALETTE, REGIONS, location=location, organic=ORGANIC)


def export(group, parts, tris):
	return fp.export(group, parts, tris, name=NAME, out=OUT, what="leafy flowerpot")
