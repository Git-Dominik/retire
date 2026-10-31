"""Power transformer in a chain-link cage (Doors asset guide v24, style mode, factory / Mines biome).

Run with Blender in the background:
	blender -b --factory-startup --python-expr "import sys; sys.path.insert(0, '<this dir>'); \
		import transformer as t; t.run()"
Writes assets/transformer/Transformer.fbx + hand-off, copies the FBX to assets/factory_fbx/ and saves
Transformer.blend. Blender axes: front = -Y, up = +Z, 1 unit = 1 stud, pivot bottom centre.
A small oil-filled transformer: tank on two skids, ribbed cooling fins front and back between
headers, flat radiators on the ends, a bolted cover with lifting lugs, three tall porcelain HV
bushings, four short LV bushings and a breather tube. Around it a cage of hex posts and rails with
diamond chain-link panels (an array of crossing bars), a high-voltage sign clipped to the front
mesh (its red band is left blank; the words are added in Roblox), and a staff maintenance gate in
the front-right bay that the apply script sets up as a SwingDoor. One mesh per value region
coloured by Part.Color; the meshes don't collide, the COL_ boxes (cage walls, tank) do.
"""

import math
import os
import shutil
import sys

import bpy
from mathutils import Vector

ROOT = "/home/omar/retire/assets"
sys.path.insert(0, ROOT + "/WallLights")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import doors_toolkit as tk  # noqa: E402
from office_furniture import col_box, helper_luau, post_box, rect, to_pivot, top_slab  # noqa: E402

OUT = ROOT + "/transformer"
TANK = (2.0, 1.3, 0.5, 3.9)  # half width, half depth, bottom, top
COVER_TOP = 4.08
CAGE_X = 3.0
CAGE = (CAGE_X, 2.6, 6.6)  # half width, half depth, post height
RAIL_Z = (0.35, 6.3)
MESH_PITCH = 0.6  # chain-link diamond width
SIGN = (-1.5, 3.8)  # centre x, z on the front mesh (the fixed left bay)
GATE = (0.24, CAGE_X - 0.28, 0.2, 6.05)  # leaf frame x0 (latch), x1 (hinge side), bottom, top


def hex_bar(m, tag, a, b, r, axis):
	tk.tube(m, [a, b], r, tag, axis=axis)


def lug(m, x, y):
	"""Lifting lug on the cover: a plate with clipped top corners, edge-on to the nearer end."""
	pts = [(-0.18, 0), (0.18, 0), (0.18, 0.2), (0.08, 0.3), (-0.08, 0.3), (-0.18, 0.2)]
	tk.hull(m, [(x + px, y + d, COVER_TOP + pz) for px, pz in pts for d in (-0.05, 0.05)], "cover")


def bushing(m, x, y, sheds, top):
	"""Porcelain bushing: metal collar, stacked sheds (8-sided), terminal rod and flat lug plate."""
	z0 = COVER_TOP
	tk.lathe(m, [(0.2, 0), (0.2, 0.12)], "hardware", center=(x, y, z0))
	prof, z = [], 0.12
	for r in sheds:
		prof += [(0.13, z), (r, z + 0.05), (r, z + 0.12), (0.13, z + 0.17)]
		z += 0.19
	prof.append((0.11, z + 0.08))
	tk.lathe(m, prof, "porcelain", center=(x, y, z0))
	ztop = z0 + z + 0.08
	tk.lathe(m, [(0.045, 0), (0.045, top)], "hardware", center=(x, y, ztop))
	tk.plain_box(m, (x - 0.09, y - 0.02, ztop + top - 0.04), (x + 0.09, y + 0.02, ztop + top + 0.18), "hardware")


