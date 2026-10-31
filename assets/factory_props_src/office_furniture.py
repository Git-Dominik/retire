"""Office furniture set (Doors asset guide v24, style mode, Office biome) for the mezzanine office.

Run with Blender in the background:
	blender -b --factory-startup --python-expr "import sys; sys.path.insert(0, '<this dir>'); \
		import office_furniture as o; o.run_all()"
Builds with assets/WallLights/doors_toolkit.py and writes assets/office_furniture/<Name>.fbx plus the
hand-off (apply script + manifest) per prop, copies each FBX to assets/factory_fbx/ and saves
OfficeFurniture.blend. Blender axes: front = -Y, up = +Z, 1 unit = 1 stud, pivot bottom centre.
Sizes follow the MezzanineOffice greybox blocks (filing cabinet 1.6 x 4.4 x 2.2, chair 1.8 wide,
desk 4.6 x 2.6 x 2.4, counter 4.9 x 3.0 x 2.1). One mesh per value region, coloured by Part.Color;
the meshes don't collide, invisible COL_ boxes do.
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

OUT = ROOT + "/office_furniture"


# --- shared helpers -------------------------------------------------------------------------------

def place(m, tag, build, mat):
	"""Build into a scratch mesh, then add it to m transformed by mat."""
	s = tk.Mesh()
	build(s)
	for vs, fs in s.parts.values():
		m.add(tag, [mat @ v for v in vs], fs)


def flat(u, v, w):
	"""slab() frame for horizontal plates: polygon in XY, extruded up Z."""
	return Vector((u, v, w))


def rect(x0, y0, x1, y1):
	return [(x1, y0), (x1, y1), (x0, y1), (x0, y0)]


def top_slab(m, tag, x0, y0, x1, y1, z0, z1, c):
	"""Thick slab with ONE chamfer on its top outer edge only (seam below stays sharp)."""
	tk.slab(m, rect(x0, y0, x1, y1), z0, z1, tag, c=c, frame=flat)


def post_box(m, tag, lo, hi, c):
	"""Box with its four vertical edges chamfered and flat ends (guide 4.5 post/body rule)."""
	cx, cy = (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2
	poly = tk.oct_poly(hi[0] - lo[0], hi[1] - lo[1], c)
	tk.hull(m, [(cx + u, cy + v, z) for u, v in poly for z in (lo[2], hi[2])], tag)


def disc(m, tag, r, z0, z1, x=0.0, y=0.0):
	tk.lathe(m, [(r, 0), (r, z1 - z0)], tag, center=(x, y, z0))


def wheel(m, tag, r, width, pos, yaw):
	"""Octagonal caster wheel, axle horizontal at heading yaw (radians), a flat facing down."""
	mat = Matrix.Translation(pos) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y")
	place(m, tag, lambda s: tk.lathe(s, [(r, -width / 2), (r, width / 2)], "t"), mat)


def bar_pull(m, tag, x0, x1, y_face, z, vertical=False, r=0.05):
	"""Chunky hex bar pull on two square standoffs, standing out from a front face at y_face (-Y)."""
	stand = 0.08
	yb = y_face - stand - r * 0.6
	if vertical:
		for zz in (x0 + 0.06, x1 - 0.06):  # x0/x1 are z extents for a vertical pull, z is its x
			tk.plain_box(m, (z - 0.04, y_face - stand, zz - 0.05), (z + 0.04, y_face, zz + 0.05), tag)
		tk.tube(m, [(z, yb, x0), (z, yb, x1)], r, tag, axis=(0, 1, 0))
	else:
		for xx in (x0 + 0.06, x1 - 0.06):
			tk.plain_box(m, (xx - 0.05, y_face - stand, z - 0.04), (xx + 0.05, y_face, z + 0.04), tag)
		tk.tube(m, [(x0, yb, z), (x1, yb, z)], r, tag, axis=(0, 1, 0))


def to_pivot(m):
	"""Move the mesh so the bounding box's bottom centre is the origin; return the offset."""
	lo, hi = tk.stats(m)["bbox"]
	off = (-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2])
	tk.translate(m, off)
	return off


def col_box(name, lo, hi, off):
	"""COL_ helper in pivot space (Roblox: x right, y up, z back = Blender y)."""
	ox, oy, oz = off
	return {"name": name, "size": (hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]),
			"pos": ((lo[0] + hi[0]) / 2 + ox, (lo[2] + hi[2]) / 2 + oz, (lo[1] + hi[1]) / 2 + oy)}


