"""Stand-in for the guide's doors_toolkit (v18 names the file but it was not supplied).

Implements the calls Sec. 14 lists with the same rules: slab / chamfer_box (one flat chamfer),
lathe (8 sides, a flat facing front), turtle / arc + tube (mitred hexagonal facet chains),
audits, to_blender, export_fbx, setup_review_rig, write_handoff.
Blender axes: front = -Y, up = +Z, 1 unit = 1 stud. Runs inside Blender (bmesh for hulls).
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

C8 = math.cos(math.pi / 8)


class Mesh:
	def __init__(self):
		self.parts = {}  # tag -> [verts, faces]

	def add(self, tag, verts, faces):
		vs, fs = self.parts.setdefault(tag, [[], []])
		o = len(vs)
		vs.extend(Vector(v) for v in verts)
		fs.extend(tuple(i + o for i in f) for f in faces)

	def retag(self, mapping):
		out = Mesh()
		for tag, (vs, fs) in self.parts.items():
			out.add(mapping.get(tag, tag), vs, fs)
		return out


def translate(m, off, tags=None):
	for tag, (vs, _) in m.parts.items():
		if tags is None or tag in tags:
			for v in vs:
				v += Vector(off)


def hull(m, pts, tag):
	"""Convex hull of points as one closed part; coplanar triangles are merged back into faces."""
	bm = bmesh.new()
	for p in pts:
		bm.verts.new(p)
	res = bmesh.ops.convex_hull(bm, input=bm.verts)
	bmesh.ops.delete(bm, geom=[v for v in res["geom_interior"] if isinstance(v, bmesh.types.BMVert)], context="VERTS")
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), verts=bm.verts, edges=bm.edges)
	bm.verts.index_update()
	m.add(tag, [v.co.copy() for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces])
	bm.free()


def chamfer_box(m, lo, hi, c, tag):
	lo, hi = Vector(lo), Vector(hi)
	ctr, h = (lo + hi) / 2, (hi - lo) / 2
	pts = []
	for sx in (-1, 1):
		for sy in (-1, 1):
			for sz in (-1, 1):
				s = Vector((sx, sy, sz))
				for ax in range(3):
					q = Vector((h.x - c, h.y - c, h.z - c))
					q[ax] = h[ax]
					pts.append(ctr + Vector(s[i] * q[i] for i in range(3)))
	hull(m, pts, tag)


def plain_box(m, lo, hi, tag):
	hull(m, [(x, y, z) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])], tag)


def oct_poly(w, h, cut):
	"""Plate outline: w x h rectangle with equal-leg 45-degree corner cuts."""
	x, y = w / 2, h / 2
	return [(x, y - cut), (x - cut, y), (-x + cut, y), (-x, y - cut),
			(-x, -y + cut), (-x + cut, -y), (x - cut, -y), (x, -y + cut)]


def inset_poly(poly, d):
	"""Offset a convex CCW polygon inward by d."""
	n = len(poly)
	lines = []
	for i in range(n):
		a, b = Vector(poly[i]), Vector(poly[(i + 1) % n])
		e = (b - a).normalized()
		nrm = Vector((-e.y, e.x))  # inward for CCW
		lines.append((a + nrm * d, e))
	out = []
	for i in range(n):
		(p1, d1), (p2, d2) = lines[i - 1], lines[i]
		den = d1.x * d2.y - d1.y * d2.x
		t = ((p2.x - p1.x) * d2.y - (p2.y - p1.y) * d2.x) / den
		out.append(tuple(p1 + d1 * t))
	return out


def wall_frame(u, v, w):
	"""Plate-local (u across, v up, w out of the wall) -> Blender (x, -y, z)."""
	return Vector((u, -w, v))


def slab(m, poly, z0, z1, tag, c=0.0, frame=wall_frame):
	"""Plate from a convex polygon, extruded z0..z1; c > 0 adds ONE 45-degree chamfer on the z1 edge."""
	pts = [frame(x, y, z0) for x, y in poly]
	if c > 0:
		pts += [frame(x, y, z1 - c) for x, y in poly]
		pts += [frame(x, y, z1) for x, y in inset_poly(poly, c)]
	else:
		pts += [frame(x, y, z1) for x, y in poly]
	hull(m, pts, tag)


def lathe(m, profile, tag, sides=8, center=(0, 0, 0), cap_bottom=True, cap_top=True):
	"""Revolve [(r, z), ...] about +Z; r is the half flat-to-flat size, a flat faces -Y (front).
	A profile point with r == 0 becomes a single pole vertex."""
	cx, cy, cz = center
	verts, faces, rings = [], [], []
	for r, z in profile:
		if r <= 1e-9:
			rings.append([len(verts)])
			verts.append((cx, cy, cz + z))
			continue
		ring = []
		for k in range(sides):
			a = math.pi / sides + 2 * math.pi * k / sides - math.pi / 2
			ring.append(len(verts))
			rr = r / math.cos(math.pi / sides)
			verts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), cz + z))
		rings.append(ring)
	for a, b in zip(rings, rings[1:]):
		if len(a) == 1:
			faces += [(a[0], b[(k + 1) % sides], b[k]) for k in range(sides)]
		elif len(b) == 1:
			faces += [(a[k], a[(k + 1) % sides], b[0]) for k in range(sides)]
		else:
			faces += [(a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]) for k in range(sides)]
	if cap_bottom and len(rings[0]) > 1:
		faces.append(tuple(reversed(rings[0])))
	if cap_top and len(rings[-1]) > 1:
		faces.append(tuple(rings[-1]))
	_fix_winding(verts, faces)
	m.add(tag, verts, faces)


def _rot(v, axis, deg):
	k = Vector(axis).normalized()
	t = math.radians(deg)
	return v * math.cos(t) + k.cross(v) * math.sin(t) + k * k.dot(v) * (1 - math.cos(t))


def turtle(start, direction, axis, ops):
	"""Bent path: ("f", length) moves forward, ("t", deg) turns about `axis`."""
	p, d = Vector(start), Vector(direction).normalized()
	pts = [p.copy()]
	for op, val in ops:
		if op == "f":
			p = p + d * val
			pts.append(p.copy())
		else:
			if abs(val) < 30:
				print(f"turtle: turn of {val} deg is below 30")
			d = _rot(d, axis, val)
	return pts


def arc(center, radius, a0, a1, segs, plane="xz"):
	if abs(a1 - a0) / segs < 30:
		print("arc: joints turn less than 30 degrees")
	i, j = {"xy": (0, 1), "xz": (0, 2), "yz": (1, 2)}[plane]
	out = []
	for s in range(segs + 1):
		a = math.radians(a0 + (a1 - a0) * s / segs)
		p = Vector(center)
		p[i] += radius * math.cos(a)
		p[j] += radius * math.sin(a)
		out.append(p)
	return out


def tube(m, pts, r, tag, axis=(1, 0, 0), sides=6, cap_start=True, cap_end=True):
	"""Chunky mitred bar along a polyline bent in the plane normal to `axis`.
	r is the half flat-to-flat size; a flat faces +-axis (toward a side viewer)."""
	n = Vector(axis).normalized()
	pts = [Vector(p) for p in pts]
	tans = [(b - a).normalized() for a, b in zip(pts, pts[1:])]
	rv = r / math.cos(math.pi / sides)
	verts, faces, rings = [], [], []
	for i, p in enumerate(pts):
		t_in = tans[max(i - 1, 0)]
		t_out = tans[min(i, len(tans) - 1)]
		mitre = (t_in + t_out).normalized()
		b = t_in.cross(n).normalized()
		ring = []
		for k in range(sides):
			a = math.pi / sides + 2 * math.pi * k / sides
			o = n * (rv * math.cos(a)) + b * (rv * math.sin(a))
			s = -o.dot(mitre) / t_in.dot(mitre)
			ring.append(len(verts))
			verts.append(p + o + t_in * s)
		rings.append(ring)
	for ra, rb in zip(rings, rings[1:]):
		faces += [(ra[k], ra[(k + 1) % sides], rb[(k + 1) % sides], rb[k]) for k in range(sides)]
	if cap_start:
		faces.append(tuple(reversed(rings[0])))
	if cap_end:
		faces.append(tuple(rings[-1]))
	_fix_winding(verts, faces)
	m.add(tag, verts, faces)


def _fix_winding(verts, faces):
	"""Flip the whole part if its signed volume is negative (outward normals)."""
	vol = 0.0
	for f in faces:
		a = Vector(verts[f[0]])
		for i in range(1, len(f) - 1):
			vol += a.dot(Vector(verts[f[i]]).cross(Vector(verts[f[i + 1]])))
	if vol < 0:
		faces[:] = [tuple(reversed(f)) for f in faces]


def wonky(m, tags, lean=0.04, taper=-0.14, jitter=0.05, top_tilt=0.2, seed=1, center=(0, 0)):
	rng = random.Random(seed)
	for tag in tags:
		vs = m.parts[tag][0]
		z0, z1 = min(v.z for v in vs), max(v.z for v in vs)
		h = max(z1 - z0, 1e-6)
		for v in vs:
			f = (v.z - z0) / h
			s = 1 + taper * f + rng.uniform(-jitter, jitter)
			v.x = center[0] + (v.x - center[0]) * s + lean * h * f
			v.y = center[1] + (v.y - center[1]) * s
			v.z += top_tilt * h * 0.1 * f * (v.x - center[0])


def _tris(fs):
	return sum(len(f) - 2 for f in fs)


def stats(m):
	out, total = {}, 0
	allv = []
	degen = 0
	for tag, (vs, fs) in m.parts.items():
		out[tag] = _tris(fs)
		total += out[tag]
		allv += vs
		for f in fs:
			a = vs[f[0]]
			for i in range(1, len(f) - 1):
				if (vs[f[i]] - a).cross(vs[f[i + 1]] - a).length < 1e-9:
					degen += 1
	lo = Vector((min(v[i] for v in allv) for i in range(3)))
	hi = Vector((max(v[i] for v in allv) for i in range(3)))
	return {"tris": total, "per_tag": out, "bbox": (tuple(round(x, 3) for x in lo), tuple(round(x, 3) for x in hi)),
			"size": tuple(round(x, 3) for x in hi - lo), "degenerate": degen}


def _normal(vs, f):
	n = Vector()
	for i in range(len(f)):
		a, b = vs[f[i]], vs[f[(i + 1) % len(f)]]
		n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
	return n.normalized()


def audit_mesh(m, soft_tags=(), organic_tags=()):
	"""Flags edges whose faces turn 6-28 degrees (accidental rounding) on crisp parts."""
	issues = []
	for tag, (vs, fs) in m.parts.items():
		if tag in soft_tags or tag in organic_tags:
			continue
		edges = {}
		for fi, f in enumerate(fs):
			for i in range(len(f)):
				e = tuple(sorted((f[i], f[(i + 1) % len(f)])))
				edges.setdefault(e, []).append(fi)
		bad = 0
		for e, fl in edges.items():
			if len(fl) == 2:
				ang = math.degrees(_normal(vs, fs[fl[0]]).angle(_normal(vs, fs[fl[1]]), 0))
				if 6 <= ang <= 28:
					bad += 1
			elif len(fl) != 2:
				issues.append(f"{tag}: non-manifold edge {e}")
		if bad:
			issues.append(f"{tag}: {bad} softly rounded edges (6-28 deg)")
	return issues


def _bvh(vs, fs):
	return BVHTree.FromPolygons([tuple(v) for v in vs], fs)


def audit_clipping(m, pairs, eps=0.004):
	"""For each (part, host): vertices of part inside the closed host deeper than eps."""
	issues = []
	for tag, host in pairs:
		hv, hf = m.parts[host]
		tree = _bvh(hv, hf)
		worst = 0.0
		for v in m.parts[tag][0]:
			hits, o, d = 0, v.copy(), Vector((0.123, 0.311, 0.942)).normalized()
			while True:
				loc, _, idx, _ = tree.ray_cast(o, d)
				if loc is None:
					break
				hits += 1
				o = loc + d * 1e-5
			if hits % 2 == 1:
				depth = tree.find_nearest(v)[3]
				worst = max(worst, depth)
		if worst > eps:
			issues.append(f"{tag} inside {host} by {worst:.3f}")
	return issues


def audit_style(objs, soft_tags=()):
	issues = []
	for ob in objs:
		soft = any(ob.name.lower().endswith("_" + t.lower()) for t in soft_tags)
		if ob.modifiers:
			issues.append(f"{ob.name}: modifiers {[md.type for md in ob.modifiers]}")
		if ob.data.has_custom_normals:
			issues.append(f"{ob.name}: custom normals")
		if not soft and any(p.use_smooth for p in ob.data.polygons):
			issues.append(f"{ob.name}: smooth-shaded polygons on a crisp part")
	return issues


def _pascal(s):
	return "".join(w[:1].upper() + w[1:] for w in s.replace("-", "_").split("_"))


def _srgb(h):
	return [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]


def _lin(c):
	return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def to_blender(name, m, palette, location=(0, 0, 0), smooth_tags=(), collection=None):
	"""One object per tag (<Name>_<Tag>) under an Empty; flat vertex colour `Col`, preview material,
	custom props roblox_material / roblox_color. Only smooth_tags are smooth-shaded."""
	coll = collection or bpy.context.collection
	group = bpy.data.objects.new(name, None)
	coll.objects.link(group)
	group.location = location
	parts = []
	for tag, (vs, fs) in m.parts.items():
		hx, rmat = palette[tag]
		pname = f"{name}_{_pascal(tag)}"
		me = bpy.data.meshes.new(pname)
		me.from_pydata([tuple(v) for v in vs], [], fs)
		me.validate()
		bm = bmesh.new()
		bm.from_mesh(me)
		bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		bmesh.ops.triangulate(bm, faces=bm.faces)
		bm.to_mesh(me)
		bm.free()
		smooth = tag in smooth_tags
		for p in me.polygons:
			p.use_smooth = smooth
		col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
		rgb = _srgb(hx)
		for d in col.data:
			d.color_srgb = (*rgb, 1.0)
		mat = bpy.data.materials.get("PREVIEW_" + pname) or bpy.data.materials.new("PREVIEW_" + pname)
		mat.use_nodes = True
		bsdf = next(nd for nd in mat.node_tree.nodes if nd.type == "BSDF_PRINCIPLED")
		bsdf.inputs["Base Color"].default_value = (*_lin(rgb), 1.0)
		bsdf.inputs["Metallic"].default_value = 0.7 if rmat == "Metal" else 0.0
		bsdf.inputs["Roughness"].default_value = 0.35 if rmat == "Metal" else 0.75
		if rmat == "Neon":
			bsdf.inputs["Emission Color"].default_value = (*_lin(rgb), 1.0)
			bsdf.inputs["Emission Strength"].default_value = 6.0
		mat.diffuse_color = (*_lin(rgb), 1.0)
		me.materials.append(mat)
		ob = bpy.data.objects.new(pname, me)
		coll.objects.link(ob)
		ob.parent = group
		ob["roblox_material"] = rmat
		ob["roblox_color"] = hx
		parts.append(ob)
	return group, parts


def setup_review_rig(target=(0, 0, 0), distance=6.0):
	sc = bpy.context.scene
	w = sc.world or bpy.data.worlds.new("World")
	sc.world = w
	w.use_nodes = True
	bg = next(nd for nd in w.node_tree.nodes if nd.type == "BACKGROUND")
	bg.inputs["Color"].default_value = (*_lin(_srgb("#2A211C")), 1.0)
	bg.inputs["Strength"].default_value = 0.4
	lo = bpy.data.objects.get("ReviewKey")
	if lo is None:
		lo = bpy.data.objects.new("ReviewKey", bpy.data.lights.new("ReviewKey", "POINT"))
		sc.collection.objects.link(lo)
	lo.data.color = _lin(_srgb("#FFD58A"))
	lo.data.energy = 300
	t = Vector(target)
	lo.location = t + Vector((-1.5, -3.0, 2.5))
	co = bpy.data.objects.get("ReviewCam")
	if co is None:
		co = bpy.data.objects.new("ReviewCam", bpy.data.cameras.new("ReviewCam"))
		sc.collection.objects.link(co)
	co.location = t + Vector((-distance * 0.5, -distance, distance * 0.25))
	co.rotation_euler = (t - co.location).to_track_quat("-Z", "Y").to_euler()
	sc.camera = co
	for area in bpy.context.screen.areas:
		if area.type == "VIEW_3D":
			for sp in area.spaces:
				if sp.type == "VIEW_3D":
					sp.shading.type = "MATERIAL"
	return co, lo


def export_fbx(path, group, colors_type="SRGB"):
	bpy.ops.object.select_all(action="DESELECT")
	group.select_set(True)
	for ob in group.children:
		ob.select_set(True)
	bpy.context.view_layer.objects.active = group
	bpy.ops.export_scene.fbx(
		filepath=path, use_selection=True, object_types={"EMPTY", "MESH"},
		mesh_smooth_type="FACE", colors_type=colors_type, use_mesh_modifiers=False,
		apply_scale_options="FBX_SCALE_ALL", bake_anim=False, path_mode="STRIP",
	)
	return path


def luau_apply_script(group_name, parts, light=None, attributes=None, part_color=False):
	"""part_color: colour each MeshPart from its palette hex (guide v24, FBX exported without
	vertex colour) instead of white over baked vertex colours."""
	color = (lambda o: f'Color3.fromHex("{o["roblox_color"]}")') if part_color else (lambda o: "Color3.new(1, 1, 1)")
	rows = "\n".join(f'\t["{o.name}"] = {{ Enum.Material.{o["roblox_material"]}, {color(o)} }},'
					 for o in parts)
	light_code = ""
	if light:
		light_code = (
			f'\t\t\tif p.Name == "{light["part"]}" and not p:FindFirstChildWhichIsA("Light") then\n'
			f'\t\t\t\tlocal l = Instance.new("PointLight")\n'
			f'\t\t\t\tl.Range, l.Brightness, l.Shadows = {light["range"]}, {light["brightness"]}, {str(light["shadows"]).lower()}\n'
			f'\t\t\t\tl.Color = Color3.fromHex("{light["color"]}")\n'
			f'\t\t\t\tl.Parent = p\n'
			f'\t\t\tend\n'
		)
	attr_code = "".join(f'\t\troot:SetAttribute("{k}", {repr(v).lower() if isinstance(v, bool) else repr(v).replace(chr(39), chr(34))})\n'
						for k, v in (attributes or {}).items())
	return (
		f"-- {group_name}: run in the Studio command bar with the imported model selected.\n"
		+ ("-- Sets each MeshPart's built-in Material and its region's Color, anchors it as\n"
		   "-- non-colliding dressing and adds the fixture's light.\n"
		   if part_color else
		   "-- Sets each MeshPart's built-in Material and a white Color (the FBX vertex colours show\n"
		   "-- through), anchors it as non-colliding dressing and adds the fixture's light.\n") +
		"local map = {\n" + rows + "\n}\n"
		'for _, root in game:GetService("Selection"):Get() do\n'
		"\tlocal parts = root:GetDescendants()\n"
		"\ttable.insert(parts, root)\n"
		"\tfor _, p in parts do\n"
		'\t\tlocal m = p:IsA("MeshPart") and map[p.Name]\n'
		"\t\tif m then\n"
		"\t\t\tp.Material, p.Color = m[1], m[2]\n"
		"\t\t\tp.Anchored, p.CanCollide, p.CanTouch = true, false, false\n"
		"\t\t\tp.CastShadow = m[1] ~= Enum.Material.Neon\n"
		"\t\t\tp.CollisionFidelity = Enum.CollisionFidelity.Box\n"
		+ light_code +
		"\t\tend\n"
		"\tend\n"
		'\tif root:IsA("Model") then\n'
		+ attr_code +
		"\tend\n"
		"end\n"
	)


def handoff_manifest(group_name, parts, note="", part_color=False):
	head = "Part.Color" if part_color else "Vertex colour"
	rows = [f"| Mesh name (must match in Studio) | Roblox Material | {head} | Tris |", "|---|---|---|---|"]
	total = 0
	for o in parts:
		n = len(o.data.polygons)
		total += n
		rows.append(f'| {o.name} | {o["roblox_material"]} | {o["roblox_color"]} | {n} |')
	return f"# Studio hand-off: {group_name}\n\n" + "\n".join(rows) + f"\n\nTotal: {total} tris. {note}\n"


def write_handoff(folder, group_name, parts, light=None, attributes=None, note="", part_color=False):
	lp = os.path.join(folder, f"{group_name}_apply_materials.luau")
	mp = os.path.join(folder, f"{group_name}_manifest.md")
	with open(lp, "w") as f:
		f.write(luau_apply_script(group_name, parts, light, attributes, part_color))
	with open(mp, "w") as f:
		f.write(handoff_manifest(group_name, parts, note, part_color))
	return lp, mp