def transformer(m):
	hx, hy, zb, zt = TANK
	for x in (-1.4, 1.4):
		tk.plain_box(m, (x - 0.18, -hy - 0.1, 0), (x + 0.18, hy + 0.1, zb), "skids")
	post_box(m, "tank", (-hx, -hy, zb), (hx, hy, zt), 0.15)
	for s in (-1, 1):  # flat end radiators
		tk.plain_box(m, (min(s * hx, s * (hx + 0.2)), -1.0, 0.95), (max(s * hx, s * (hx + 0.2)), 1.0, 3.45), "tank")
	# Cooling fins front and back, 17 plates between a top and a bottom header
	for s in (-1, 1):
		y0, y1 = sorted((s * hy, s * (hy + 0.5)))
		for z0, z1 in ((0.7, 0.85), (3.55, 3.7)):
			tk.plain_box(m, (-1.72, min(s * hy, s * (hy + 0.32)), z0), (1.72, max(s * hy, s * (hy + 0.32)), z1), "tank")
		for k in range(17):
			x = -1.6 + 0.2 * k
			tk.plain_box(m, (x - 0.03, y0, 0.85), (x + 0.03, y1, 3.55), "fins")
	top_slab(m, "cover", -hx - 0.12, -hy - 0.12, hx + 0.12, hy + 0.12, zt, COVER_TOP, 0.04)
	# Cover bolts round the rim
	for x0, y0, x1, y1, n in ((-hx, -hy, hx, -hy, 9), (-hx, hy, hx, hy, 9), (-hx, -hy + 0.5, -hx, hy - 0.5, 4),
							  (hx, -hy + 0.5, hx, hy - 0.5, 4)):
		for k in range(n):
			t = k / (n - 1)
			bx, by = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
			tk.plain_box(m, (bx - 0.05, by - 0.05, COVER_TOP), (bx + 0.05, by + 0.05, COVER_TOP + 0.07), "bolts")
	for x in (-1.75, 1.75):
		for y in (-0.95, 0.95):
			lug(m, x, y)
	for x in (-0.9, 0.0, 0.9):
		bushing(m, x, 0.35, (0.28, 0.25, 0.25, 0.22), 0.25)
	for x in (-0.9, -0.3, 0.3, 0.9):
		bushing(m, x, -0.65, (0.2, 0.18), 0.12)
	# Breather / oil-level tube, back left
	tk.lathe(m, [(0.17, 0), (0.17, 1.15)], "breather", center=(-1.45, 0.6, COVER_TOP))
	tk.lathe(m, [(0.2, 1.15), (0.2, 1.25)], "hardware", center=(-1.45, 0.6, COVER_TOP))


def chain_panel(m, origin, u_dir, w, h, tag="cage_mesh"):
	"""Diamond chain-link: two families of crossing bars clipped to a w x h panel in the plane spanned
	by u_dir and +Z at origin. Bar ends stop on the panel edge, inside the posts and rails."""
	o, u, z = Vector(origin), Vector(u_dir), Vector((0, 0, 1))
	n = u.cross(z)
	a = MESH_PITCH
	for fam, depth in ((1, -0.012), (-1, 0.012)):
		k0 = math.floor(-h / a) if fam == 1 else 0
		k1 = math.ceil(w / a) if fam == 1 else math.ceil((w + h) / a)
		for k in range(k0, k1 + 1):
			c = k * a + (a / 2 if fam == 1 else 0)
			if fam == 1:  # v = u - c
				lo, hi = max(0.0, c), min(w, h + c)
				ends = ((lo, lo - c), (hi, hi - c))
			else:  # v = c - u
				lo, hi = max(0.0, c - h), min(w, c)
				ends = ((lo, c - lo), (hi, c - hi))
			if hi - lo < 0.05:
				continue
			d = (Vector(ends[1]) - Vector(ends[0])).normalized()
			side = Vector((-d.y, d.x)) * 0.015
			pts = []
			for eu, ev in ends:
				for sg in (-1, 1):
					for dd in (-0.012, 0.012):
						pu, pv = eu + side.x * sg, ev + side.y * sg
						pts.append(o + u * pu + z * pv + n * (depth + dd))
			tk.hull(m, pts, tag)