def helper_luau(group, anchor, hs, extra=""):
	if not hs:  # overhead / wall fixtures: no collision boxes, keep the imported pivot
		return (
			"\n" + 'for _, root in game:GetService("Selection"):Get() do\n'
			f'\tif root:IsA("Model") and root:FindFirstChild("{group}_{anchor}", true) then\n'
			+ extra + "\tend\nend\n"
		)
	rows = "\n".join(
		f'\t{{ "{h["name"]}", Vector3.new({h["size"][0]:.3f}, {h["size"][1]:.3f}, {h["size"][2]:.3f}), '
		f'Vector3.new({h["pos"][0]:.3f}, {h["pos"][1]:.3f}, {h["pos"][2]:.3f}) }},'
		for h in hs)
	return (
		"\n-- Collision helpers (guide 9.2): invisible anchored boxes; the meshes above don't collide.\n"
		"-- Offsets are from the model's bottom centre, front -Z.\n"
		"local helpers = {\n" + rows + "\n}\n"
		'for _, root in game:GetService("Selection"):Get() do\n'
		f'\tif root:IsA("Model") and root:FindFirstChild("{group}_{anchor}", true) then\n'
		"\t\tfor _, h in helpers do\n"
		"\t\t\tlocal old = root:FindFirstChild(h[1])\n"
		"\t\t\tif old then\n"
		"\t\t\t\told:Destroy()\n"
		"\t\t\tend\n"
		"\t\tend\n"
		"\t\tlocal cf, size = root:GetBoundingBox()\n"
		"\t\tlocal base = cf * CFrame.new(0, -size.Y / 2, 0)\n"
		"\t\troot.WorldPivot = base\n"
		"\t\tfor _, h in helpers do\n"
		'\t\t\tlocal p = Instance.new("Part")\n'
		"\t\t\tp.Name, p.Size = h[1], h[2]\n"
		"\t\t\tp.CFrame = base * CFrame.new(h[3])\n"
		"\t\t\tp.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false\n"
		"\t\t\tp.Transparency, p.CastShadow = 1, false\n"
		"\t\t\tp.Parent = root\n"
		"\t\tend\n"
		+ extra +
		"\tend\n"
		"end\n"
	)


# --- filing cabinet -------------------------------------------------------------------------------
# Four-drawer steel cabinet. Each drawer (front + hollow tray) is its own mesh with its own pull mesh,
# so the apply script can group them as Drawer1..Drawer4 (top to bottom) and slide them out along -Z.

FC_W, FC_D, FC_H = 1.6, 2.2, 4.4
FC_BAY = (0.26, 4.16)  # drawer bays between the bottom panel and the lock rail


def filing_cabinet():
	m = tk.Mesh()
	hx, hy = FC_W / 2, FC_D / 2
	ix = hx - 0.06  # inner face of the side sheets
	tk.plain_box(m, (-ix, -hy + 0.12, 0), (ix, hy - 0.06, 0.2), "plinth")
	for s in (-1, 1):
		tk.plain_box(m, (min(s * hx, s * ix), -hy, 0.2), (max(s * hx, s * ix), hy, FC_H - 0.08), "carcass")
	top_slab(m, "carcass", -hx, -hy, hx, hy, FC_H - 0.08, FC_H, 0.0)
	tk.plain_box(m, (-ix, -hy, 0.2), (ix, hy, FC_BAY[0]), "carcass")  # bottom panel
	tk.plain_box(m, (-ix, hy - 0.06, FC_BAY[0]), (ix, hy, FC_H - 0.08), "carcass")  # back
	tk.plain_box(m, (-ix, -hy, FC_BAY[1]), (ix, -hy + 0.14, FC_H - 0.08), "carcass")  # lock rail
	# Lock barrel on the rail, top right like the reference
	mat = Matrix.Translation((ix - 0.2, -hy, (FC_BAY[1] + FC_H - 0.08) / 2)) @ Matrix.Rotation(math.pi / 2, 4, "X")
	place(m, "lock", lambda s: tk.lathe(s, [(0.055, 0), (0.055, 0.05)], "t"), mat)
	pitch = (FC_BAY[1] - FC_BAY[0]) / 4
	for k in range(4):
		zlo = FC_BAY[1] - (k + 1) * pitch
		zhi = zlo + pitch
		if k < 3:  # rail behind the gap under this drawer
			tk.plain_box(m, (-ix, -hy + 0.08, zlo - 0.06), (ix, -hy + 0.18, zlo + 0.06), "carcass")
		tag = f"drawer{k + 1}"
		yf = -hy + 0.02  # fronts sit 0.02 back from the side sheets
		tk.plain_box(m, (-ix + 0.02, yf, zlo + 0.025), (ix - 0.02, yf + 0.06, zhi - 0.025), tag)
		# Hollow tray behind the front: bottom, sides, back, open top
		t0, t1, y1 = zlo + 0.1, zhi - 0.14, hy - 0.12
		tk.plain_box(m, (-0.66, yf + 0.06, t0), (0.66, y1, t0 + 0.04), tag)
		for s in (-1, 1):
			tk.plain_box(m, (min(s * 0.66, s * 0.62), yf + 0.06, t0 + 0.04), (max(s * 0.66, s * 0.62), y1, t1), tag)
		tk.plain_box(m, (-0.62, y1 - 0.04, t0 + 0.04), (0.62, y1, t1), tag)
		# Pull a little above centre, label holder top left
		pull = f"drawer{k + 1}_pull"
		bar_pull(m, pull, -0.32, 0.32, yf, zhi - 0.42 * pitch)
		tk.plain_box(m, (-0.6, yf - 0.025, zhi - 0.24), (-0.28, yf, zhi - 0.1), pull)
	off = to_pivot(m)
	palette = {"plinth": ("#3A3C3C", "Metal"), "carcass": ("#8F928E", "Metal"), "lock": ("#B89B5E", "Metal")}
	for k in range(4):
		palette[f"drawer{k + 1}"] = ("#A4A7A2", "Metal")
		palette[f"drawer{k + 1}_pull"] = ("#D0D0C8", "Metal")
	hs = [col_box("COL_Body", (-hx, -hy, 0), (hx, hy, FC_H), off)]
	extra = (
		"\t\t-- Each drawer and its pull become one Model, PrimaryPart = the drawer; it opens\n"
		"\t\t-- by pivoting along the cabinet's -Z (about 1.6 studs fully out).\n"
		"\t\tfor k = 1, 4 do\n"
		'\t\t\tlocal d = root:FindFirstChild("FilingCabinet_Drawer" .. k, true)\n'
		'\t\t\tlocal p = root:FindFirstChild("FilingCabinet_Drawer" .. k .. "Pull", true)\n'
		'\t\t\tif d and p and not root:FindFirstChild("Drawer" .. k) then\n'
		'\t\t\t\tlocal g = Instance.new("Model")\n'
		'\t\t\t\tg.Name = "Drawer" .. k\n'
		"\t\t\t\tg.Parent = root\n"
		"\t\t\t\td.Parent, p.Parent = g, g\n"
		"\t\t\t\tg.PrimaryPart = d\n"
		"\t\t\tend\n"
		"\t\tend\n"
	)
	clip = [("lock", "carcass")] + [(f"drawer{k + 1}_pull", f"drawer{k + 1}") for k in range(4)]
	return m, palette, hs, extra, "Carcass", clip, None


