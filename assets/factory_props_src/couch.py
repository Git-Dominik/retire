"""Couch (Doors asset guide v24): a two-seat upholstered couch for the store.

Run inside Blender (MCP execute). Builds with assets/WallLights/doors_toolkit.py, exports
assets/couch/Couch.fbx + hand-off, and copies the FBX to assets/factory_fbx/.
Blender axes: front = -Y, up = +Z, 1 unit = 1 stud, pivot bottom centre (bbox centred in x/y).
v24: 8.5 x 5 x ~4.2 (measured sofa), one mesh per value region coloured by Part.Color (no vertex
colour in the FBX), cloth in Sand, pale studs as the value accent, COL_ helper parts for collision.
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

OUT = ROOT + "/couch"
LEAN = 10  # back lean, degrees
LIP_TOP = 1.24
SEAT_TOP = 2.04
BACK_Y = (1.0, 1.45)  # back frame front/rear, before the lean
PAD_FRONT = 0.6  # back pad face, before the lean
LEAN_PIVOT = (BACK_Y[1], LIP_TOP)  # (y, z) the back rocks about: its rear foot on the lip
ARM_R, ARM_ZC, ARM_XC = 0.78, 2.46, 3.33  # roll radius, axis height, axis |x|
SCROLL_R, SCROLL_DX = 0.86, 0.06
FRONT, BACK = -1.9, 1.6  # arm roll front/back y

# Value regions -> meshes (Sec 10.1): tags built separately for the audits, merged on export
REGIONS = {
	"feet": "feet",
	"apron": "frame", "back_frame": "frame", "arm_strip": "frame",
	"lip": "trim", "crest": "trim", "arm_button": "trim",
	"studs": "studs",
	"arm_body": "upholstery", "arm_roll": "upholstery", "arm_scroll": "upholstery",
	"back_pad": "padding", "cushion_l": "padding", "cushion_r": "padding",
	"pillow_l": "pillows", "pillow_r": "pillows",
	"tufts": "tufts",
}
PALETTE = {
	"feet": ("#362D28", "Wood"),
	"frame": ("#4A3E35", "Wood"),
	"trim": ("#6A584A", "Wood"),
	"studs": ("#C0B9AE", "Metal"),
	"upholstery": ("#8A6656", "Sand"),
	"padding": ("#A07D6A", "Sand"),
	"pillows": ("#A8845A", "Sand"),
	"tufts": ("#7A5E40", "Sand"),
}


def plan_frame(u, v, w):
	"""Plan polygon (x, y) extruded up z."""
	return Vector((u, v, w))


def transform(m, tag, mat, start=0):
	vs = m.parts[tag][0]
	for i in range(start, len(vs)):
		vs[i] = mat @ vs[i]


def lean_matrix():
	y0, z0 = LEAN_PIVOT
	return (Matrix.Translation((0, y0, z0)) @ Matrix.Rotation(math.radians(-LEAN), 4, "X")
			@ Matrix.Translation((0, -y0, -z0)))


def disc(m, tag, r, h, mat, back_cap=False):
	"""Flat octagonal disc built on +Z, then placed by mat; the back cap is dropped (it sits on a face)."""
	start = len(m.parts.get(tag, [[], []])[0])
	tk.lathe(m, [(r, 0), (r, h)], tag, cap_bottom=back_cap)
	transform(m, tag, mat, start)


# Disc axis +Z -> -Y (facing the front)
FACE_FRONT = Matrix.Rotation(math.radians(90), 4, "X")


def crown_outline(half_w, top, bottom, side=0.8, shoulder=1.2):
	"""Back outline in (x, z), CCW: straight sides, then five crown facets turning 30 degrees each."""
	lens = [side, shoulder, None, shoulder, side]
	dirs = [120, 150, 180, 210, 240]  # f1..f5 headings, walking right to left
	lens[2] = 2 * (half_w - side * 0.5 - shoulder * math.cos(math.radians(30)))
	rise = side * math.sin(math.radians(60)) + shoulder * 0.5
	p = Vector((half_w, top - rise))
	pts = [(half_w, bottom), (p.x, p.y)]
	for L, d in zip(lens, dirs):
		p = p + Vector((math.cos(math.radians(d)), math.sin(math.radians(d)))) * L
		pts.append((p.x, p.y))
	pts[-1] = (-half_w, pts[-1][1])
	pts.append((-half_w, bottom))
	return pts


def pillow(m, tag, size, thick, pinch, seed, mat):
	"""Tufted throw pillow: thin seam rim, puffed faces, pinched button tuft in each face centre."""
	rng = random.Random(seed)
	h = size / 2
	rim = []
	for k in range(8):
		a = math.radians(45 * k)
		r = h * math.sqrt(2) if k % 2 else h * 0.9  # edge mids pulled in: pointy corners
		rim.append(Vector((r * math.cos(a), r * math.sin(a), 0)))
	verts = list(rim)
	faces = []
	for side in (1, -1):
		inner0 = len(verts)
		for k in range(8):
			p = rim[k] * 0.55
			verts.append(Vector((p.x, p.y, side * thick / 2)))
		c = len(verts)
		verts.append(Vector((0, 0, side * (thick / 2 - pinch))))
		for k in range(8):
			a, b = inner0 + k, inner0 + (k + 1) % 8
			faces.append((c, a, b) if side > 0 else (c, b, a))
			ra, rb = k, (k + 1) % 8
			faces.append((ra, rb, b, a) if side > 0 else (ra, a, b, rb))
	for v in verts:  # hand-made wonk: <= 5% jitter
		v.x += rng.uniform(-0.03, 0.03) * h
		v.y += rng.uniform(-0.03, 0.03) * h
		v.z += rng.uniform(-0.04, 0.04) * thick
	start = len(m.parts.get(tag, [[], []])[0])
	m.add(tag, verts, faces)
	transform(m, tag, mat, start)
	for side in (1, -1):  # tuft buttons, seated in the pinch on both faces
		flip = Matrix.Rotation(math.pi, 4, "X") if side < 0 else Matrix.Identity(4)
		place = mat @ Matrix.Translation((0, 0, side * (thick / 2 - pinch - 0.02))) @ flip
		disc(m, "tufts", 0.09, 0.06, place)


def build():
	m = tk.Mesh()

	# Base: four squat feet, an oct-plan apron with a stud row, a sharp lip it all sits on
	for sx in (-1, 1):
		for sy in (-1, 1):
			foot = [(x + sx * 3.65, y + (1.25 if sy > 0 else -1.38)) for x, y in tk.oct_poly(0.8, 0.8, 0.1)]
			tk.slab(m, foot, 0.0, 0.42, "feet", frame=plan_frame)
	apron = [(x, y - 0.075) for x, y in tk.oct_poly(8.2, 3.45, 0.08)]
	tk.slab(m, apron, 0.42, 1.1, "apron", frame=plan_frame)
	tk.plain_box(m, (-4.15, -1.9, 1.1), (4.15, 1.7, LIP_TOP), "lip")
	for i in range(17):
		disc(m, "studs", 0.09, 0.05, Matrix.Translation((-3.6 + i * 0.45, -1.8, 0.76)) @ FACE_FRONT)
	for sx in (-1, 1):
		face_side = Matrix.Rotation(math.radians(sx * 90), 4, "Y")
		for i in range(7):
			disc(m, "studs", 0.09, 0.05, Matrix.Translation((sx * 4.1, -1.4 + i * 0.45, 0.76)) @ face_side)

	# Arms: body under a fat 8-sided roll, flared scroll in front, wood strip ending in a button
	for sx in (-1, 1):
		xc = sx * ARM_XC
		body = [(x + xc, y + (FRONT + BACK) / 2) for x, y in tk.oct_poly(1.4, BACK - FRONT, 0.08)]
		tk.slab(m, body, LIP_TOP, ARM_ZC, "arm_body", frame=plan_frame)
		tk.tube(m, [(xc, BACK, ARM_ZC), (xc, FRONT, ARM_ZC)], ARM_R, "arm_roll", axis=(1, 0, 0), sides=8)
		xs = xc + sx * SCROLL_DX
		tk.tube(m, [(xs, FRONT, ARM_ZC), (xs, FRONT - 0.14, ARM_ZC)], SCROLL_R, "arm_scroll",
				axis=(1, 0, 0), sides=8)
		tk.plain_box(m, (xs - 0.3, FRONT - 0.12, LIP_TOP), (xs + 0.3, FRONT, ARM_ZC - SCROLL_R), "arm_strip")
		disc(m, "arm_button", 0.24, 0.09, Matrix.Translation((xs, FRONT - 0.14, ARM_ZC)) @ FACE_FRONT)

	# Back: thick wood frame with a faceted crown, padded inset pad, crest block; leaned back
	top = 4.82
	outline = crown_outline(2.6, top, LIP_TOP)
	tk.slab(m, outline, -BACK_Y[1], -BACK_Y[0], "back_frame", c=0.06)
	tk.slab(m, tk.inset_poly(outline, 0.22), -BACK_Y[0], -PAD_FRONT, "back_pad", c=0.16)
	tk.plain_box(m, (-0.45, BACK_Y[0], top), (0.45, BACK_Y[1], top + 0.18), "crest")
	for t in ("back_frame", "back_pad", "crest"):
		transform(m, t, lean_matrix())

	# Seat: two wide low cushions with a seam gap, front lip past the base
	tk.chamfer_box(m, (-2.58, -1.98, LIP_TOP), (-0.04, PAD_FRONT - 0.01, SEAT_TOP), 0.08, "cushion_l")
	tk.chamfer_box(m, (0.04, -1.98, LIP_TOP), (2.58, PAD_FRONT - 0.01, SEAT_TOP), 0.08, "cushion_r")

	# Throw pillows propped in the corners against back and arm
	for sx, tag, seed in ((-1, "pillow_l", 3), (1, "pillow_r", 8)):
		mat = (Matrix.Translation((sx * 1.95, 0.4, SEAT_TOP + 0.68))
			   @ Matrix.Rotation(math.radians(sx * -28), 4, "Z")
			   @ Matrix.Rotation(math.radians(90 - 22), 4, "X")
			   @ Matrix.Rotation(math.radians(sx * 6), 4, "Z"))
		pillow(m, tag, 1.25, 0.44, 0.13, seed, mat)

	# Pivot: bottom centre of the bounding box
	st = tk.stats(m)
	(x0, y0, _), (x1, y1, _) = st["bbox"]
	tk.translate(m, (-(x0 + x1) / 2, -(y0 + y1) / 2, 0))
	return m, -(y0 + y1) / 2


CLIP_PAIRS = [
	("pillow_l", "cushion_l"), ("pillow_r", "cushion_r"), ("pillow_l", "back_pad"),
	("pillow_r", "back_pad"), ("pillow_l", "arm_roll"), ("pillow_r", "arm_roll"),
	("pillow_l", "arm_body"), ("pillow_r", "arm_body"),
	("cushion_l", "arm_body"), ("cushion_r", "arm_body"), ("cushion_l", "back_pad"),
	("cushion_r", "back_pad"), ("back_pad", "arm_roll"), ("back_frame", "arm_roll"),
	("back_frame", "arm_body"), ("crest", "back_frame"), ("arm_strip", "arm_scroll"),
	("cushion_l", "cushion_r"), ("cushion_l", "arm_roll"), ("cushion_r", "arm_roll"),
]


def helpers(dy):
	"""COL_ boxes in pivot space (Roblox: x right, y up, z back), from the build's dimensions."""
	def box(name, x0, x1, y0, y1, z0, z1, tilt=0.0):
		return {"name": name, "size": (x1 - x0, z1 - z0, y1 - y0),
				"pos": ((x0 + x1) / 2, (z0 + z1) / 2, (y0 + y1) / 2 + dy), "tilt": tilt}

	out = [box("COL_Base", -4.15, 4.15, -1.98, 1.7, 0, SEAT_TOP)]
	for sx, n in ((-1, "COL_ArmL"), (1, "COL_ArmR")):
		lo, hi = sorted((sx * (ARM_XC - ARM_R), sx * (ARM_XC + SCROLL_DX + SCROLL_R)))
		out.append(box(n, lo, hi, FRONT - 0.14, BACK, SEAT_TOP, ARM_ZC + ARM_R))
	# Back: the pad-to-frame slab above the seat, tilted by the lean about its own centre
	c = lean_matrix() @ Vector((0, (PAD_FRONT + BACK_Y[1]) / 2, (SEAT_TOP + 4.82) / 2))
	out.append({"name": "COL_Back", "size": (5.2, 4.82 - SEAT_TOP, BACK_Y[1] - PAD_FRONT),
				"pos": (0, c.z, c.y + dy), "tilt": LEAN})
	return out