def cage(m):
	cx, cy, ph = CAGE
	posts = [(x, y) for x in (-cx, 0, cx) for y in (-cy, cy)] + [(-cx, 0), (cx, 0)]
	for x, y in posts:
		hex_bar(m, "cage_frame", (x, y, 0.06), (x, y, ph), 0.12, (1, 0, 0))
		hex_bar(m, "cage_frame", (x, y, ph), (x, y, ph + 0.08), 0.16, (1, 0, 0))  # cap
		tk.plain_box(m, (x - 0.2, y - 0.2, 0), (x + 0.2, y + 0.2, 0.06), "cage_frame")  # foot plate
	for z in RAIL_Z:
		for y in (-cy, cy):
			xe = 0 if (y < 0 and z == RAIL_Z[0]) else cx  # the gate bay has no bottom rail to trip on
			hex_bar(m, "cage_frame", (-cx, y, z), (xe, y, z), 0.07, (0, 1, 0))
		for x in (-cx, cx):
			hex_bar(m, "cage_frame", (x, -cy, z), (x, cy, z), 0.07, (1, 0, 0))
	h = RAIL_Z[1] - RAIL_Z[0]
	for y in (-cy, cy):  # long sides, two bays each
		for x0 in (-cx, 0):
			if y < 0 and x0 == 0:
				continue  # the maintenance gate fills this bay
			chain_panel(m, (x0 + 0.1, y, RAIL_Z[0]), (1, 0, 0), cx - 0.2, h)
	for x in (-cx, cx):
		for y0 in (-cy, 0):
			chain_panel(m, (x, y0 + 0.1, RAIL_Z[0]), (0, 1, 0), cy - 0.2, h)


def clipped_tri(half, cy, clip):
	"""Equilateral warning triangle (point up) with its corners clipped by clip along each edge."""
	h = half * math.sqrt(3)
	pts = [Vector((-half, cy - h / 3)), Vector((half, cy - h / 3)), Vector((0, cy + 2 * h / 3))]
	out = []
	for i in range(3):
		p, a, b = pts[i], pts[i - 1], pts[(i + 1) % 3]
		out += [tuple(p + (a - p).normalized() * clip), tuple(p + (b - p).normalized() * clip)]
	return out


def sign(m):
	"""High-voltage plate (the standard symbol): a black-bordered yellow triangle with a black
	zig-zag bolt ending in an arrowhead, over a blank red band (its text is added in Roblox).
	Held to the front mesh by four corner clips that pass through the chain-link."""
	sx, sz = SIGN
	yb = -CAGE[1] - 0.05  # plate back, just outside the mesh

	def fr(u, v, w):
		return Vector((sx + u, yb - w, sz + v))

	def flat_poly(poly, w0, w1, tag):
		tk.hull(m, [fr(u, v, w) for u, v in poly for w in (w0, w1)], tag)

	pw, ph = 0.65, 0.8  # half sizes
	for u in (-pw + 0.12, pw - 0.12):
		for v in (-ph + 0.12, ph - 0.12):
			tk.plain_box(m, (sx + u - 0.06, -CAGE[1] - 0.06, sz + v - 0.06),
						 (sx + u + 0.06, -CAGE[1] + 0.04, sz + v + 0.06), "cage_frame")
	flat_poly(rect(-pw, -ph, pw, ph), 0, 0.05, "sign_plate")
	flat_poly(clipped_tri(0.52, 0.18, 0.08), 0.05, 0.06, "sign_black")
	flat_poly(clipped_tri(0.4, 0.18, 0.06), 0.06, 0.07, "sign_yellow")
	# Bolt, inside the yellow: upper stroke, a jog to the right, lower stroke, arrowhead (each convex)
	flat_poly([(0.0, 0.47), (0.07, 0.47), (0.0, 0.24), (-0.07, 0.24)], 0.07, 0.08, "sign_black")
	flat_poly([(-0.07, 0.24), (0.0, 0.24), (0.07, 0.19), (0.0, 0.19)], 0.07, 0.08, "sign_black")
	flat_poly([(0.0, 0.19), (0.07, 0.19), (0.0, 0.03), (-0.06, 0.06)], 0.07, 0.08, "sign_black")
	flat_poly([(-0.12, 0.08), (0.04, 0.02), (-0.08, -0.03)], 0.07, 0.08, "sign_black")
	flat_poly(rect(-pw + 0.08, -ph + 0.08, pw - 0.08, -ph + 0.42), 0.05, 0.07, "sign_band")