# --- office chair ---------------------------------------------------------------------------------
# Armless task chair, matched to the owner's photo: a plain slate-blue seat cushion on a thin dark
# pan, a separate blue back pad (rounded rectangle, no frame), two dark bent uprights between them,
# gas column, five-star base on octagonal casters. Rounded corners are 45-degree clips; the pads'
# soft edges are one chamfer top and bottom.

CH_SEAT = (1.34, 1.2, 0.04)  # width, depth, centre y: no wider than the back pad
CH_SEAT_TOP = 1.74
CH_BACK = (0.0, 0.8, 2.52)  # back pad centre, sitting low over the seat as in the photo
CH_BACK_SIZE = (1.36, 1.04)
CH_LEAN = math.radians(8)


def pad_hull(t, poly, frame, a0, a1, a2, a3, c0, c1):
	"""Cushion: poly inset c0 at a0, full poly a1..a2, inset c1 at a3 (frame maps (u, v, depth))."""
	pts = [frame(u, v, a0) for u, v in tk.inset_poly(poly, c0)]
	pts += [frame(u, v, a) for u, v in poly for a in (a1, a2)]
	pts += [frame(u, v, a3) for u, v in tk.inset_poly(poly, c1)]
	tk.hull(t, pts, "t")


def chair():
	m = tk.Mesh()
	# Five-star base: hub, tapered legs, caster forks and wheels
	disc(m, "base", 0.17, 0.24, 0.44)
	for k in range(5):
		a = math.pi / 2 + 2 * math.pi * k / 5  # one leg straight back
		d = Vector((math.cos(a), math.sin(a), 0))
		sd = Vector((-d.y, d.x, 0))
		pts = []
		for r, w, z0, z1 in ((0.1, 0.09, 0.26, 0.42), (0.8, 0.065, 0.26, 0.34)):
			for s in (-1, 1):
				for z in (z0, z1):
					pts.append(d * r + sd * (s * w) + Vector((0, 0, z)))
		tk.hull(m, pts, "base")
		tip = d * 0.78
		tk.plain_box(m, (tip.x - 0.06, tip.y - 0.06, 0.15), (tip.x + 0.06, tip.y + 0.06, 0.27), "base")
		wheel(m, "wheels", 0.1, 0.1, (tip.x + d.x * 0.05, tip.y + d.y * 0.05, 0.1), a)
	# Gas column: sleeve, piston, mechanism plate under the seat
	disc(m, "column", 0.11, 0.44, 1.02)
	disc(m, "column", 0.075, 1.02, 1.3)
	tk.plain_box(m, (-0.26, -0.26, 1.3), (0.26, 0.5, 1.4), "frame")
	tk.plain_box(m, (-0.42, 0.22, 1.3), (0.42, 0.5, 1.4), "frame")  # upright bracket
	# Height lever out of the left of the mechanism, ending in a paddle
	tk.tube(m, [(-0.2, -0.1, 1.35), (-0.56, -0.1, 1.35), (-0.7, -0.2, 1.35)], 0.035, "frame", axis=(0, 0, 1))
	tk.plain_box(m, (-0.86, -0.3, 1.32), (-0.68, -0.14, 1.38), "frame")
	# Seat: thin dark pan, then the blue cushion
	sw, sd_, sy = CH_SEAT
	pan = tk.oct_poly(sw - 0.2, sd_ - 0.2, 0.22)
	tk.hull(m, [(u, sy + v, z) for u, v in pan for z in (1.4, 1.46)], "under")
	seat = tk.oct_poly(sw, sd_, 0.22)
	place(m, "pad", lambda t: pad_hull(t, seat, lambda u, v, z: Vector((u, sy + v, z)),
										1.46, 1.51, 1.66, CH_SEAT_TOP, 0.05, 0.08), Matrix.Identity(4))
	# Back pad, built in back-local (x across, y out the back, z up) and leaned back
	bmat = Matrix.Translation(CH_BACK) @ Matrix.Rotation(-CH_LEAN, 4, "X")
	back = tk.oct_poly(*CH_BACK_SIZE, 0.18)
	place(m, "pad", lambda t: pad_hull(t, back, lambda u, v, y: Vector((u, y, v)),
										-0.11, -0.04, 0.05, 0.1, 0.07, 0.05), bmat)
	# Uprights: bracket on the back pad's rear, swan-neck bar down and forward into the seat bracket
	for x in (-0.3, 0.3):
		place(m, "frame", lambda t, x=x: tk.plain_box(t, (x - 0.08, 0.06, -0.44), (x + 0.08, 0.17, -0.02), "t"), bmat)
		end = bmat @ Vector((x, 0.12, -0.16))
		rr, z0 = 0.16, 1.35
		lean = CH_LEAN
		a3 = math.pi / 2 - lean  # arc ends heading up, leaning back
		arc_end_z = z0 + rr * (1 - math.cos(a3))
		arc_end_y = end.y - (end.z - arc_end_z) * math.tan(lean)
		yc = arc_end_y - rr * math.sin(a3)
		path = [(x, 0.3, z0), (x, yc, z0)]
		for t in (a3 / 2, a3):  # two ~40-degree joints
			path.append((x, yc + rr * math.sin(t), z0 + rr * (1 - math.cos(t))))
		path.append(tuple(end))
		tk.tube(m, path, 0.045, "frame", axis=(1, 0, 0))
	off = to_pivot(m)
	palette = {
		"pad": ("#56647A", "Sand"), "under": ("#2E3035", "Plastic"), "frame": ("#3E4044", "Metal"),
		"base": ("#333538", "Plastic"), "column": ("#6A6D71", "Metal"), "wheels": ("#1F2022", "Plastic"),
	}
	bw = CH_BACK_SIZE[0] / 2
	hs = [
		col_box("COL_Seat", (-sw / 2, sy - sd_ / 2, 0), (sw / 2, sy + sd_ / 2, CH_SEAT_TOP), off),
		col_box("COL_Back", (-bw, 0.68, CH_BACK[2] - 0.52), (bw, 1.05, CH_BACK[2] + 0.56), off),
	]
	clip = [("column", "base")]
	return m, palette, hs, "", "Pad", clip, None


