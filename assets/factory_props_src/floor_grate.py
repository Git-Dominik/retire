"""Floor grate (Doors asset guide v24, target mode): a recessed industrial floor grating with
pipes running through the pit below it.

Run inside Blender (MCP execute). Builds with assets/WallLights/doors_toolkit.py, exports
assets/floor_grate/FloorGrate.fbx + hand-off, and copies the FBX to assets/factory_fbx/.
Blender axes: front = -Y, up = +Z, 1 unit = 1 stud, pivot bottom centre of the pit. The deck
(frame band and grate tops) is at z = DECK, so sink the model DECK studs below the floor.
Target traits: a diagonal (45-degree) lattice of thin flat strips, cut by an exact boolean so
the edge cells are triangles; a thick edge bar round it with proud square corner blocks; a wide
frame band with a chamfered inner edge; the grate on a ledge, held up by two beams; pipes stacked
at three depths in the pit (cream high on posts, red mid, blue and dark low on saddles).
One mesh per value region, coloured by Part.Color.
"""

import math
import os
import shutil
import sys

import bmesh
import bpy

ROOT = "/home/omar/retire/assets"
sys.path.insert(0, ROOT + "/WallLights")
import doors_toolkit as tk  # noqa: E402

OUT = ROOT + "/floor_grate"
OUTER = 5.75  # half footprint
OPEN = 5.0  # half opening inside the frame band (and the pit walls' inner face)
DECK = 3.0  # frame and grate top
BAND_T, BAND_C = 0.3, 0.08  # frame band thickness, inner top chamfer
LEDGE_W, LEDGE_T = 0.4, 0.2
GRATE_GAP = 0.05  # grate edge to frame band
EDGE_W, EDGE_H = 0.35, 0.3  # grate's edge bar
CORNER, CORNER_UP = 0.5, 0.06  # corner block size, how far it stands proud of the deck
# Strip spacing (perpendicular), width, thickness. The pattern repeats every LAT_PITCH * sqrt(2)
# along x; 12 repeats per tile width keeps it continuous across the seams of the open variants.
LAT_PITCH, LAT_W, LAT_T = 2 * OUTER / (12 * math.sqrt(2)), 0.18, 0.18
LAT_DROP = 0.03  # lattice top below the edge bar, so the buried part never z-fights
BEAM_X, BEAM_W, BEAM_H = (-3.3, 3.3), 0.3, 0.35
FLOOR_T = 0.2
SADDLE_H = 0.25
HIGH, MID = 2.0, 1.3  # pipe centre heights; low pipes sit on saddles
# (tag, y, radius, height or None for low, joint flange x positions)
PIPES = [
	("pipe_cream", -4.0, 0.35, HIGH, (1.4,)),
	("pipe_blue", -2.9, 0.5, None, (-2.0,)),
	("pipe_cream", -1.8, 0.3, HIGH, ()),
	("pipe_dark", -0.9, 0.3, None, (0.6,)),
	("pipe_red", 0.4, 0.5, MID, (-0.8,)),
	("pipe_cream", 1.7, 0.35, HIGH, (2.2,)),
	("pipe_blue", 2.9, 0.45, None, ()),
	("pipe_dark", 4.0, 0.22, MID, (-1.5,)),
]
SADDLE_X = (-2.4, 2.4)

