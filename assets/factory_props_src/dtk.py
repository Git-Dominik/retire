"""Minimal Doors-style toolkit (stand-in for the missing doors_toolkit.py).

Blender coords: Z up, front = -Y, 1 unit = 1 stud. Every part is built per tag into its own
bmesh; to_blender makes one flat-shaded object per tag with a flat `Col` vertex colour.
Shapes: hull boxes with one flat chamfer per chosen edge, lofts (lathe / mitred hex tubes).
"""

import math

import bmesh
import bpy
from mathutils import Vector


def v(*a):
    return Vector(a if len(a) == 3 else a[0])


class Builder:
    def __init__(self):
        self.parts = {}  # tag -> bmesh

    def bm(self, tag):
        if tag not in self.parts:
            self.parts[tag] = bmesh.new()
        return self.parts[tag]

    # --- primitives -------------------------------------------------------------------------

    def hull(self, tag, pts):
        b = bmesh.new()
        verts = [b.verts.new(p) for p in pts]
        res = bmesh.ops.convex_hull(b, input=verts)
        for g in res["geom_interior"] + res["geom_unused"]:
            if isinstance(g, bmesh.types.BMVert) and g.is_valid:
                bmesh.ops.delete(b, geom=[g], context="VERTS")
        bmesh.ops.dissolve_limit(b, angle_limit=math.radians(0.5), verts=b.verts, edges=b.edges)
        self._append(tag, b)

    def box(self, tag, lo, hi, c=0.0, axes="xyz", flat=()):
        """Box from lo to hi. One 45° chamfer of size c on edges parallel to `axes`, except
        edges that touch a face in `flat` ("-z", "+x", ...), which stay sharp seams."""
        lo, hi = v(lo), v(hi)
        if c <= 0:
            pts = [v(x, y, z) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
            return self.hull(tag, pts)
        names = "xyz"
        pts = set()
        for sx in (0, 1):
            for sy in (0, 1):
                for sz in (0, 1):
                    s = (sx, sy, sz)
                    corner = [hi[i] if s[i] else lo[i] for i in range(3)]
                    for a in range(3):
                        p = list(corner)
                        for b in range(3):
                            if b == a:
                                continue
                            k = 3 - a - b
                            fa = ("+" if s[a] else "-") + names[a]
                            fb = ("+" if s[b] else "-") + names[b]
                            if names[k] in axes and fa not in flat and fb not in flat:
                                p[b] += -c if s[b] else c
                        pts.add(tuple(round(q, 6) for q in p))
        self.hull(tag, [v(p) for p in pts])

    def prism(self, tag, poly, z0, z1, axis="z"):
        """Extrude a convex 2D polygon (in the two other axes, in xyz order) along axis."""
        pts = []
        for z in (z0, z1):
            for a, b in poly:
                if axis == "z":
                    pts.append(v(a, b, z))
                elif axis == "y":
                    pts.append(v(a, z, b))
                else:
                    pts.append(v(z, a, b))
        self.hull(tag, pts)

    def loft(self, tag, rings, cap0=True, cap1=True):
        b = bmesh.new()
        vr = [[b.verts.new(p) for p in r] for r in rings]
        n = len(rings[0])
        for i in range(len(vr) - 1):
            for j in range(n):
                a, c = vr[i][j], vr[i][(j + 1) % n]
                d, e = vr[i + 1][(j + 1) % n], vr[i + 1][j]
                if len({a, c, d, e}) == 4:
                    b.faces.new((a, c, d, e))
        if cap0:
            b.faces.new(list(reversed(vr[0])))
        if cap1:
            b.faces.new(vr[-1])
        bmesh.ops.remove_doubles(b, verts=b.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
        self._append(tag, b)

    # --- rings, lathes, tubes -----------------------------------------------------------------

    @staticmethod
    def frame(axis):
        axis = v(axis).normalized()
        ref = v(0, 0, 1) if abs(axis.z) < 0.9 else v(0, -1, 0)
        u = axis.cross(ref).normalized()
        w = axis.cross(u).normalized()
        return u, w

    @classmethod
    def ring(cls, center, axis, r, sides, rot=None, u=None, w=None):
        """Polygon with flats (not corners) at distance r (r = half flat-to-flat)."""
        if u is None:
            u, w = cls.frame(axis)
        R = r / math.cos(math.pi / sides)
        rot = math.pi / sides if rot is None else rot
        c = v(center)
        return [
            c + (u * math.cos(rot + 2 * math.pi * i / sides) + w * math.sin(rot + 2 * math.pi * i / sides)) * R
            for i in range(sides)
        ]

    def lathe(self, tag, profile, base, axis=(0, 0, 1), sides=8, cap0=True, cap1=True, rot=None):
        """profile = [(r, t), ...] along axis from base. r = 0 points collapse to a cap."""
        axis = v(axis).normalized()
        u, w = self.frame(axis)
        rings = []
        for r, t in profile:
            rings.append(self.ring(v(base) + axis * t, axis, max(r, 1e-4), sides, rot, u, w))
        self.loft(tag, rings, cap0, cap1)

    def cyl(self, tag, p0, p1, r, sides=8, c=0.0, rot=None):
        """Straight 8-sided body from p0 to p1, optional chamfer c on both ends."""
        p0, p1 = v(p0), v(p1)
        d = p1 - p0
        L = d.length
        if c > 0:
            prof = [(r - c, 0), (r, c), (r, L - c), (r - c, L)]
        else:
            prof = [(r, 0), (r, L)]
        self.lathe(tag, prof, p0, d, sides, rot=rot)

    def ring_tube(self, tag, center, normal, radius, r, segs=8, sides=6):
        """Closed faceted ring (handwheel, hoop) of `segs` straight hex segments."""
        c = v(center)
        u, w = self.frame(normal)
        pts = [c + (u * math.cos(a) + w * math.sin(a)) * radius for a in [2 * math.pi * i / segs for i in range(segs)]]
        n = v(normal).normalized()
        R = r / math.cos(math.pi / sides)
        rings = []
        for p in pts:
            radial = (p - c).normalized()
            ring = []
            for k in range(sides):
                ang = math.pi / sides + 2 * math.pi * k / sides
                ring.append(p + (radial * math.cos(ang) + n * math.sin(ang)) * R)
            rings.append(ring)
        rings.append(rings[0])
        self.loft(tag, rings, False, False)

    def loop_tube(self, tag, pts, normal, r, sides=6):
        """Closed planar polyline (handle loop) as a mitred hex bar; normal = loop plane normal."""
        pts = [v(p) for p in pts]
        N = v(normal).normalized()
        R = r / math.cos(math.pi / sides)
        n = len(pts)
        rings = []
        for i, p in enumerate(pts):
            a = (p - pts[i - 1]).normalized()
            b = (pts[(i + 1) % n] - p).normalized()
            mdir = N.cross(a + b).normalized()
            scale = 1 / mdir.dot(N.cross(a).normalized())
            ring = []
            for k in range(sides):
                ang = math.pi / sides + 2 * math.pi * k / sides
                ring.append(p + mdir * math.cos(ang) * R * scale + N * math.sin(ang) * R)
            rings.append(ring)
        rings.append(rings[0])
        self.loft(tag, rings, False, False)

    def tube(self, tag, pts, r, sides=6, cap0=True, cap1=True):
        """Mitred faceted bar through pts (hexagonal by default)."""
        pts = [v(p) for p in pts]
        d0 = (pts[1] - pts[0]).normalized()
        u, w = self.frame(d0)
        rings = []
        R = r / math.cos(math.pi / sides)
        for i, p in enumerate(pts):
            if i == 0:
                n = d0
            elif i == len(pts) - 1:
                n = (pts[-1] - pts[-2]).normalized()
            else:
                a = (p - pts[i - 1]).normalized()
                b = (pts[i + 1] - p).normalized()
                n = (a + b).normalized()
            # carry the frame along the path (parallel transport) for an untwisted bar
            if i > 0:
                dprev = (p - pts[i - 1]).normalized()
                ref_u = u - dprev * u.dot(dprev)
                u = ref_u.normalized()
                w = dprev.cross(u).normalized()
            seg_d = (pts[i] - pts[i - 1]).normalized() if i > 0 else d0
            ring = []
            for k in range(sides):
                ang = math.pi / sides + 2 * math.pi * k / sides
                off = (u * math.cos(ang) + w * math.sin(ang)) * R
                # project onto the mitre plane through p with normal n, along seg_d
                q = p + off
                t = (p - q).dot(n) / seg_d.dot(n)
                ring.append(q + seg_d * t)
            rings.append(ring)
            if 0 < i < len(pts) - 1:
                # rotate frame into the next segment
                dnext = (pts[i + 1] - p).normalized()
                rotq = seg_d.rotation_difference(dnext)
                u = rotq @ u
                w = rotq @ w
        self.loft(tag, rings, cap0, cap1)

    @staticmethod
    def turtle(start, direction, axis, ops):
        p = v(start)
        d = v(direction).normalized()
        ax = v(axis).normalized()
        pts = [p.copy()]
        from mathutils import Matrix

        for op, val in ops:
            if op == "f":
                p = p + d * val
                pts.append(p.copy())
            else:
                d = (Matrix.Rotation(math.radians(val), 3, ax) @ d).normalized()
        return pts

    # --- utilities ---------------------------------------------------------------------------

    def _append(self, tag, b):
        tmp = bpy.data.meshes.new("_tmp")
        b.to_mesh(tmp)
        b.free()
        self.bm(tag).from_mesh(tmp)
        bpy.data.meshes.remove(tmp)

    def mirror_x(self, tag_src_fn):
        """Call fn(sign) for sign in (-1, 1)."""
        for s in (-1, 1):
            tag_src_fn(s)

    def stats(self):
        out = {}
        for tag, b in self.parts.items():
            b2 = b.copy()
            bmesh.ops.triangulate(b2, faces=b2.faces)
            out[tag] = len(b2.faces)
            b2.free()
        return out


def hexcol(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def to_blender(name, builder, palette, location=(0, 0, 0)):
    """palette = {tag: (hex, RobloxMaterial)}. Objects are named <Name>_<Tag>."""
    old = bpy.data.objects.get(name)
    if old:
        for ch in list(old.children):
            bpy.data.objects.remove(ch, do_unlink=True)
        bpy.data.objects.remove(old, do_unlink=True)
    root = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(root)
    root.location = location
    objs = []
    for tag, b in builder.parts.items():
        hx, mat = palette[tag]
        me = bpy.data.meshes.new(f"{name}_{tag}")
        b2 = b.copy()
        bmesh.ops.remove_doubles(b2, verts=b2.verts, dist=1e-5)
        bmesh.ops.triangulate(b2, faces=b2.faces)
        b2.to_mesh(me)
        b2.free()
        for p in me.polygons:
            p.use_smooth = False
        col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        rgb = hexcol(hx)
        for d in col.data:
            d.color_srgb = (*rgb, 1.0)
        ob = bpy.data.objects.new(f"{name}_{tag}", me)
        ob["roblox_material"] = mat
        ob["roblox_color"] = hx
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = root
        ob.data.materials.append(preview_material(tag, hx, mat))
        objs.append(ob)
    return root, objs


def preview_material(tag, hx, mat):
    key = f"prev_{hx}_{mat}"
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    attr = m.node_tree.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    m.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    metal = mat in ("Metal", "DiamondPlate", "CorrodedMetal")
    bsdf.inputs["Metallic"].default_value = 0.5 if metal else 0.0
    bsdf.inputs["Roughness"].default_value = 0.45 if metal else 0.75
    if mat == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*hexcol(hx), 1)
        bsdf.inputs["Emission Strength"].default_value = 4
    return m


def export_fbx(path, root):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for ch in root.children:
        ch.select_set(True)
    bpy.context.view_layer.objects.active = root
    loc = root.location.copy()
    root.location = (0, 0, 0)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"EMPTY", "MESH"},
        mesh_smooth_type="FACE",
        colors_type="SRGB",
        path_mode="STRIP",
        embed_textures=False,
        apply_unit_scale=True,
        bake_space_transform=True,
        axis_forward="-Z",
        axis_up="Y",
    )
    root.location = loc


def audit(builder):
    """Non-manifold edges and degenerate faces per tag (should all be 0)."""
    out = {}
    for tag, b in builder.parts.items():
        nm = sum(1 for e in b.edges if not e.is_manifold)
        deg = sum(1 for f in b.faces if f.calc_area() < 1e-7)
        smooth_turns = 0
        for e in b.edges:
            if len(e.link_faces) == 2:
                ang = math.degrees(e.calc_face_angle(0))
                if 6 < ang < 28:
                    smooth_turns += 1
        out[tag] = {"nonmanifold": nm, "degenerate": deg, "soft_edges": smooth_turns}
    return out
