"""Flowerpot (Doors asset guide v24): a brown octagonal pot holding a tall, thin snake-plant fan.

Run inside Blender (MCP execute). Builds with assets/WallLights/doors_toolkit.py, exports
assets/flowerpot/Flowerpot.fbx + hand-off, and copies the FBX to assets/factory_fbx/.
Blender axes: front = -Y, up = +Z, 1 unit = 1 stud, pivot bottom centre.
One mesh per value region coloured by Part.Color (no vertex colour in the FBX); the pot is crisp,
the soil and leaves organic. A COL_Pot helper box collides; the meshes don't.
"""

import math
import os
import random
import shutil
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = "/home/omar/retire/assets"
sys.path.insert(0, ROOT + "/WallLights")
import doors_toolkit as tk  # noqa: E402

OUT = ROOT + "/flowerpot"
FOOT_TOP = 0.18
RIM = (1.62, 1.95)  # rim band bottom / top
RIM_R, WELL_R = 1.0, 0.88  # rim outer and well inner half flat-to-flat
SOIL_Z = 1.80  # soil surface at the edge, 0.15 below the rim
LEAVES = 11
SEED = 7

REGIONS = {
	"foot": "foot", "body": "body", "rim": "rim", "soil": "soil",
	"leaves_dark": "leaves_dark", "leaves_light": "leaves_light",
}
PALETTE = {
	"foot": ("#4A3226", "Plastic"),
	"body": ("#7A5038", "Plastic"),
	"rim": ("#94664A", "Plastic"),
	"soil": ("#3A2E26", "Ground"),
	"leaves_dark": ("#4F6A34", "LeafyGrass"),
	"leaves_light": ("#71873F", "LeafyGrass"),
}


def blade(m, tag, base, height, width, lean, heading, twist, rng):
	"""One folded leaf: a thin diamond section swept up a gently bending spine to a point.
	heading is the lean direction in plan; the blade's flat faces it, so it fans outward."""
	fracs = (0.0, 0.35, 0.7)
	widths = (1.0, 1.08, 0.72)
	thick = 0.055
	out = Vector((math.cos(heading), math.sin(heading), 0))
	side = Vector((-out.y, out.x, 0))
	verts, rings = [], []
	pos = Vector(base)
	prev = 0.0
	for i, f in enumerate(fracs + (1.0,)):
		# Lean grows toward the tip (organic droop), small steps so no joint folds back
		ang = math.radians(lean * (0.6 + 0.8 * f))
		d = (out * math.sin(ang) + Vector((0, 0, math.cos(ang))))
		pos = pos + d * (height * (f - prev))
		prev = f
		if f >= 1.0:
			verts.append(pos.copy())
			rings.append([len(verts) - 1])
			break
		rot = Matrix.Rotation(math.radians(twist * f), 3, d)
		w = width * widths[i] * rng.uniform(0.92, 1.08)
		ws, ts = rot @ (side * w), rot @ (out * thick)
		ring = []
		for p in (pos + ws, pos + ts, pos - ws, pos - ts):
			ring.append(len(verts))
			verts.append(p.copy())
		rings.append(ring)
	faces = [tuple(reversed(rings[0]))]
	for a, b in zip(rings, rings[1:]):
		if len(b) == 1:
			faces += [(a[k], a[(k + 1) % 4], b[0]) for k in range(4)]
		else:
			faces += [(a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]) for k in range(4)]
	tk._fix_winding(verts, faces)
	m.add(tag, verts, faces)


def pot(m, rng):
	"""The pot and its soil, shared with flowerpot_bush.py. Leaves sit on SOIL_Z."""
	# Pot: dark foot, mid body flaring out, lighter rim band with the soil well inside
	tk.lathe(m, [(0.78, 0.0), (0.78, FOOT_TOP)], "foot")
	tk.lathe(m, [(0.68, FOOT_TOP), (0.92, RIM[0])], "body")
	tk.lathe(m, [(RIM_R, RIM[0]), (RIM_R, RIM[1]), (WELL_R, RIM[1]), (WELL_R, 1.70), (0, 1.70)], "rim")
	# Soil: a low ragged mound just below the rim, side tucked inside the well
	soil = tk.Mesh()
	tk.lathe(soil, [(WELL_R - 0.01, 1.70), (WELL_R - 0.01, SOIL_Z), (0.5, SOIL_Z + 0.06), (0, SOIL_Z + 0.08)], "soil")
	vs = soil.parts["soil"][0]
	for v in vs:
		if v.z > SOIL_Z - 0.01:
			v.z += rng.uniform(-0.025, 0.025)
	m.add("soil", *soil.parts["soil"])


