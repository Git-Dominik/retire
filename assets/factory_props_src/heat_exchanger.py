"""Heat exchanger (Doors asset guide v24, style mode): a horizontal shell-and-tube exchanger.

Run inside Blender (MCP execute). Builds with assets/WallLights/doors_toolkit.py, exports
assets/heat_exchanger/HeatExchanger.fbx + hand-off, and copies the FBX to assets/factory_fbx/.
Blender axes: front = -Y, up = +Z, length along X, 1 unit = 1 stud, pivot bottom centre.
An 8-sided drum on two saddles, a bolted body-flange pair, a channel end with a bolted cover and
nozzles up and down; one mesh per value region coloured by Part.Color, COL_ helper parts collide.
"""

import math
import os
import shutil
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = "/home/omar/retire/assets"
sys.path.insert(0, ROOT + "/WallLights")
import doors_toolkit as tk  # noqa: E402

OUT = ROOT + "/heat_exchanger"
CZ, R = 3.3, 1.8  # drum axis height, half flat-to-flat
FL_R = 2.15  # flange half flat-to-flat
SHELL_X = (-7.2, 3.0)  # drum between rear flange and body flanges
CHAN_X = (3.6, 6.0)  # channel barrel between body flanges and cover flange
SADDLE_X = (-4.6, 1.0)
NOZ_X, NOZ_R = 4.8, 0.55
BOLTS = 16  # nuts per flange face, two per octagon side
BOLT_R = 1.98  # nut centre radius on a 2.15 flange

REGIONS = {
	"shell": "shell", "head": "shell", "channel": "shell", "noz_top": "shell", "noz_bot": "shell",
	"vents": "shell", "drain": "shell",
	"rear_flange": "flanges", "body_flange_a": "flanges", "body_flange_b": "flanges",
	"cover_flange": "flanges", "cover": "flanges", "noz_collars": "flanges", "noz_flanges": "flanges",
	"vent_caps": "flanges", "lugs": "flanges",
	"bolts": "bolts",
	"saddle_web": "saddles", "saddle_rib": "saddles", "saddle_base": "saddles",
	"pads": "pads", "drain_cap": "pads",
}
PALETTE = {
	"shell": ("#A8A49A", "Metal"),
	"flanges": ("#7E7A72", "Metal"),
	"bolts": ("#3E3A36", "Metal"),
	"saddles": ("#8A867C", "Metal"),
	"pads": ("#B8862E", "DiamondPlate"),
}


def place(m, tag, build, mat):
	"""Build into a scratch mesh, then add it to m transformed by mat."""
	s = tk.Mesh()
	build(s)
	for vs, fs in s.parts.values():
		m.add(tag, [mat @ v for v in vs], fs)


