"""Three Doors-style wall lights for the pawn shop, built on the guide's Sec. 17 helpers.
Blender coords: Z up, 1 unit = 1 stud, wall plane at y = 0, fixture reaches toward -Y.
Pivot = back centre of the backplate. Every tag becomes one MeshPart (one Material + Color3).
"""
import math
import random

import doors_generators as g

C8 = math.cos(math.pi / 8)


def lathe(profile, tag, sx=1.0, sy=1.0, cap_lo=True, cap_hi=True, jitter=None, rng=None):
    """8-sided lathe around local Z. profile = [(flat-to-flat radius, z)], flats face +-X / +-Y.
    sx/sy stretch the plan (an elongated octagon). jitter = (radial, z) random wobble per vertex."""
    m = g.Mesh()
    rings = []
    for r, z in profile:
        ring = []
        for k in range(8):
            a = math.pi / 8 + 2 * math.pi * k / 8
            rr, zz = r / C8, z
            if jitter:
                rr *= 1 + rng.uniform(-jitter[0], jitter[0])
                zz += rng.uniform(-jitter[1], jitter[1])
            ring.append(m.vert((rr * math.cos(a) * sx, rr * math.sin(a) * sy, zz)))
        rings.append(ring)
    for i in range(len(profile) - 1):
        dr = profile[i + 1][0] - profile[i][0]
        dz = profile[i + 1][1] - profile[i][1]
        g._lathe_band(m, rings[i], rings[i + 1], dz, -dr, tag)
    if cap_lo:
        g._cap(m, m.vert((0, 0, profile[0][1])), rings[0], -1, tag)
    if cap_hi:
        g._cap(m, m.vert((0, 0, profile[-1][1])), rings[-1], 1, tag)
    return m


def out_of_wall(m):
    """Local lathe axis Z -> -Y (out of the wall), local Y -> up. A proper rotation, winding kept."""
    m.v = [(x, -z, y) for x, y, z in m.v]
    return m


def backplate(tag, w, h, t, ch):
    """Elongated octagonal plate on the wall: one 45-degree chamfer on the front edge, no back face."""
    r = w / 2
    prof = [(r, 0.0), (r, t - ch), (r - ch, t)]
    return out_of_wall(lathe(prof, tag, sy=h / w, cap_lo=False))


def sweep(points, tag, h, cut=0.55, cap_start=False, cap_end=False):
    """Chamfered-square tube along a polyline in the YZ plane (x = 0): 8-sided section with
    flat 45-degree corner cuts, so the arm keeps crisp single-segment chamfers."""
    m = g.Mesh()
    c = h * cut
    sec = [(h, c), (c, h), (-c, h), (-h, c), (-h, -c), (-c, -h), (c, -h), (h, -c)]
    rings, ctrs = [], []
    n = len(points)
    for i, p in enumerate(points):
        a, b = points[max(i - 1, 0)], points[min(i + 1, n - 1)]
        ty, tz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(ty, tz)
        ty, tz = ty / L, tz / L
        uy, uz = -tz, ty  # perpendicular to the path, in the YZ plane
        rings.append([m.vert((sx, p[0] + uy * su, p[1] + uz * su)) for sx, su in sec])
        ctrs.append((0.0, p[0], p[1]))
    for i in range(n - 1):
        cx = [(ctrs[i][j] + ctrs[i + 1][j]) / 2 for j in range(3)]
        for k in range(8):
            q = (rings[i][k], rings[i][(k + 1) % 8], rings[i + 1][(k + 1) % 8], rings[i + 1][k])
            pts = [m.v[j] for j in q]
            ref = tuple(sum(p_[j] for p_ in pts) / 4 - cx[j] for j in range(3))
            m.quad(*q, tag=tag, ref=ref)
    for flag, i, sgn in ((cap_start, 0, -1), (cap_end, n - 1, 1)):
        if flag:
            a, b = points[max(i - 1, 0)], points[min(i + 1, n - 1)]
            d = (0, (b[0] - a[0]) * sgn, (b[1] - a[1]) * sgn)
            ctr = m.vert(ctrs[i])
            for k in range(8):
                m.tri(ctr, rings[i][k], rings[i][(k + 1) % 8], tag, d)
    return m


def bulb(tag, r, h, down=False, small=False):
    """Chunky faceted bulb (flat-shaded), base at z = 0, growing up (or down).
    small = a 3-ring flame shape for candle tips, to stay inside the triangle budget."""
    prof = [(0.62 * r, 0.0), (0.95 * r, 0.18 * h), (1.0 * r, 0.42 * h), (0.78 * r, 0.75 * h),
            (0.38 * r, 0.96 * h)]
    if small:
        prof = [(0.6 * r, 0.0), (1.0 * r, 0.35 * h), (0.35 * r, 0.95 * h)]
    m = lathe(prof, tag)
    if down:  # mirror Z and fix winding
        m.v = [(x, y, -z) for x, y, z in m.v]
        m.f = [(a, c, b) for a, b, c in m.f]
    return m


def place(dst, src, off):
    return g.merge(dst, src, off)