# --- office desk ----------------------------------------------------------------------------------
# Cantilever desk: wood top with two cable grommets, grey steel C-frame legs (post at the back, foot
# running forward), wood modesty panel between the posts. Knee space ~4 studs wide and 2.2 high so
# the task chair (1.8 wide, seat 1.78) slides under.

DK_W, DK_D, DK_H = 4.6, 2.4, 2.6


def desk():
	m = tk.Mesh()
	hx, hy = DK_W / 2, DK_D / 2
	top_slab(m, "top", -hx, -hy, hx, hy, DK_H - 0.25, DK_H, 0.04)
	for gx in (-hx + 0.45, hx - 0.45):
		disc(m, "grommets", 0.12, DK_H, DK_H + 0.015, gx, hy - 0.35)
	ztop = DK_H - 0.25
	for s in (-1, 1):
		x = s * (hx - 0.25)
		tk.plain_box(m, (x - 0.11, -hy + 0.1, 0.06), (x + 0.11, hy - 0.2, 0.26), "frame")  # foot
		tk.plain_box(m, (x - 0.11, 0.5, 0.26), (x + 0.11, 0.8, ztop - 0.12), "frame")  # post
		tk.plain_box(m, (x - 0.11, -hy + 0.2, ztop - 0.12), (x + 0.11, hy - 0.15, ztop), "frame")  # arm
		for y0 in (-hy + 0.14, hy - 0.4):
			tk.plain_box(m, (x - 0.09, y0, 0), (x + 0.09, y0 + 0.16, 0.06), "feet")
	px = hx - 0.25 - 0.11  # posts' inner faces
	tk.plain_box(m, (-px - 0.05, 0.6, 0.85), (px + 0.05, 0.7, ztop - 0.12), "modesty")
	off = to_pivot(m)
	palette = {
		"top": ("#6E5B49", "Wood"), "modesty": ("#54463A", "Wood"), "frame": ("#8A8D90", "Metal"),
		"feet": ("#2A2B2D", "Plastic"), "grommets": ("#B5B3AD", "Plastic"),
	}
	hs = [col_box("COL_Top", (-hx, -hy, ztop), (hx, hy, DK_H), off)]
	for s in (-1, 1):
		x = s * (hx - 0.25)
		hs.append(col_box(f"COL_Leg{'L' if s < 0 else 'R'}", (x - 0.11, -hy + 0.1, 0), (x + 0.11, hy - 0.15, ztop), off))
	hs.append(col_box("COL_Modesty", (-px, 0.6, 0.85), (px, 0.7, ztop - 0.12), off))
	clip = [("modesty", "frame")]
	return m, palette, hs, "", "Top", clip, None


# --- portable whiteboard --------------------------------------------------------------------------
# Plain white board in a dark aluminium frame with a marker tray, tilted back on pivot hubs between
# two hex uprights; H feet on octagonal casters, a hex crossbar low between the uprights.

WB_HUB_Z = 4.0
WB_TILT = math.radians(8)
WB_X = 3.95  # upright centres