def lathe_x(m, tag, profile, x0, cap_bottom=True, cap_top=True):
	"""Lathe along +X from x0 on the drum axis; flats face up, down, front and back."""
	mat = Matrix.Translation((x0, 0, CZ)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
	place(m, tag, lambda s: tk.lathe(s, profile, "t", cap_bottom=cap_bottom, cap_top=cap_top), mat)


def disc_x(m, tag, r, x0, x1):
	lathe_x(m, tag, [(r, 0), (r, x1 - x0)], x0)


def disc_z(m, tag, r, z0, z1, x, y=0.0):
	tk.lathe(m, [(r, 0), (r, z1 - z0)], tag, center=(x, y, z0))


def nut_ring(m, count, radius, mat, size=0.26, depth=0.16, phase=0.0):
	"""count nuts on a ring in the local XY plane, seated on z=0 and rising to +z, placed by mat."""
	for k in range(count):
		a = phase + 2 * math.pi * k / count
		rot = Matrix.Rotation(a, 4, "Z")
		h = size / 2
		pts = [rot @ Vector((radius + dx, dy, dz)) for dx in (-h, h) for dy in (-h, h) for dz in (0, depth)]
		tk.hull(m, [mat @ p for p in pts], "bolts")


def flange_nuts(m, x_face, outward):
	"""A nut ring on a flange face at x_face, nuts standing out along +X (outward=1) or -X."""
	mat = Matrix.Translation((x_face, 0, CZ)) @ Matrix.Rotation(outward * math.pi / 2, 4, "Y")
	nut_ring(m, BOLTS, BOLT_R, mat, phase=math.pi / BOLTS)


def saddle(m, x):
	"""Pad, base plate, tapered web cut to the drum's lower three facets, centre rib."""
	tk.chamfer_box(m, (x - 0.75, -1.95, 0), (x + 0.75, 1.95, 0.5), 0.06, "pads")
	tk.plain_box(m, (x - 0.6, -1.85, 0.5), (x + 0.6, 1.85, 0.64), "saddle_base")
	bot = CZ - R
	flat = R * math.tan(math.pi / 8)
	top = bot + (1.5 - flat)  # drum's lower diagonal facet at |y| = 1.5
	web = [(-1.7, 0.64), (1.7, 0.64), (1.5, top), (flat, bot), (-flat, bot), (-1.5, top)]
	tk.hull(m, [(x + dx, y, z) for dx in (-0.15, 0.15) for y, z in web], "saddle_web")
	for x0, x1 in ((x - 0.6, x - 0.15), (x + 0.15, x + 0.6)):
		tk.plain_box(m, (x0, -0.1, 0.64), (x1, 0.1, bot), "saddle_rib")


def nozzle(m, up):
	"""Channel nozzle: collar on the channel flat, pipe, bolted flange (blind on top)."""
	s = 1 if up else -1
	face = CZ + s * R
	z = lambda d: face + s * d  # noqa: E731
	lo = lambda a, b: (min(z(a), z(b)), max(z(a), z(b)))  # noqa: E731
	tag = "noz_top" if up else "noz_bot"
	disc_z(m, "noz_collars", 0.72, *lo(0, 0.12), NOZ_X)
	disc_z(m, tag, NOZ_R, *lo(0.12, 1.0 if up else 0.85), NOZ_X)
	end = 1.0 if up else 0.85
	disc_z(m, "noz_flanges", 0.8, *lo(end, end + 0.22), NOZ_X)
	if up:
		disc_z(m, "noz_flanges", 0.8, *lo(end + 0.22, end + 0.36), NOZ_X)
		face_z = z(end + 0.36)
	else:
		face_z = z(end + 0.22)
	mat = Matrix.Translation((NOZ_X, 0, face_z)) @ Matrix.Rotation(0 if up else math.pi, 4, "X")
	nut_ring(m, 8, 0.62, mat, size=0.2, depth=0.12, phase=math.pi / 8)


def lug(m, x):
	"""Lifting lug on the drum's top flat: a plate with clipped top corners."""
	z0 = CZ + R
	pts = [(-0.3, 0), (0.3, 0), (0.3, 0.3), (0.15, 0.45), (-0.15, 0.45), (-0.3, 0.3)]
	tk.hull(m, [(x + px, y, z0 + pz) for px, pz in pts for y in (-0.08, 0.08)], "lugs")


def build():
	m = tk.Mesh()
	# Drum, rear head (45-degree turn to a flat end), channel, cover
	disc_x(m, "shell", R, *SHELL_X)
	x = SHELL_X[0]
	disc_x(m, "rear_flange", FL_R, x - 0.3, x)
	lathe_x(m, "head", [(1.2, 0), (R, 0.6), (R, 0.9)], x - 1.2)  # 45-degree turn to a flat end
	disc_x(m, "body_flange_a", FL_R, SHELL_X[1], SHELL_X[1] + 0.3)
	disc_x(m, "body_flange_b", FL_R, SHELL_X[1] + 0.3, CHAN_X[0])
	disc_x(m, "channel", R, *CHAN_X)
	disc_x(m, "cover_flange", FL_R, CHAN_X[1], CHAN_X[1] + 0.3)
	disc_x(m, "cover", FL_R, CHAN_X[1] + 0.3, CHAN_X[1] + 0.6)
	# Bolts on every outer flange face
	flange_nuts(m, x, 1)
	flange_nuts(m, x - 0.3, -1)
	flange_nuts(m, SHELL_X[1], -1)
	flange_nuts(m, CHAN_X[0], 1)
	flange_nuts(m, CHAN_X[1], -1)
	flange_nuts(m, CHAN_X[1] + 0.6, 1)
	for sx in SADDLE_X:
		saddle(m, sx)
	nozzle(m, True)
	nozzle(m, False)
	# Small vent stubs on the drum top, a drain stub with a yellow cap underneath
	for vx in (-6.2, 2.2):
		disc_z(m, "vents", 0.2, CZ + R, CZ + R + 0.45, vx)
		disc_z(m, "vent_caps", 0.3, CZ + R + 0.45, CZ + R + 0.6, vx)
	disc_z(m, "drain", 0.18, CZ - R - 0.5, CZ - R, -6.2)
	disc_z(m, "drain_cap", 0.27, CZ - R - 0.68, CZ - R - 0.5, -6.2)
	for lx in (-5.6, -0.4):
		lug(m, lx)
	# Pivot: bottom centre of the bounding box
	st = tk.stats(m)
	lo, hi = st["bbox"]
	off = (-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2])
	tk.translate(m, off)
	return m, off