def helper_luau(hs):
	rows = "\n".join(
		f'\t{{ "{h["name"]}", Vector3.new({h["size"][0]:.3f}, {h["size"][1]:.3f}, {h["size"][2]:.3f}), '
		f'Vector3.new({h["pos"][0]:.3f}, {h["pos"][1]:.3f}, {h["pos"][2]:.3f}), {h["tilt"]} }},'
		for h in hs)
	return (
		"\n-- Collision helpers (guide 9.2): invisible anchored boxes; the meshes above don't collide.\n"
		"-- Offsets are from the bottom centre, z towards the back; the back's side is read off the\n"
		"-- pillows (they sit behind the pivot) so an import that flips z still lines up.\n"
		"local helpers = {\n" + rows + "\n}\n"
		'for _, root in game:GetService("Selection"):Get() do\n'
		'\tlocal pillows = root:IsA("Model") and root:FindFirstChild("Couch_Pillows", true)\n'
		"\tif pillows then\n"
		"\t\tlocal cf, size = root:GetBoundingBox()\n"
		"\t\tlocal base = cf * CFrame.new(0, -size.Y / 2, 0)\n"
		"\t\troot.WorldPivot = base\n"
		"\t\tlocal back = base:PointToObjectSpace(pillows.Position).Z >= 0 and 1 or -1\n"
		"\t\tfor _, h in helpers do\n"
		"\t\t\tlocal old = root:FindFirstChild(h[1])\n"
		"\t\t\tif old then\n"
		"\t\t\t\told:Destroy()\n"
		"\t\t\tend\n"
		'\t\t\tlocal p = Instance.new("Part")\n'
		"\t\t\tp.Name, p.Size = h[1], h[2]\n"
		"\t\t\tp.CFrame = base * CFrame.new(h[3].X, h[3].Y, h[3].Z * back) * CFrame.Angles(math.rad(h[4]) * back, 0, 0)\n"
		"\t\t\tp.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false\n"
		"\t\t\tp.Transparency, p.CastShadow = 1, false\n"
		"\t\t\tp.Parent = root\n"
		"\t\tend\n"
		"\tend\n"
		"end\n"
	)