def whiteboard():
	m = tk.Mesh()
	for s in (-1, 1):
		x = s * WB_X
		tk.plain_box(m, (x - 0.13, -1.1, 0.22), (x + 0.13, 1.1, 0.42), "stand")  # foot
		# Hex upright (flats face the board, so the hub seats flat) and a wider hex cap
		tk.tube(m, [(x, 0, 0.42), (x, 0, 5.3)], 0.12, "stand", axis=(1, 0, 0))
		tk.tube(m, [(x, 0, 5.3), (x, 0, 5.38)], 0.15, "stand", axis=(1, 0, 0))
		for y in (-0.95, 0.95):
			tk.plain_box(m, (x - 0.07, y - 0.07, 0.15), (x + 0.07, y + 0.07, 0.22), "stand")
			wheel(m, "wheels", 0.11, 0.1, (x, y, 0.11), 0)
		# Pivot hub into the board's side frame, tension knob outside
		mat = Matrix.Translation((x, 0, WB_HUB_Z)) @ Matrix.Rotation(s * math.pi / 2, 4, "Y")
		place(m, "hubs", lambda t: tk.lathe(t, [(0.12, -0.3), (0.12, -0.1)], "t"), mat)
		place(m, "knobs", lambda t: tk.lathe(t, [(0.1, 0.12), (0.1, 0.24)], "t"), mat)
	tk.tube(m, [(-WB_X + 0.06, 0, 1.1), (WB_X - 0.06, 0, 1.1)], 0.09, "stand", axis=(0, 1, 0))  # hex crossbar
	bmat = Matrix.Translation((0, 0, WB_HUB_Z)) @ Matrix.Rotation(-WB_TILT, 4, "X")
	bw, bh, fw = 3.72, 2.2, 0.16  # half width, half height, frame width

	def board(t):
		tk.plain_box(t, (-bw + fw, -0.03, -bh + fw), (bw - fw, 0.03, bh - fw), "board")
		tk.plain_box(t, (-bw, -0.07, bh - fw), (bw, 0.07, bh), "frame")
		tk.plain_box(t, (-bw, -0.07, -bh), (bw, 0.07, -bh + fw), "frame")
		for s in (-1, 1):
			tk.plain_box(t, (min(s * bw, s * (bw - fw)), -0.07, -bh + fw), (max(s * bw, s * (bw - fw)), 0.07, bh - fw), "frame")
		tk.plain_box(t, (-2.0, -0.34, -bh), (2.0, -0.07, -bh + 0.05), "frame")  # marker tray
		tk.plain_box(t, (-2.0, -0.34, -bh + 0.05), (2.0, -0.3, -bh + 0.13), "frame")  # its lip

	b = tk.Mesh()
	board(b)
	for tag, (vs, fs) in b.parts.items():
		m.add(tag, [bmat @ v for v in vs], fs)
	off = to_pivot(m)
	palette = {
		"board": ("#E2E3DF", "SmoothPlastic"), "frame": ("#4A4D52", "Metal"), "stand": ("#3A3C40", "Metal"),
		"hubs": ("#2C2E31", "Metal"), "knobs": ("#B9B9B3", "Metal"), "wheels": ("#1F2022", "Plastic"),
	}
	hs = [col_box(f"COL_Stand{'L' if s < 0 else 'R'}", (s * WB_X - 0.15, -1.1, 0), (s * WB_X + 0.15, 1.1, 5.38), off)
		  for s in (-1, 1)]
	# Board slab as an upright box covering the tilted board's footprint
	hs.append(col_box("COL_Board", (-bw, -0.45, WB_HUB_Z - bh), (bw, 0.45, WB_HUB_Z + bh), off))
	clip = [("hubs", "stand")]
	return m, palette, hs, "", "Board", clip, None


# --- office counter -------------------------------------------------------------------------------
# Base cabinet with a laminate top: a door pair with raised panels on the left, a bank of three
# drawers on the right, pale bar pulls, a recessed dark plinth.

CT_W, CT_D, CT_H = 4.9, 2.1, 3.0


def counter():
	m = tk.Mesh()
	hx, hy = CT_W / 2, CT_D / 2
	bx, by = hx - 0.05, hy - 0.05
	top_slab(m, "top", -hx, -hy, hx, hy, CT_H - 0.25, CT_H, 0.05)
	tk.plain_box(m, (-bx, -by, 0.25), (bx, by, CT_H - 0.25), "carcass")
	tk.plain_box(m, (-bx + 0.08, -by + 0.15, 0), (bx - 0.08, by - 0.05, 0.25), "plinth")
	yf = -by  # carcass front face
	z0, z1 = 0.32, CT_H - 0.32
	x0 = -bx + 0.06
	split = x0 + 3.1
	gap = 0.04
	dw = (3.1 - gap) / 2
	for i in range(2):
		a = x0 + i * (dw + gap)
		b = a + dw
		tk.plain_box(m, (a, yf - 0.06, z0), (b, yf, z1), "doors")
		# Raised panel: margin 0.16, one 45-degree bevel; the pull side gets a wider stile so the
		# pull's standoffs seat flat on the door, clear of the panel's bevel.
		wide = 0.36
		poly = rect(a + (0.16 if i == 0 else wide), z0 + 0.16, b - (wide if i == 0 else 0.16), z1 - 0.16)
		pts = [(u, yf - 0.06, v) for u, v in poly] + [(u, yf - 0.1, v) for u, v in tk.inset_poly(poly, 0.04)]
		tk.hull(m, pts, "panels")
		px = b - wide / 2 if i == 0 else a + wide / 2
		bar_pull(m, "pulls", z1 - 0.75, z1 - 0.2, yf - 0.06, px, vertical=True)
	dx0, dx1 = split + gap, bx - 0.06
	dh = (z1 - z0 - 2 * gap) / 3
	for k in range(3):
		a = z0 + k * (dh + gap)
		tk.plain_box(m, (dx0, yf - 0.06, a), (dx1, yf, a + dh), "doors")
		bar_pull(m, "pulls", (dx0 + dx1) / 2 - 0.3, (dx0 + dx1) / 2 + 0.3, yf - 0.06, a + dh * 0.62)
	off = to_pivot(m)
	palette = {
		"top": ("#A9A8A3", "SmoothPlastic"), "carcass": ("#3F4246", "Plastic"), "doors": ("#4A4E53", "Plastic"),
		"panels": ("#555A60", "Plastic"), "pulls": ("#BDBDB6", "Metal"), "plinth": ("#26282A", "Plastic"),
	}
	hs = [col_box("COL_Body", (-hx, -hy, 0), (hx, hy, CT_H), off)]
	clip = [("panels", "doors"), ("pulls", "doors")]
	return m, palette, hs, "", "Top", clip, None