CLIP_PAIRS = [
	("rear_flange", "shell"), ("body_flange_a", "shell"), ("channel", "body_flange_b"),
	("saddle_web", "shell"), ("saddle_rib", "shell"), ("saddle_rib", "saddle_web"),
	("noz_collars", "channel"), ("lugs", "shell"), ("vents", "shell"),
]


def helpers(off):
	"""COL_ boxes in pivot space (Roblox: x right, y up, z back)."""
	ox, oy, oz = off

	def box(name, x0, x1, y0, y1, z0, z1):
		return {"name": name, "size": (x1 - x0, z1 - z0, y1 - y0),
				"pos": ((x0 + x1) / 2 + ox, (z0 + z1) / 2 + oz, (y0 + y1) / 2 + oy)}

	out = [box("COL_Body", SHELL_X[0] - 1.2, CHAN_X[1] + 0.6, -FL_R, FL_R, CZ - FL_R, CZ + FL_R)]
	for i, sx in enumerate(SADDLE_X):
		out.append(box(f"COL_Saddle{i + 1}", sx - 0.75, sx + 0.75, -1.95, 1.95, 0, CZ - FL_R))
	out.append(box("COL_NozzleTop", NOZ_X - 0.8, NOZ_X + 0.8, -0.8, 0.8, CZ + FL_R, CZ + R + 1.36))
	return out


def helper_luau(hs):
	rows = "\n".join(
		f'\t{{ "{h["name"]}", Vector3.new({h["size"][0]:.3f}, {h["size"][1]:.3f}, {h["size"][2]:.3f}), '
		f'Vector3.new({h["pos"][0]:.3f}, {h["pos"][1]:.3f}, {h["pos"][2]:.3f}) }},'
		for h in hs)
	return (
		"\n-- Collision helpers (guide 9.2): invisible anchored boxes; the meshes above don't collide.\n"
		"-- Offsets are from the bottom centre; the model is symmetric front to back.\n"
		"local helpers = {\n" + rows + "\n}\n"
		'for _, root in game:GetService("Selection"):Get() do\n'
		'\tif root:IsA("Model") and root:FindFirstChild("HeatExchanger_Shell", true) then\n'
		"\t\tlocal cf, size = root:GetBoundingBox()\n"
		"\t\tlocal base = cf * CFrame.new(0, -size.Y / 2, 0)\n"
		"\t\troot.WorldPivot = base\n"
		"\t\tfor _, d in root:GetDescendants() do\n"
		'\t\t\tif d:IsA("BasePart") then\n'
		"\t\t\t\td.Anchored, d.CanCollide = true, false\n"
		"\t\t\tend\n"
		"\t\tend\n"
		"\t\tfor _, h in helpers do\n"
		"\t\t\tlocal old = root:FindFirstChild(h[1])\n"
		"\t\t\tif old then\n"
		"\t\t\t\told:Destroy()\n"
		"\t\t\tend\n"
		'\t\t\tlocal p = Instance.new("Part")\n'
		"\t\t\tp.Name, p.Size = h[1], h[2]\n"
		"\t\t\tp.CFrame = base * CFrame.new(h[3])\n"
		"\t\t\tp.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false\n"
		"\t\t\tp.Transparency, p.CastShadow = 1, false\n"
		"\t\t\tp.Parent = root\n"
		"\t\tend\n"
		"\tend\n"
		"end\n"
	)


def run():
	for ob in [o for o in bpy.data.objects if o.name == "HeatExchanger" or o.name.startswith("HeatExchanger_")]:
		bpy.data.objects.remove(ob, do_unlink=True)
	m, off = build()
	audits = {"mesh": tk.audit_mesh(m), "clip": tk.audit_clipping(m, CLIP_PAIRS)}
	merged = m.retag(REGIONS)
	st = tk.stats(merged)
	group, parts = tk.to_blender("HeatExchanger", merged, PALETTE)
	audits["style"] = tk.audit_style(parts)
	return m, st, audits, group, parts, off


def export(group, parts, tris, off):
	os.makedirs(OUT, exist_ok=True)
	fbx = tk.export_fbx(OUT + "/HeatExchanger.fbx", group, colors_type="NONE")
	tk.write_handoff(OUT, "HeatExchanger", parts, attributes={"Biome": "Mines", "Interactable": False},
					 note=f"Doors guide v24 heat exchanger, {tris} tris. Pivot bottom centre, length along X, "
					 "front -Z. Colour is Part.Color (no vertex colour in the FBX). COL_ helper parts collide.",
					 part_color=True)
	with open(OUT + "/HeatExchanger_apply_materials.luau", "a") as f:
		f.write(helper_luau(helpers(off)))
	shutil.copy(fbx, ROOT + "/factory_fbx/HeatExchanger.fbx")
	return fbx