def gate(m):
	"""Staff maintenance gate in the front-right bay: hex tube frame with a mid brace and its own
	chain-link, two hinge straps on the corner post (knuckles stay with the cage), a latch grip at
	the mid post. Its meshes are the leaf of a SwingDoor (see the apply script)."""
	cx, cy, ph = CAGE
	x0, x1, z0, z1 = GATE
	for a, b in (((x0, -cy, z0), (x1, -cy, z0)), ((x0, -cy, z1), (x1, -cy, z1)), ((x0, -cy, 3.2), (x1, -cy, 3.2))):
		hex_bar(m, "gate_frame", a, b, 0.06, (0, 1, 0))
	for x in (x0, x1):
		hex_bar(m, "gate_frame", (x, -cy, z0 - 0.06), (x, -cy, z1 + 0.06), 0.06, (0, 1, 0))
	for zlo, zhi in ((z0, 3.2), (3.2, z1)):
		chain_panel(m, (x0, -cy, zlo), (1, 0, 0), x1 - x0, zhi - zlo, "gate_mesh")
	for z in (1.2, 5.2):
		tk.plain_box(m, (x1, -cy - 0.04, z - 0.08), (cx - 0.1, -cy + 0.04, z + 0.08), "gate_frame")  # strap
		hex_bar(m, "cage_frame", (cx, -cy, z - 0.14), (cx, -cy, z + 0.14), 0.16, (1, 0, 0))  # knuckle
	tk.plain_box(m, (x0 - 0.04, -cy - 0.2, 3.0), (x0 + 0.04, -cy - 0.04, 3.4), "gate_grip")
	tk.plain_box(m, (x0 - 0.04, -cy - 0.08, 3.08), (x0 + 0.04, -cy + 0.0, 3.14), "gate_grip")
	tk.plain_box(m, (x0 - 0.04, -cy - 0.08, 3.26), (x0 + 0.04, -cy + 0.0, 3.32), "gate_grip")


PALETTE = {
	"skids": ("#3E423F", "Metal"), "tank": ("#7E847F", "Metal"), "fins": ("#959B95", "Metal"),
	"cover": ("#676C68", "Metal"), "bolts": ("#3A3D3B", "Metal"), "porcelain": ("#6E3A2C", "SmoothPlastic"),
	"hardware": ("#B8B5AA", "Metal"), "breather": ("#D6D0C0", "Plastic"),
	"cage_frame": ("#55595C", "Metal"), "cage_mesh": ("#8A8E90", "Metal"),
	"sign_plate": ("#E3DCC8", "SmoothPlastic"), "sign_black": ("#1E1E1E", "SmoothPlastic"),
	"sign_yellow": ("#E8A21E", "SmoothPlastic"), "sign_band": ("#8E2A26", "SmoothPlastic"),
	"gate_frame": ("#55595C", "Metal"), "gate_mesh": ("#8A8E90", "Metal"), "gate_grip": ("#C8A23A", "Metal"),
}