# --- coffee machine -------------------------------------------------------------------------------
# Drip coffee maker: dark body (water-tank column and an overhanging head), filter basket under the
# head, a hollow octagonal glass carafe with coffee inside, collar, lid and swan-neck handle, warming
# plate, water window on the side, rocker switch and an amber power light.

CM_PLATE = (0.0, -0.15)  # carafe axis


def coffee_machine():
	m = tk.Mesh()
	cx, cy = CM_PLATE
	post_box(m, "base", (-0.45, -0.58, 0), (0.45, 0.45, 0.16), 0.06)
	disc(m, "plate", 0.33, 0.16, 0.19, cx, cy)
	post_box(m, "body", (-0.42, 0.1, 0.16), (0.42, 0.45, 1.08), 0.06)
	post_box(m, "body", (-0.45, -0.6, 1.08), (0.45, 0.47, 1.38), 0.08)
	tk.lathe(m, [(0.27, 0), (0.32, 0.05), (0.32, 0.13)], "trim", center=(cx, cy, 0.95))  # filter basket
	# Carafe: hollow two-wall glass shell, open neck (guide Sec 11 shell rule)
	zc = 0.19
	loop = [(0, 0), (0.27, 0), (0.31, 0.04), (0.31, 0.44), (0.25, 0.5), (0.25, 0.64),
			(0.22, 0.64), (0.22, 0.51), (0.28, 0.45), (0.28, 0.07), (0.25, 0.04), (0, 0.04)]
	tk.lathe(m, loop, "glass", center=(cx, cy, zc), cap_bottom=False, cap_top=False)
	tk.lathe(m, [(0.235, 0.045), (0.265, 0.075), (0.265, 0.34)], "coffee", center=(cx, cy, zc))
	tk.lathe(m, [(0.275, 0.55), (0.275, 0.64)], "trim", center=(cx, cy, zc))  # collar
	tk.lathe(m, [(0.275, 0.64), (0.275, 0.68), (0.23, 0.72)], "trim", center=(cx, cy, zc))  # lid
	# Handle: out of the collar, two 45-degree joints down, two back into the glass
	hz = lambda z: zc + z  # noqa: E731
	tk.tube(m, [(-0.24, cy, hz(0.6)), (-0.4, cy, hz(0.6)), (-0.47, cy, hz(0.53)), (-0.47, cy, hz(0.22)),
				(-0.4, cy, hz(0.15)), (-0.29, cy, hz(0.15))], 0.04, "trim", axis=(0, 1, 0))
	tk.plain_box(m, (0.42, 0.16, 0.36), (0.445, 0.34, 0.98), "window")
	tk.plain_box(m, (-0.34, -0.63, 1.18), (-0.16, -0.6, 1.29), "switch")
	tk.plain_box(m, (-0.1, -0.62, 1.21), (-0.05, -0.6, 1.26), "indicator")
	off = to_pivot(m)
	palette = {
		"body": ("#3C3F43", "Plastic"), "base": ("#2E3033", "Plastic"), "trim": ("#222326", "Plastic"),
		"plate": ("#8E9093", "Metal"), "glass": ("#D4DCDE", "Glass"), "coffee": ("#6E3B24", "SmoothPlastic"),
		"window": ("#6F8088", "Glass"), "switch": ("#C2C3BE", "SmoothPlastic"), "indicator": ("#FFA25A", "Neon"),
	}
	hs = [col_box("COL_Body", (-0.45, -0.6, 0), (0.45, 0.47, 1.38), off)]
	extra = (
		"\t\tfor _, p in root:GetDescendants() do\n"
		'\t\t\tif p.Name == "CoffeeMachine_Glass" then\n'
		"\t\t\t\tp.Transparency = 0.6\n"
		'\t\t\telseif p.Name == "CoffeeMachine_Window" then\n'
		"\t\t\t\tp.Transparency = 0.35\n"
		"\t\t\tend\n"
		"\t\tend\n"
	)
	light = {"part": "CoffeeMachine_Indicator", "range": 1.5, "brightness": 0.4, "shadows": False, "color": "#FFB06A"}
	clip = [("coffee", "glass")]
	return m, palette, hs, extra, "Body", clip, light


# --- twin-tube ceiling light ----------------------------------------------------------------------
# Surface-mounted fluorescent fitting (target: the owner's screenshot): dark housing with ballast
# blocks on top at each end, a pale aluminium tray (clipped corners, rim, V divider down the middle)
# and two octagonal Neon tubes in dark end sockets. Pivot top centre; the open face looks down.

TL_W, TL_L = 2.3, 5.0
TL_TUBE_X, TL_TUBE_Z, TL_TUBE_R = 0.58, -0.74, 0.15