# ------------------------------------------------------------------ V1 cup sconce
def gen_cup():
    m = g.Mesh()
    place(m, backplate("plate", 0.72, 1.2, 0.12, 0.04), (0, 0, 0))
    # arm: mount block, horizontal bar, upright bar (butted, never overlapping coplanar)
    g.chamfer_box(m, (-0.13, -0.20, -0.38), (0.13, -0.11, -0.12), 0.025, "arm", skip=[(1, 1)])
    g.chamfer_box(m, (-0.07, -0.48, -0.32), (0.07, -0.19, -0.18), 0.02, "arm", skip=[(1, 0), (1, 1)])
    g.chamfer_box(m, (-0.08, -0.64, -0.34), (0.08, -0.48, 0.10), 0.025, "arm", skip=[(2, 1)])
    # cup: smooth-shaded upturned octagonal shade with a shallow bulb seat
    cup_prof = [(0.11, 0.0), (0.20, 0.05), (0.29, 0.14), (0.35, 0.26), (0.37, 0.31),
                (0.32, 0.31), (0.24, 0.21)]
    place(m, lathe(cup_prof, "shade"), (0, -0.56, 0.10))
    place(m, bulb("bulb", 0.15, 0.36), (0, -0.56, 0.27))
    return m


# ------------------------------------------------------------------ V2 candle bar sconce
def gen_candle():
    rng = random.Random(7)
    m = g.Mesh()
    place(m, backplate("plate", 0.56, 1.25, 0.12, 0.04), (0, 0, 0))
    g.chamfer_box(m, (-0.07, -0.45, -0.31), (0.07, -0.11, -0.17), 0.02, "bar", skip=[(1, 0), (1, 1)])
    g.chamfer_box(m, (-0.60, -0.60, -0.33), (0.60, -0.45, -0.16), 0.025, "bar")
    for x, hgt in ((-0.56, 0.44), (0.56, 0.50)):
        drip = [(0.20, 0.0), (0.20, 0.035), (0.17, 0.065)]
        place(m, lathe(drip, "bar", cap_lo=False), (x, -0.525, -0.175))
        sleeve = [(0.115, 0.0), (0.11, hgt * 0.5), (0.105, hgt)]
        s = lathe(sleeve, "sleeve", jitter=(0.05, 0.0), rng=rng)
        # lopsided wax edge: lift two neighbouring verts of the top ring (verts 16..23)
        k = rng.randrange(8)
        for j in (16 + k, 16 + (k + 1) % 8):
            vx, vy, vz = s.v[j]
            s.v[j] = (vx, vy, vz + 0.035)
        place(m, s, (x, -0.525, -0.11))
        place(m, bulb("bulb", 0.075, 0.2, small=True), (x, -0.525, -0.11 + hgt - 0.01))
    return m


# ------------------------------------------------------------------ V3 hooded shelf light
def gen_hood():
    m = g.Mesh()
    place(m, backplate("plate", 0.52, 0.80, 0.10, 0.035), (0, 0, 0))
    g.chamfer_box(m, (-0.10, -0.17, -0.12), (0.10, -0.09, 0.08), 0.02, "arm", skip=[(1, 1)])
    neck = [(-0.17, -0.02), (-0.30, 0.10), (-0.42, 0.34), (-0.62, 0.52), (-0.86, 0.56), (-1.02, 0.50)]
    place(m, sweep(neck, "arm", 0.065), (0, 0, 0))
    top = 0.54
    # listed from the shallow underside out and up over the dome, so the lathe's normals face out
    hood_prof = [(0.22, -0.25), (0.36, -0.36), (0.45, -0.37), (0.45, -0.34), (0.39, -0.30),
                 (0.37, -0.23), (0.31, -0.12), (0.21, -0.04), (0.10, 0.0)]
    hood = lathe(hood_prof, "shade")
    place(m, hood, (0, -1.04, top))
    place(m, bulb("bulb", 0.13, 0.30, down=True), (0, -1.04, top - 0.25))
    return m


VARIANTS = {"WallLightCup": gen_cup, "WallLightCandle": gen_candle, "WallLightHood": gen_hood}

SMOOTH_TAGS = {"shade"}  # curved forms; everything else stays flat with crisp chamfers

PALETTE = {
    "WallLightCup": {"plate": ("#4A3024", "Wood"), "arm": ("#2E2724", "Metal"),
                     "shade": ("#9A7B5A", "Metal"), "bulb": ("#FFD58A", "Neon")},
    "WallLightCandle": {"plate": ("#4A3024", "Wood"), "bar": ("#2E2724", "Metal"),
                        "sleeve": ("#E3C9A0", "SmoothPlastic"), "bulb": ("#FFD58A", "Neon")},
    "WallLightHood": {"plate": ("#2E2724", "Metal"), "arm": ("#2E2724", "Metal"),
                      "shade": ("#8C6E50", "Metal"), "bulb": ("#FFD58A", "Neon")},
}


def split(m):
    """One Mesh per tag."""
    out = {}
    for tg in sorted(set(m.tag)):
        idx = [i for i, t in enumerate(m.tag) if t == tg]
        used = sorted({v for i in idx for v in m.f[i]})
        remap = {v: k for k, v in enumerate(used)}
        s = g.Mesh()
        s.v = [m.v[v] for v in used]
        s.f = [tuple(remap[v] for v in m.f[i]) for i in idx]
        s.tag = [tg] * len(idx)
        out[tg] = s
    return out


if __name__ == "__main__":
    for name, fn in VARIANTS.items():
        m = fn()
        print(name, g.stats(m))
        for tg, s in split(m).items():
            print("   ", tg, g.stats(s))