def build():
	m = tk.Mesh()
	rng = random.Random(SEED)
	pot(m, rng)
	# Leaves: tall outer blades lean out, short inner ones stand up; two greens alternate
	for i in range(LEAVES):
		heading = 2 * math.pi * i / LEAVES + rng.uniform(-0.25, 0.25)
		inner = i % 3 == 0
		r = rng.uniform(0.08, 0.2) if inner else rng.uniform(0.25, 0.45)
		base = (r * math.cos(heading), r * math.sin(heading), SOIL_Z - 0.12)
		height = rng.uniform(3.1, 3.7) if inner else rng.uniform(2.4, 3.3)
		lean = rng.uniform(2, 6) if inner else rng.uniform(8, 16)
		tag = "leaves_light" if i % 2 else "leaves_dark"
		blade(m, tag, base, height, rng.uniform(0.12, 0.15), lean, heading, rng.uniform(-25, 25), rng)
	return m


CLIP_PAIRS = [("foot", "body"), ("body", "rim"), ("soil", "rim")]


def helper_luau():
	return (
		"\n-- Collision helper (guide 9.2): an invisible anchored box round the pot; the meshes don't collide.\n"
		'for _, root in game:GetService("Selection"):Get() do\n'
		'\tif root:IsA("Model") then\n'
		"\t\tlocal cf, size = root:GetBoundingBox()\n"
		"\t\tlocal base = cf * CFrame.new(0, -size.Y / 2, 0)\n"
		"\t\troot.WorldPivot = base\n"
		'\t\tlocal old = root:FindFirstChild("COL_Pot")\n'
		"\t\tif old then\n"
		"\t\t\told:Destroy()\n"
		"\t\tend\n"
		'\t\tlocal p = Instance.new("Part")\n'
		f'\t\tp.Name, p.Size = "COL_Pot", Vector3.new({2 * RIM_R:.2f}, {RIM[1]:.2f}, {2 * RIM_R:.2f})\n'
		f"\t\tp.CFrame = base * CFrame.new(0, {RIM[1] / 2:.3f}, 0)\n"
		"\t\tp.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false\n"
		"\t\tp.Transparency, p.CastShadow = 1, false\n"
		"\t\tp.Parent = root\n"
		"\tend\n"
		"end\n"
	)


def run(name="Flowerpot", build_fn=build, palette=PALETTE, regions=REGIONS, location=(0, 0, 0),
		organic=("soil", "leaves_dark", "leaves_light"), soft=()):
	for ob in [o for o in bpy.data.objects if o.name == name or o.name.startswith(name + "_")]:
		bpy.data.objects.remove(ob, do_unlink=True)
	m = build_fn()
	audits = {"mesh": tk.audit_mesh(m, soft_tags=soft, organic_tags=organic), "clip": tk.audit_clipping(m, CLIP_PAIRS)}
	merged = m.retag(regions)
	st = tk.stats(merged)
	group, parts = tk.to_blender(name, merged, palette, location=location, smooth_tags=soft)
	audits["style"] = tk.audit_style(parts, soft_tags=soft)
	return st, audits, group, parts


def export(group, parts, tris, name="Flowerpot", out=OUT, what="flowerpot"):
	os.makedirs(out, exist_ok=True)
	fbx = tk.export_fbx(f"{out}/{name}.fbx", group, colors_type="NONE")
	tk.write_handoff(out, name, parts, attributes={"Biome": "Manor", "Interactable": False},
					 note=f"Doors guide v24 {what}, {tris} tris. Pivot bottom centre, front -Z. "
					 "Colour is Part.Color (no vertex colour in the FBX). COL_Pot collides.",
					 part_color=True)
	with open(f"{out}/{name}_apply_materials.luau", "a") as f:
		f.write(helper_luau())
	shutil.copy(fbx, f"{ROOT}/factory_fbx/{name}.fbx")
	return fbx