def tube_light():
	m = tk.Mesh()
	outer = tk.oct_poly(TL_W, TL_L, 0.3)
	inner = tk.inset_poly(outer, 0.16)
	for x in (-0.55, 0.55):
		for y in (-(TL_L / 2 - 0.45), TL_L / 2 - 0.45):
			post_box(m, "housing", (x - 0.35, y - 0.25, -0.2), (x + 0.35, y + 0.25, 0), 0.12)  # ballast
	tk.hull(m, [(u, v, z) for u, v in outer for z in (-0.55, -0.2)], "housing")
	# Tray rim: one mitred strip per edge of the clipped outline
	for i in range(len(outer)):
		j = (i + 1) % len(outer)
		quad = [outer[i], outer[j], inner[j], inner[i]]
		tk.hull(m, [(u, v, z) for u, v in quad for z in (-0.75, -0.55)], "tray")
	tk.hull(m, [(u, v, z) for u, v in inner for z in (-0.6, -0.55)], "reflector")
	ly = TL_L / 2 - 0.16
	tk.hull(m, [(x, y, z) for x, z in ((-0.18, -0.6), (0.18, -0.6), (0, -0.72)) for y in (-ly, ly)], "tray")
	for x in (-TL_TUBE_X, TL_TUBE_X):
		mat = Matrix.Translation((x, 0, TL_TUBE_Z)) @ Matrix.Rotation(math.pi / 2, 4, "X")
		place(m, "tubes", lambda t: tk.lathe(t, [(TL_TUBE_R, -2.12), (TL_TUBE_R, 2.12)], "t"), mat)
		for s in (-1, 1):
			y0, y1 = sorted((s * 2.1, s * 2.34))
			mat = Matrix.Translation((x, 0, TL_TUBE_Z)) @ Matrix.Rotation(math.pi / 2, 4, "X")
			place(m, "sockets", lambda t, a=y0, b=y1: tk.lathe(t, [(0.19, -b), (0.19, -a)], "t"), mat)
	lo, hi = tk.stats(m)["bbox"]
	tk.translate(m, (-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -hi[2]))  # top centre
	palette = {
		"housing": ("#26282B", "Metal"), "tray": ("#B7BABE", "Metal"), "reflector": ("#9EA2A7", "Metal"),
		"tubes": ("#EEF4FF", "Neon"), "sockets": ("#3A3C40", "Metal"),
	}
	extra = (
		'\t\tlocal tubes = root:FindFirstChild("TubeLight_Tubes", true)\n'
		'\t\tif tubes and not tubes:FindFirstChildWhichIsA("Light") then\n'
		"\t\t\t-- Two layers (guide Sec 8): a small glow, and a shadowed pool on the floor.\n"
		'\t\t\tlocal glow = Instance.new("PointLight")\n'
		"\t\t\tglow.Range, glow.Brightness, glow.Shadows = 8, 0.5, false\n"
		'\t\t\tglow.Color = Color3.fromHex("#DDE8FF")\n'
		"\t\t\tglow.Parent = tubes\n"
		'\t\t\tlocal pool = Instance.new("SpotLight")\n'
		"\t\t\tpool.Face, pool.Angle = Enum.NormalId.Bottom, 120\n"
		"\t\t\tpool.Range, pool.Brightness, pool.Shadows = 45, 1.5, true\n"
		'\t\t\tpool.Color = Color3.fromHex("#E4ECFF")\n'
		"\t\t\tpool.Parent = tubes\n"
		"\t\tend\n"
	)
	clip = [("sockets", "reflector")]
	return m, palette, [], extra, "Tubes", clip, None


# --- wall speaker ---------------------------------------------------------------------------------
# PA speaker box (target: the owner's screenshot): a square body with a wide 45-degree front bevel,
# an octagonal grille bulging out as a dome (rim, dark dome, a grid of bars bent over it) and a small dark panel with a green and an
# amber diamond LED. Pivot back centre on the wall, front -Z.

WS_W, WS_H, WS_D = 1.5, 1.6, 0.42
WS_GRILLE = (0.0, 0.12, 0.49)  # centre u, v, half size
WS_DOME = 0.2  # how far the grille bulges past the front face


def chord(poly, axis, val):
	"""Extent along the other axis where the line coord[axis] == val crosses a convex polygon."""
	hits = []
	for i in range(len(poly)):
		a, b = poly[i], poly[(i + 1) % len(poly)]
		if (a[axis] - val) * (b[axis] - val) <= 0 and a[axis] != b[axis]:
			t = (val - a[axis]) / (b[axis] - a[axis])
			hits.append(a[1 - axis] + t * (b[1 - axis] - a[1 - axis]))
	return min(hits), max(hits)