REGIONS = {
	"band": "frame",
	"lattice": "grate", "edge": "grate", "corners": "grate",
	"walls": "liner", "ledge": "liner", "beams": "liner",
	"floor": "pit_floor",
	"pipe_red": "pipe_red", "pipe_blue": "pipe_blue", "pipe_dark": "pipe_dark",
	"pipe_cream": "pipe_cream",
	"flanges": "fittings", "saddles": "fittings",
}
PALETTE = {
	"frame": ("#4A4744", "DiamondPlate"),
	"grate": ("#3E3430", "DiamondPlate"),
	"liner": ("#2C2926", "Metal"),
	"pit_floor": ("#363431", "DiamondPlate"),
	"pipe_red": ("#7A3C3A", "DiamondPlate"),
	"pipe_blue": ("#525C7A", "DiamondPlate"),
	"pipe_dark": ("#3E3A36", "Metal"),
	"pipe_cream": ("#A89E8A", "DiamondPlate"),
	"fittings": ("#8A847A", "Metal"),
}
# Model name -> open ends (-1 = left / -X, 1 = right / +X). An open end has no wall, band side,
# edge bar or corner blocks: the pit, lattice, ledges and pipes run on to the tile's edge, so tiles
# laid 2 * OUTER apart along x join into one long trench (OpenR, then OpenLR..., then OpenL).
VARIANTS = {
	"FloorGrate": (),
	"FloorGrateOpenL": (-1,),
	"FloorGrateOpenR": (1,),
	"FloorGrateOpenLR": (-1, 1),
}


def band_side(m, sx, sy, opens=()):
	"""One side of the frame band, mitred at the corners, inner top edge chamfered.
	(sx, sy) is the outward direction; d is depth in from the outer edge. A y side runs square to
	the tile's edge at an open end."""
	z0, z1 = DECK - BAND_T, DECK
	w = OUTER - OPEN
	pts = []
	for d, z in ((0, z0), (0, z1), (w, z0), (w, z1 - BAND_C), (w - BAND_C, z1)):
		for s in (-1, 1):
			# the mitre keeps each edge's ends on the 45-degree corner line
			along = OUTER if not sx and s in opens else OUTER - d
			if sx:
				pts.append((sx * (OUTER - d), s * along, z))
			else:
				pts.append((s * along, sy * (OUTER - d), z))
	tk.hull(m, pts, "band")


def _box_obj(name, verts_faces):
	me = bpy.data.meshes.new(name)
	me.from_pydata(*verts_faces)
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def lattice(m, x0, x1, half, z0, z1):
	"""Plate from x0 to x1 and +-half in y with diamond holes cut out (exact boolean): what is left
	is two sets of flat strips at +-45 degrees, LAT_PITCH apart, LAT_W wide, flush and joined at
	every crossing. The holes stay on the same grid whatever the plate's extent."""
	plate_v = [(x, y, z) for x in (x0, x1) for y in (-half, half) for z in (z0, z1)]
	plate_f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
	plate = _box_obj("_lat_plate", (plate_v, [], plate_f))
	hd = (LAT_PITCH - LAT_W) / 2 * math.sqrt(2)  # hole half-diagonal, along x and y
	n = int(max(-x0, x1, half) * math.sqrt(2) / LAT_PITCH) + 2
	cv, cf = [], []
	for i in range(-n, n):
		for j in range(-n, n):
			u, v = (i + 0.5) * LAT_PITCH, (j + 0.5) * LAT_PITCH
			cx, cy = (u + v) / math.sqrt(2), (u - v) / math.sqrt(2)
			if cx - hd >= x1 or cx + hd <= x0 or abs(cy) - hd >= half:
				continue
			o = len(cv)
			ring = [(cx + hd, cy), (cx, cy + hd), (cx - hd, cy), (cx, cy - hd)]
			cv += [(x, y, z0 - 0.1) for x, y in ring] + [(x, y, z1 + 0.1) for x, y in ring]
			cf += [(o + 3, o + 2, o + 1, o), (o + 4, o + 5, o + 6, o + 7)]
			cf += [(o + k, o + (k + 1) % 4, o + 4 + (k + 1) % 4, o + 4 + k) for k in range(4)]
	cutter = _box_obj("_lat_cut", (cv, [], cf))
	mod = plate.modifiers.new("cut", "BOOLEAN")
	mod.operation, mod.solver, mod.object = "DIFFERENCE", "EXACT", cutter
	dg = bpy.context.evaluated_depsgraph_get()
	bm = bmesh.new()
	bm.from_mesh(plate.evaluated_get(dg).to_mesh())
	bmesh.ops.dissolve_degenerate(bm, dist=1e-4, edges=bm.edges)
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), verts=bm.verts, edges=bm.edges)
	bm.verts.index_update()
	m.add("lattice", [v.co.copy() for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces])
	bm.free()
	for ob in (plate, cutter):
		me = ob.data
		bpy.data.objects.remove(ob, do_unlink=True)
		bpy.data.meshes.remove(me)


