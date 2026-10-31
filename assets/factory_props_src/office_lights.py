"""Mezzanine office light fixtures (Doors asset guide v24, style mode, Office biome).

Run inside Blender (MCP execute). Builds with assets/WallLights/doors_toolkit.py, exports
assets/mezzanine_office/{OfficePendant,CageLamp}.fbx + hand-offs, and copies the FBXs to
assets/factory_fbx/. Blender axes: front = -Y, up = +Z, 1 unit = 1 stud.
The rest of the office (deck, joists, cabin, doors, troffers, greybox furniture) is built from
Parts in Studio; only these two need faceted hollow shells.

OfficePendant: ceiling canopy, hex rod, collar, open octagonal shade (two-wall hollow shell, lit
cream inside), socket and bulb inside the cavity. Pivot = top centre (ceiling).
CageLamp: wall bulkhead. Octagonal backplate, base cup, hollow glass tube, end cap, four hex cage
bars and a mid ring, bulb inside the glass. Pivot = back centre (wall), reaches toward -Y.
"""

import math
import os
import shutil
import sys

from mathutils import Matrix, Vector

ROOT = "/home/omar/retire/assets"
sys.path.insert(0, ROOT + "/WallLights")
import doors_toolkit as tk  # noqa: E402

OUT = ROOT + "/mezzanine_office"

PENDANT_PALETTE = {
	"hanger": ("#3F423D", "Metal"),  # canopy, rod, collar, socket
	"shade": ("#4E5E55", "Metal"),  # muted green enamel outside
	"shade_in": ("#D8CDB4", "SmoothPlastic"),  # lit cream inside
	"bulb": ("#FFE3A8", "Neon"),
}
CAGE_PALETTE = {
	"body": ("#5A5E57", "Metal"),  # backplate, base cup
	"cage": ("#3F423D", "Metal"),  # bars, ring, end cap
	"glass": ("#D9CDB0", "Glass"),
	"bulb": ("#FFD58A", "Neon"),
}


def lathe_loop(m, loop, seg_tags, mat=Matrix.Identity(4), sides=8):
	"""Closed (r, z) loop lathed into a two-wall hollow shell (caps off); each profile segment
	goes to its own tag so the inside can carry a lighter value than the outside."""
	s = tk.Mesh()
	tk.lathe(s, loop + [loop[0]], "t", sides=sides, cap_bottom=False, cap_top=False)
	vs, fs = s.parts["t"]
	for i, tag in enumerate(seg_tags):
		chunk = fs[i * sides:(i + 1) * sides]
		used = sorted({v for f in chunk for v in f})
		remap = {v: k for k, v in enumerate(used)}
		m.add(tag, [mat @ vs[v] for v in used], [tuple(remap[v] for v in f) for f in chunk])


def place(m, tag, build, mat):
	s = tk.Mesh()
	build(s)
	for vs, fs in s.parts.values():
		m.add(tag, [mat @ v for v in vs], fs)


def build_pendant():
	m = tk.Mesh()
	tk.lathe(m, [(0.4, -0.12), (0.4, 0.0)], "canopy")
	tk.tube(m, [(0, 0, -0.06), (0, 0, -1.74)], 0.05, "rod")
	tk.lathe(m, [(0.26, -1.78), (0.26, -1.70)], "collar")
	# outer wall (~50 degrees), rim, inner wall, top ring hidden under the collar
	lathe_loop(m, [(0.24, -1.78), (0.85, -2.5), (0.79, -2.5), (0.19, -1.84)],
			   ["shade", "shade", "shade_in", "shade"])
	tk.lathe(m, [(0.12, -1.98), (0.12, -1.80)], "socket")
	tk.lathe(m, [(0.1, -1.98), (0.2, -2.08), (0.2, -2.25), (0.12, -2.35)], "bulb")  # above the rim
	return m


PENDANT_REGIONS = {"canopy": "hanger", "rod": "hanger", "collar": "hanger", "socket": "hanger"}
PENDANT_CLIP = [("rod", "canopy"), ("rod", "collar"), ("collar", "shade"), ("socket", "shade_in")]

# Cage lamp: lathe axis +Z mapped onto -Y (out of the wall), centred on the plate
OUTWARD = Matrix.Rotation(math.radians(90), 4, "X")
CAGE_R = 0.33


def build_cage():
	m = tk.Mesh()
	tk.slab(m, tk.oct_poly(0.9, 1.1, 0.2), 0.0, 0.16, "plate")
	place(m, "cup", lambda s: tk.lathe(s, [(0.32, 0.14), (0.32, 0.4)], "t"), OUTWARD)
	lathe_loop(m, [(0.27, 0.4), (0.27, 1.08), (0.22, 1.08), (0.22, 0.4)],
			   ["glass", "glass", "glass", "glass"], OUTWARD)
	place(m, "cap", lambda s: tk.lathe(s, [(0.36, 1.08), (0.36, 1.18)], "t"), OUTWARD)
	place(m, "bulb", lambda s: tk.lathe(s, [(0.1, 0.4), (0.16, 0.5), (0.16, 0.82), (0.1, 0.94)], "t"), OUTWARD)
	# four bars from cup to cap on the diagonals, buried at both ends
	for k in range(4):
		a = math.radians(45 + 90 * k)
		x, z = CAGE_R * math.cos(a), CAGE_R * math.sin(a)
		tk.tube(m, [(x, -0.36, z), (x, -1.12, z)], 0.045, "bars", axis=(math.cos(a), 0, math.sin(a)))
	# mid ring: an octagon of short bars at the cage radius
	ring_r = CAGE_R / math.cos(math.pi / 8)
	pts = [Vector((ring_r * math.cos(math.radians(22.5 + 45 * k)), -0.76,
				   ring_r * math.sin(math.radians(22.5 + 45 * k)))) for k in range(8)]
	for k in range(8):
		a, b = pts[k], pts[(k + 1) % 8]
		d = (b - a).normalized() * 0.04
		tk.tube(m, [a - d, b + d], 0.04, "ring", axis=(0, 1, 0))
	return m