GATE_EXTRA = """
		-- Maintenance gate: a SwingDoor (SwingDoors.client) whose one leaf is the gate's meshes,
		-- pivoted on the corner post's hinge line; the door's pivot is the opening's centre.
		if not root:FindFirstChild("MaintenanceGate") then
			local door = Instance.new("Model")
			door.Name = "MaintenanceGate"
			door.Parent = root
			local leaf = Instance.new("Model")
			leaf.Name = "Leaf"
			leaf.Parent = door
			for _, name in { "Transformer_GateFrame", "Transformer_GateMesh", "Transformer_GateGrip" } do
				local p = root:FindFirstChild(name, true)
				if p then
					p.Parent = leaf
				end
			end
			leaf.WorldPivot = base * CFrame.new(HINGE)
			door.WorldPivot = base * CFrame.new(CENTRE)
			door:SetAttribute("OpenAngle", 100)
			game:GetService("CollectionService"):AddTag(door, "SwingDoor")
		end
"""


def gate_luau(off):
	ox, oy, oz = off
	v = lambda x, y, z: f"{x + ox:.3f}, {z + oz:.3f}, {y + oy:.3f}"  # noqa: E731 (Roblox x, up, z)
	cx, cy, _ = CAGE
	return GATE_EXTRA.replace("HINGE", v(cx, -cy, 3.2)).replace("CENTRE", v(cx / 2, -cy, 3.2))[1:]


def build():
	m = tk.Mesh()
	transformer(m)
	cage(m)
	gate(m)
	sign(m)
	off = to_pivot(m)
	cx, cy, ph = CAGE
	hx, hy, zb, zt = TANK
	hs = [col_box("COL_Tank", (-hx - 0.2, -hy - 0.5, 0), (hx + 0.2, hy + 0.5, COVER_TOP), off)]
	# Front wall only on the fixed bay: the gate is a SwingDoor, and its leaves never collide
	hs.append(col_box("COL_CageFront", (-cx, -cy - 0.12, 0), (0.12, -cy + 0.12, ph), off))
	hs.append(col_box("COL_CageBack", (-cx, cy - 0.12, 0), (cx, cy + 0.12, ph), off))
	for x in (-cx, cx):
		hs.append(col_box(f"COL_Cage{'Left' if x < 0 else 'Right'}", (x - 0.12, -cy, 0), (x + 0.12, cy, ph), off))
	return m, hs, off


def run():
	for ob in [o for o in bpy.data.objects if o.name == "Transformer" or o.name.startswith("Transformer_")]:
		bpy.data.objects.remove(ob, do_unlink=True)
	m, hs, off = build()
	audits = {"mesh": tk.audit_mesh(m), "clip": tk.audit_clipping(m, [("porcelain", "cover"), ("fins", "tank")])}
	st = tk.stats(m)
	group, parts = tk.to_blender("Transformer", m, PALETTE)
	audits["style"] = tk.audit_style(parts)
	os.makedirs(OUT, exist_ok=True)
	fbx = tk.export_fbx(OUT + "/Transformer.fbx", group, colors_type="NONE")
	size = " x ".join(f"{v:.2f}" for v in (st["size"][0], st["size"][2], st["size"][1]))
	tk.write_handoff(OUT, "Transformer", parts, attributes={"Biome": "Mines", "Interactable": False},
					 note=f"Doors guide v24, {st['tris']} tris, {size} studs (W x H x D). Pivot bottom centre, "
					 "front -Z (the sign's side). Colour is Part.Color (no vertex colour in the FBX). COL_ helper "
					 "parts (tank and the four cage walls) collide.", part_color=True)
	with open(OUT + "/Transformer_apply_materials.luau", "a") as f:
		f.write(helper_luau("Transformer", "Tank", hs, gate_luau(off)))
	shutil.copy(fbx, ROOT + "/factory_fbx/Transformer.fbx")
	bpy.ops.wm.save_as_mainfile(filepath=OUT + "/Transformer.blend")
	return {"tris": st["tris"], "size": st["size"], "per_tag": st["per_tag"], "audits": audits}