def build(opens=()):
	"""opens: the x ends (-1, 1) left open so the tile joins its neighbour (see VARIANTS)."""
	def reach(s, closed):
		"""How far the y-side pieces run towards end s: the tile's edge if open."""
		return s * (OUTER if s in opens else closed)

	m = tk.Mesh()
	for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
		if sx not in opens:
			band_side(m, sx, sy, opens)

	# Pit liner: north/south walls run full width, east/west fit between them
	wz0, wz1 = FLOOR_T, DECK - BAND_T
	for s in (-1, 1):
		lo, hi = sorted((s * OPEN, s * OUTER))
		tk.plain_box(m, (-OUTER, lo, wz0), (OUTER, hi, wz1), "walls")
		if s not in opens:
			tk.plain_box(m, (lo, -OPEN, wz0), (hi, OPEN, wz1), "walls")
	tk.plain_box(m, (-OUTER, -OUTER, 0), (OUTER, OUTER, FLOOR_T), "floor")

	# Ledge the grate's edge bar rests on, against the walls' inner faces
	lz1 = DECK - EDGE_H
	lz0 = lz1 - LEDGE_T
	li = OPEN - LEDGE_W
	for s in (-1, 1):
		lo, hi = sorted((s * li, s * OPEN))
		tk.plain_box(m, (reach(-1, OPEN), lo, lz0), (reach(1, OPEN), hi, lz1), "ledge")
		if s not in opens:
			tk.plain_box(m, (lo, -li, lz0), (hi, li, lz1), "ledge")

	# Grate: edge bars run between proud corner blocks; the lattice's rim is buried in the bars
	go = OPEN - GRATE_GAP
	gi = go - EDGE_W
	ci = go - CORNER
	for s in (-1, 1):
		lo, hi = sorted((s * gi, s * go))
		tk.plain_box(m, (reach(-1, ci), lo, lz1), (reach(1, ci), hi, DECK), "edge")
		if s in opens:
			continue
		tk.plain_box(m, (lo, -ci, lz1), (hi, ci, DECK), "edge")
		for t in (-1, 1):
			xl, xh = sorted((s * ci, s * go))
			yl, yh = sorted((t * ci, t * go))
			tk.plain_box(m, (xl, yl, lz1), (xh, yh, DECK + CORNER_UP), "corners")
	lat1 = DECK - LAT_DROP
	lat0 = lat1 - LAT_T
	lattice(m, reach(-1, gi + 0.05), reach(1, gi + 0.05), gi + 0.05, lat0, lat1)

	# Beams under the lattice, ends buried in the ledges
	for x in BEAM_X:
		tk.plain_box(m, (x - BEAM_W / 2, -li - 0.1, lat0 - BEAM_H), (x + BEAM_W / 2, li + 0.1, lat0), "beams")

	# Pipes run along X into the walls; wall flanges, joint flanges, saddles or posts to the floor
	for tag, y, r, zc, joints in PIPES:
		zc = zc or FLOOR_T + SADDLE_H + r
		tk.tube(m, [(reach(-1, OPEN + 0.4), y, zc), (reach(1, OPEN + 0.4), y, zc)], r, tag,
				axis=(0, 0, 1), sides=8)
		for s in (-1, 1):
			if s in opens:
				continue
			a, b = sorted((s * (OPEN - 0.15), s * OPEN))
			tk.tube(m, [(a, y, zc), (b, y, zc)], r + 0.09, "flanges", axis=(0, 0, 1), sides=8)
		for x in joints:
			tk.tube(m, [(x - 0.12, y, zc), (x + 0.12, y, zc)], r + 0.12, "flanges", axis=(0, 0, 1), sides=8)
		post = zc - r - FLOOR_T > 0.5  # tall supports are slim posts, short ones squat saddles
		hw, hd = (0.1, 0.12) if post else (0.16, r * 0.85)
		for x in SADDLE_X:
			tk.plain_box(m, (x - hw, y - hd, FLOOR_T), (x + hw, y + hd, zc - r * 0.55), "saddles")
	return m