CAGE_REGIONS = {"plate": "body", "cup": "body", "cap": "cage", "bars": "cage", "ring": "cage"}
CAGE_CLIP = [("cup", "plate"), ("glass", "cup"), ("cap", "glass")]


def placement_luau(group, placeholder, pivot):
	"""Appended to the apply script: move the fixture onto its Studio placeholder, hand it the
	placeholder's lights, and parent it into MezzanineOffice.Lights."""
	bulb = group + "_Bulb"
	pivot_code = {
		"top": "cf * CFrame.new(0, size.Y / 2, 0)",
		"back": "cf * CFrame.new(0, 0, size.Z / 2)",
	}[pivot]
	return (
		"\n-- Placement: fit onto the placeholder Parts built in Studio, keep its lights.\n"
		'local office = workspace.FactoryRoomEditCopies.PipeGallery:FindFirstChild("MezzanineOffice")\n'
		'local holders = office and office:FindFirstChild("BlenderPlaceholders")\n'
		'for _, root in game:GetService("Selection"):Get() do\n'
		f'\tlocal bulb = root:FindFirstChild("{bulb}", true)\n'
		'\tif root:IsA("Model") and bulb and holders then\n'
		f'\t\tlocal ph = holders:FindFirstChild("{placeholder}")\n'
		"\t\tif ph then\n"
		"\t\t\tlocal cf, size = root:GetBoundingBox()\n"
		f"\t\t\troot.WorldPivot = {pivot_code}\n"
		f'\t\t\troot:PivotTo(ph:GetAttribute("Mount"))\n'
		"\t\t\tfor _, p in root:GetDescendants() do\n"
		'\t\t\t\tif p:IsA("BasePart") and p.Material == Enum.Material.Glass then\n'
		"\t\t\t\t\tp.Transparency = 0.5\n"
		"\t\t\t\tend\n"
		"\t\t\tend\n"
		'\t\t\tfor _, l in ph:GetChildren() do\n'
		'\t\t\t\tif l:IsA("Light") then\n'
		"\t\t\t\t\tl.Parent = bulb\n"
		"\t\t\t\tend\n"
		"\t\t\tend\n"
		f'\t\t\troot.Name = "{group}"\n'
		'\t\t\troot:SetAttribute("LightSource", true)\n'
		"\t\t\troot.Parent = office.Lights\n"
		"\t\t\tph:Destroy()\n"
		"\t\tend\n"
		"\tend\n"
		"end\n"
	)


def make(name, m, regions, palette, clip):
	import bpy
	for ob in [o for o in bpy.data.objects if o.name == name or o.name.startswith(name + "_")]:
		bpy.data.objects.remove(ob, do_unlink=True)
	audits = {"mesh": tk.audit_mesh(m), "clip": tk.audit_clipping(m, clip)}
	merged = m.retag(regions)
	st = tk.stats(merged)
	group, parts = tk.to_blender(name, merged, palette)
	audits["style"] = tk.audit_style(parts)
	return group, parts, st, audits


def export(name, group, parts, tris, placeholder, pivot, note):
	os.makedirs(OUT, exist_ok=True)
	fbx = tk.export_fbx(f"{OUT}/{name}.fbx", group, colors_type="NONE")
	tk.write_handoff(OUT, name, parts, attributes={"Biome": "Office", "LightSource": True},
					 note=f"Doors guide v24, {tris} tris. {note} Colour is Part.Color (no vertex colour in "
					 "the FBX). Meshes don't collide (overhead fixture, out of reach).", part_color=True)
	with open(f"{OUT}/{name}_apply_materials.luau", "a") as f:
		f.write(placement_luau(name, placeholder, pivot))
	shutil.copy(fbx, f"{ROOT}/factory_fbx/{name}.fbx")
	return fbx


def run():
	out = {}
	pg, pp, ps, pa = make("OfficePendant", build_pendant(), PENDANT_REGIONS, PENDANT_PALETTE, PENDANT_CLIP)
	cg, cp, cs, ca = make("CageLamp", build_cage(), CAGE_REGIONS, CAGE_PALETTE, CAGE_CLIP)
	cg.location = (3, 0, 0)
	out["pendant"] = {"stats": ps, "audits": pa}
	out["cage"] = {"stats": cs, "audits": ca}
	return out, (pg, pp, ps), (cg, cp, cs)