def wall_speaker():
	m = tk.Mesh()
	tk.slab(m, rect(-WS_W / 2, -WS_H / 2, WS_W / 2, WS_H / 2), 0, WS_D, "body", c=0.12)
	gu, gv, gr = WS_GRILLE
	outer = [(u + gu, v + gv) for u, v in tk.oct_poly(2 * gr, 2 * gr, gr * 0.6)]
	inner = tk.inset_poly(outer, 0.07)
	for i in range(len(outer)):
		j = (i + 1) % len(outer)
		quad = [outer[i], outer[j], inner[j], inner[i]]
		tk.hull(m, [tk.wall_frame(u, v, w) for u, v in quad for w in (WS_D, WS_D + 0.08)], "grille")
	# The grille bulges out: a dark octagonal dome inside the rim, the bar grid bent over it
	rin = gr - 0.07
	rc = rin / math.cos(math.pi / 8)  # dome reaches zero height at the octagon's corners

	def dome(du, dv):
		return WS_DOME * max(0.0, 1 - (du * du + dv * dv) / (rc * rc))

	prof = [(rin, 0.0)] + [(rin * f, dome(rin * f, 0)) for f in (0.72, 0.4)] + [(0, WS_DOME)]
	mat = Matrix.Translation((gu, -WS_D, gv)) @ Matrix.Rotation(math.pi / 2, 4, "X")
	place(m, "grille_back", lambda t: tk.lathe(t, prof, "t"), mat)
	for k in range(-2, 3):  # 5 x 5 grid, four facets per bar, ends buried in the rim
		c = 0.16 * k
		v0, v1 = chord(inner, 0, gu + c)
		pts = [(gu + c, v0 + (v1 - v0) * t / 4) for t in range(5)]
		tk.tube(m, [tk.wall_frame(u, v, WS_D + 0.02 + dome(u - gu, v - gv)) for u, v in pts], 0.024, "grille",
				axis=(1, 0, 0))
		u0, u1 = chord(inner, 1, gv + c)
		pts = [(u0 + (u1 - u0) * t / 4, gv + c) for t in range(5)]
		tk.tube(m, [tk.wall_frame(u, v, WS_D + 0.045 + dome(u - gu, v - gv)) for u, v in pts], 0.024, "grille",
				axis=(0, 0, 1))
	tk.slab(m, rect(0.16, -0.62, 0.6, -0.44), WS_D, WS_D + 0.03, "panel")
	for tag, cu in (("led_green", 0.28), ("led_amber", 0.48)):
		d = 0.05
		cv = -0.53
		tk.slab(m, [(cu + d, cv), (cu, cv + d), (cu - d, cv), (cu, cv - d)], WS_D + 0.03, WS_D + 0.06, tag)
	palette = {
		"body": ("#4B5059", "Plastic"), "grille_back": ("#1C1D20", "Plastic"), "grille": ("#34373C", "Metal"),
		"panel": ("#26282C", "Plastic"), "led_green": ("#5CFF6E", "Neon"), "led_amber": ("#FF9A50", "Neon"),
	}
	extra = (
		'\t\tfor name, hex in { WallSpeaker_LedGreen = "#5CFF6E", WallSpeaker_LedAmber = "#FF9A50" } do\n'
		"\t\t\tlocal led = root:FindFirstChild(name, true)\n"
		'\t\t\tif led and not led:FindFirstChildWhichIsA("Light") then\n'
		'\t\t\t\tlocal l = Instance.new("PointLight")\n'
		"\t\t\t\tl.Range, l.Brightness, l.Shadows = 1, 0.3, false\n"
		"\t\t\t\tl.Color = Color3.fromHex(hex)\n"
		"\t\t\t\tl.Parent = led\n"
		"\t\t\tend\n"
		"\t\tend\n"
	)
	return m, palette, [], extra, "Body", [], None


# --- driver ---------------------------------------------------------------------------------------

PROPS = {
	"FilingCabinet": filing_cabinet,
	"OfficeChair": chair,
	"OfficeDesk": desk,
	"Whiteboard": whiteboard,
	"OfficeCounter": counter,
	"CoffeeMachine": coffee_machine,
	"TubeLight": tube_light,
	"WallSpeaker": wall_speaker,
}
PIVOTS = {"TubeLight": "Pivot top centre, open face down", "WallSpeaker": "Pivot back centre, front -Z"}


def build_one(name):
	for ob in [o for o in bpy.data.objects if o.name == name or o.name.startswith(name + "_")]:
		bpy.data.objects.remove(ob, do_unlink=True)
	m, palette, hs, extra, anchor, clip, light = PROPS[name]()
	audits = {"mesh": tk.audit_mesh(m), "clip": tk.audit_clipping(m, clip) if clip else []}
	st = tk.stats(m)
	group, parts = tk.to_blender(name, m, palette)
	audits["style"] = tk.audit_style(parts)
	return group, parts, st, audits, hs, extra, anchor, light


def export_one(name, group, parts, st, hs, extra, anchor, light):
	os.makedirs(OUT, exist_ok=True)
	fbx = tk.export_fbx(f"{OUT}/{name}.fbx", group, colors_type="NONE")
	size = " x ".join(f"{v:.2f}" for v in (st["size"][0], st["size"][2], st["size"][1]))
	tk.write_handoff(OUT, name, parts, light=light, attributes={"Biome": "Office", "Interactable": False},
					 note=f"Doors guide v24, {st['tris']} tris, {size} studs (W x H x D). "
					 f"{PIVOTS.get(name, 'Pivot bottom centre, front -Z')}. Colour is Part.Color (no vertex "
					 "colour in the FBX). " + ("COL_ helper parts collide." if hs else "Meshes don't collide."),
					 part_color=True)
	with open(f"{OUT}/{name}_apply_materials.luau", "a") as f:
		f.write(helper_luau(name, anchor, hs, extra))
	shutil.copy(fbx, f"{ROOT}/factory_fbx/{name}.fbx")


def run_all(names=None, save=True):
	report = {}
	x = 0.0
	for name in names or PROPS:
		group, parts, st, audits, hs, extra, anchor, light = build_one(name)
		export_one(name, group, parts, st, hs, extra, anchor, light)
		report[name] = {"tris": st["tris"], "size_xyz": st["size"], "degenerate": st["degenerate"],
						"per_tag": st["per_tag"], "audits": audits}
		w = st["size"][0]
		group.location.x = x + w / 2  # lay them out side by side in the saved file only
		x += w + 1.5
	if save:
		bpy.ops.wm.save_as_mainfile(filepath=f"{OUT}/OfficeFurniture.blend")
	return report