CLIP_PAIRS = [
	("pipe_cream", "beams"), ("pipe_red", "beams"), ("pipe_cream", "ledge"),
	("pipe_dark", "pipe_red"), ("pipe_blue", "pipe_cream"), ("edge", "band"), ("corners", "band"),
]


def helper_luau(name):
	return (
		"\n-- Collision helper (guide 9.2): one invisible deck box over the grate and frame; the\n"
		"-- meshes above don't collide.\n"
		'for _, root in game:GetService("Selection"):Get() do\n'
		f'\tif root:IsA("Model") and root:FindFirstChild("{name}_Grate", true) then\n'
		"\t\tlocal cf, size = root:GetBoundingBox()\n"
		"\t\troot.WorldPivot = cf * CFrame.new(0, -size.Y / 2, 0)\n"
		'\t\tlocal old = root:FindFirstChild("COL_Deck")\n'
		"\t\tif old then\n"
		"\t\t\told:Destroy()\n"
		"\t\tend\n"
		'\t\tlocal p = Instance.new("Part")\n'
		f'\t\tp.Name, p.Size = "COL_Deck", Vector3.new({2 * OUTER}, {EDGE_H}, {2 * OUTER})\n'
		f"\t\tp.CFrame = root.WorldPivot * CFrame.new(0, {DECK - EDGE_H / 2}, 0)\n"
		"\t\tp.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, true, false, false\n"
		"\t\tp.Transparency, p.CastShadow = 1, false\n"
		"\t\tp.Parent = root\n"
		"\tend\n"
		"end\n"
	)


def run(name="FloorGrate"):
	for ob in [o for o in bpy.data.objects if o.name == name or o.name.startswith(name + "_")]:
		bpy.data.objects.remove(ob, do_unlink=True)
	m = build(VARIANTS[name])
	pairs = [p for p in CLIP_PAIRS if p[0] in m.parts and p[1] in m.parts]  # OpenLR has no corners
	audits = {"mesh": tk.audit_mesh(m), "clip": tk.audit_clipping(m, pairs)}
	merged = m.retag(REGIONS)
	st = tk.stats(merged)
	group, parts = tk.to_blender(name, merged, PALETTE)
	audits["style"] = tk.audit_style(parts)
	return m, st, audits, group, parts


def export(name, group, parts, tris):
	os.makedirs(OUT, exist_ok=True)
	fbx = tk.export_fbx(f"{OUT}/{name}.fbx", group, colors_type="NONE")
	opens = VARIANTS[name]
	tiling = ""
	if opens:
		ends = " and ".join({-1: "left (-X)", 1: "right (+X)"}[s] for s in opens)
		tiling = (f" Open at the {ends} end: tiles join edge to edge {2 * OUTER} studs apart along "
				  "X, with the same rotation.")
	tk.write_handoff(OUT, name, parts, attributes={"Biome": "Mines", "Interactable": False},
					 note=f"Doors guide v24 floor grate, {tris} tris. Pivot bottom centre of the pit, "
					 f"front -Z; the deck is {DECK} studs up, so sink the model {DECK} studs into the "
					 "floor (the corner blocks stand a little proud). Colour is Part.Color (no vertex "
					 f"colour in the FBX). COL_Deck collides.{tiling}",
					 part_color=True)
	with open(f"{OUT}/{name}_apply_materials.luau", "a") as f:
		f.write(helper_luau(name))
	shutil.copy(fbx, f"{ROOT}/factory_fbx/{name}.fbx")
	return fbx