def run():
	for ob in [o for o in bpy.data.objects if o.name == "Couch" or o.name.startswith("Couch_")]:
		bpy.data.objects.remove(ob, do_unlink=True)
	m, dy = build()
	hand = ("pillow_l", "pillow_r", "tufts")
	audits = {
		"mesh": tk.audit_mesh(m, organic_tags=hand),
		"clip": tk.audit_clipping(m, CLIP_PAIRS),
	}
	merged = m.retag(REGIONS)
	st = tk.stats(merged)
	group, parts = tk.to_blender("Couch", merged, PALETTE)
	audits["style"] = tk.audit_style(parts)
	return m, st, audits, group, parts, dy


def export(group, parts, tris, dy):
	os.makedirs(OUT, exist_ok=True)
	fbx = tk.export_fbx(OUT + "/Couch.fbx", group, colors_type="NONE")
	tk.write_handoff(OUT, "Couch", parts, attributes={"Biome": "Manor", "Interactable": False},
					 note=f"Doors guide v24 couch, {tris} tris. Pivot bottom centre, front -Z. "
					 "Colour is Part.Color (no vertex colour in the FBX). COL_ helper parts collide.",
					 part_color=True)
	lp = OUT + "/Couch_apply_materials.luau"
	with open(lp, "a") as f:
		f.write(helper_luau(helpers(dy)))
	shutil.copy(fbx, ROOT + "/factory_fbx/Couch.fbx")
	return fbx
