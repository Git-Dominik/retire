"""Doors-style asset generators. Pure Python (no bpy needed to run/test).
Coordinates: Blender convention, Z up, 1 unit = 1 stud. Output = Mesh(v, f, tag).
Faces are triangles with outward winding. `tag` = material region per face.
"""
import math, random


class Mesh:
    def __init__(self):
        self.v, self.f, self.tag = [], [], []

    def vert(self, p):
        self.v.append((float(p[0]), float(p[1]), float(p[2])))
        return len(self.v) - 1

    def tri(self, a, b, c, tag="main", ref=None):
        """Add a triangle. If ref (a direction) is given, flip winding so the normal faces it."""
        if ref is not None:
            A, B, C = self.v[a], self.v[b], self.v[c]
            u = (B[0]-A[0], B[1]-A[1], B[2]-A[2])
            w = (C[0]-A[0], C[1]-A[1], C[2]-A[2])
            n = (u[1]*w[2]-u[2]*w[1], u[2]*w[0]-u[0]*w[2], u[0]*w[1]-u[1]*w[0])
            if n[0]*ref[0] + n[1]*ref[1] + n[2]*ref[2] < 0:
                b, c = c, b
        self.f.append((a, b, c))
        self.tag.append(tag)

    def quad(self, a, b, c, d, tag="main", ref=None):
        self.tri(a, b, c, tag, ref)
        self.tri(a, c, d, tag, ref)


def translate(m, off):
    m.v = [(x+off[0], y+off[1], z+off[2]) for x, y, z in m.v]
    return m


def merge(dst, src, off=(0, 0, 0)):
    base = len(dst.v)
    dst.v += [(x+off[0], y+off[1], z+off[2]) for x, y, z in src.v]
    dst.f += [(a+base, b+base, c+base) for a, b, c in src.f]
    dst.tag += src.tag
    return dst


def stats(m):
    xs, ys, zs = zip(*m.v)
    vol, degenerate = 0.0, 0
    for a, b, c in m.f:
        A, B, C = m.v[a], m.v[b], m.v[c]
        vol += (A[0]*(B[1]*C[2]-B[2]*C[1]) - A[1]*(B[0]*C[2]-B[2]*C[0]) + A[2]*(B[0]*C[1]-B[1]*C[0])) / 6.0
        u = (B[0]-A[0], B[1]-A[1], B[2]-A[2]); w = (C[0]-A[0], C[1]-A[1], C[2]-A[2])
        n = (u[1]*w[2]-u[2]*w[1], u[2]*w[0]-u[0]*w[2], u[0]*w[1]-u[1]*w[0])
        if math.sqrt(n[0]**2 + n[1]**2 + n[2]**2) < 1e-9:
            degenerate += 1
    return {"tris": len(m.f), "bbox": (round(max(xs)-min(xs), 3), round(max(ys)-min(ys), 3), round(max(zs)-min(zs), 3)),
            "signed_volume": round(vol, 4), "degenerate_tris": degenerate}


# ---------------------------------------------------------------- boxes
_AX = "xyz"


def chamfer_box(m, lo, hi, c, tag="main", skip=()):
    """Box with exactly ONE flat 45-degree chamfer segment on every edge (44 tris).
    skip = [(axis, side)] faces to omit (axis 0/1/2, side 0=min 1=max), e.g. faces hidden against another part."""
    cen = [(lo[i]+hi[i])/2 for i in range(3)]
    V = {}
    for sx in (0, 1):
        for sy in (0, 1):
            for sz in (0, 1):
                s = (sx, sy, sz)
                X = [hi[i] if s[i] else lo[i] for i in range(3)]
                I = [X[i]-c if s[i] else X[i]+c for i in range(3)]
                V[s+("x",)] = m.vert((X[0], I[1], I[2]))
                V[s+("y",)] = m.vert((I[0], X[1], I[2]))
                V[s+("z",)] = m.vert((I[0], I[1], X[2]))

    def add(ids):
        pts = [m.v[i] for i in ids]
        ctr = [sum(p[j] for p in pts)/len(pts) for j in range(3)]
        ref = tuple(ctr[j]-cen[j] for j in range(3))
        for k in range(1, len(ids)-1):
            m.tri(ids[0], ids[k], ids[k+1], tag, ref)

    for ai in range(3):                       # 6 flat faces
        o1, o2 = [j for j in range(3) if j != ai]
        for side in (0, 1):
            if (ai, side) in skip:
                continue
            ids = []
            for p, q in ((0, 0), (1, 0), (1, 1), (0, 1)):
                sg = [0, 0, 0]; sg[ai] = side; sg[o1] = p; sg[o2] = q
                ids.append(V[tuple(sg)+(_AX[ai],)])
            add(ids)
    for ai in range(3):                       # 12 chamfer strips
        o1, o2 = [j for j in range(3) if j != ai]
        for p, q in ((0, 0), (1, 0), (1, 1), (0, 1)):
            A = [0, 0, 0]; B = [0, 0, 0]
            A[o1] = B[o1] = p; A[o2] = B[o2] = q; A[ai] = 0; B[ai] = 1
            A, B = tuple(A), tuple(B)
            add([V[A+(_AX[o1],)], V[A+(_AX[o2],)], V[B+(_AX[o2],)], V[B+(_AX[o1],)]])
    for sx in (0, 1):                         # 8 corner triangles
        for sy in (0, 1):
            for sz in (0, 1):
                s = (sx, sy, sz)
                add([V[s+("x",)], V[s+("y",)], V[s+("z",)]])
    return m


def plain_box(m, lo, hi, tag="main", skip=()):
    """Plain 8-vertex box (12 tris), for parts that stay hidden-chamfer-free (page block)."""
    cen = [(lo[i]+hi[i])/2 for i in range(3)]
    V = {}
    for sx in (0, 1):
        for sy in (0, 1):
            for sz in (0, 1):
                s = (sx, sy, sz)
                V[s] = m.vert([hi[i] if s[i] else lo[i] for i in range(3)])
    for ai in range(3):
        o1, o2 = [j for j in range(3) if j != ai]
        for side in (0, 1):
            if (ai, side) in skip:
                continue
            ids = []
            for p, q in ((0, 0), (1, 0), (1, 1), (0, 1)):
                sg = [0, 0, 0]; sg[ai] = side; sg[o1] = p; sg[o2] = q
                ids.append(V[tuple(sg)])
            pts = [m.v[i] for i in ids]
            ctr = [sum(p_[j] for p_ in pts)/4 for j in range(3)]
            ref = tuple(ctr[j]-cen[j] for j in range(3))
            m.quad(*ids, tag=tag, ref=ref)
    return m


# ---------------------------------------------------------------- BOOK
def gen_book(w=1.2, d=1.7, t=0.4, board=0.07, inset_frac=0.03, chamfer_frac=0.05, spine_w=0.08, bands=2):
    """Three-layer book lying flat: X = width, Y = depth, Z = thickness. Spine on the -X edge.
    Layers: bottom cover board, page block (inset 3% of smallest dim on the 3 open sides),
    top cover board (overhangs the pages by the same 3%), plus a spine that is its own chamfered
    face standing proud of the covers by the same amount. Tags: cover / pages / spine / band.
    Spine bands (bands=0/1/2) are thin low-relief strips, tag 'band' (its own colour/material region).
    ~150 tris. Origin = bottom centre."""
    m = Mesh()
    small = min(w, d, t)
    ins = inset_frac*small
    c = chamfer_frac*small
    chamfer_box(m, (spine_w, 0, 0), (w, d, board), c, "cover", skip=[(0, 0)])          # bottom board
    chamfer_box(m, (spine_w, 0, t-board), (w, d, t), c, "cover", skip=[(0, 0)])        # top board
    plain_box(m, (spine_w, ins, board), (w-ins, d-ins, t-board), "pages",
              skip=[(0, 0), (2, 0), (2, 1)])                                           # page block
    chamfer_box(m, (-ins, 0, 0), (spine_w, d, t), c, "spine", skip=[(0, 1)])           # spine
    if bands:                                                                          # 1-2 thin low-relief band strips (no textures in Roblox style)
        bw = 0.07*d; prud = 0.012
        for y0 in ([0.13*d, 0.80*d] if bands >= 2 else [0.13*d]):
            plain_box(m, (-ins-prud, y0, 1.6*c), (-ins+0.004, y0+bw, t-1.6*c), "band", skip=[(0, 1)])
    xs = [v[0] for v in m.v]
    translate(m, (-(max(xs)+min(xs))/2, -d/2, 0))
    return m


# ---------------------------------------------------------------- lathe helper
def _lathe_band(m, ring_a, ring_b, nr, nz, tag, n=8):
    """Quads between two 8-vertex rings; (nr, nz) = nominal outward profile normal."""
    for k in range(n):
        a, b = ring_a[k], ring_a[(k+1) % n]
        c, d = ring_b[(k+1) % n], ring_b[k]
        for tri in ((a, b, c), (a, c, d)):
            pts = [m.v[i] for i in tri]
            cx = sum(p[0] for p in pts)/3; cy = sum(p[1] for p in pts)/3
            ang = math.atan2(cy, cx)
            m.tri(*tri, tag, (math.cos(ang)*nr, math.sin(ang)*nr, nz))


def _cap(m, center, ring, nz, tag, n=8):
    for k in range(n):
        m.tri(center, ring[k], ring[(k+1) % n], tag, (0, 0, nz))


# ---------------------------------------------------------------- POT
def gen_pot(pot_w=2.2, pot_h=2.0):
    """Tapered 8-sided pot: thin top lip, small foot flare, open top with inner wall down to the
    soil level (0.85*pot_h). Origin = bottom centre. ~112 tris, closed. Tag: pot."""
    P = [(0.38, 0.00), (0.33, 0.08), (0.44, 0.92), (0.50, 0.92),
         (0.50, 1.00), (0.43, 1.00), (0.42, 0.85)]            # (radius*pot_w, z*pot_h), circumradius
    m = Mesh()
    rings = []
    for rf, zf in P:
        rings.append([m.vert((rf*pot_w/math.cos(math.pi/8)*math.cos(math.pi/8 + 2*math.pi*k/8),
                              rf*pot_w/math.cos(math.pi/8)*math.sin(math.pi/8 + 2*math.pi*k/8), zf*pot_h)) for k in range(8)])
    for i in range(len(P)-1):
        dr = (P[i+1][0]-P[i][0])*pot_w
        dz = (P[i+1][1]-P[i][1])*pot_h
        _lathe_band(m, rings[i], rings[i+1], dz, -dr, "pot")
    _cap(m, m.vert((0, 0, 0)), rings[0], -1, "pot")
    _cap(m, m.vert((0, 0, P[-1][1]*pot_h)), rings[-1], 1, "pot")   # cavity floor, hidden under soil
    return m


# ---------------------------------------------------------------- SOIL
def gen_soil(pot_w=2.2, seed=3):
    """Lumpy mounded soil: centre hub + mid ring + rim ring, bumps <= 9% of pot width. 24 tris.
    Origin = rim level at pot axis. Tag: soil."""
    rng = random.Random(seed)
    R = 0.42*pot_w
    m = Mesh()
    outer = [m.vert((R*math.cos(math.pi/8 + 2*math.pi*k/8), R*math.sin(math.pi/8 + 2*math.pi*k/8),
                     rng.uniform(0.0, 0.015)*pot_w)) for k in range(8)]
    mid = [m.vert((0.62*R*math.cos(2*math.pi*k/8 + rng.uniform(-.2, .2)),
                   0.62*R*math.sin(2*math.pi*k/8 + rng.uniform(-.2, .2)),
                   rng.uniform(0.03, 0.09)*pot_w)) for k in range(8)]
    hub = m.vert((0, 0, rng.uniform(0.06, 0.09)*pot_w))
    for k in range(8):
        k2 = (k+1) % 8
        m.quad(outer[k], outer[k2], mid[k2], mid[k], "soil", (0, 0, 1))
        m.tri(hub, mid[k], mid[k2], "soil", (0, 0, 1))
    return m


# ---------------------------------------------------------------- TRUNK
def gen_trunk(pot_w=2.2, foliage_h=3.8, lean_deg=12, kink_deg=10, sides=4, seed=2):
    """Short chunky faceted trunk: square section, base flare, taper, lean + one kink, 3 segments.
    Visible length = 12% of foliage height, plus 10% buried in the foliage. 24 tris (no hidden caps).
    Origin = where it meets the soil. Tag: trunk."""
    rng = random.Random(seed)
    L = 0.12*foliage_h + 0.10*foliage_h
    r0 = 0.11*pot_w
    phi = rng.uniform(0, 2*math.pi)
    stations = [(0.00, 1.35), (0.15, 1.00), (0.55, 0.88), (1.00, 0.74)]          # (z fraction, radius mult)
    seg_angles = [lean_deg, lean_deg+kink_deg, lean_deg-0.5*kink_deg]
    m = Mesh()
    rings, centers, off, prev_z = [], [], 0.0, 0.0
    for i, (zf, rm) in enumerate(stations):
        z = zf*L
        if i > 0:
            off += math.tan(math.radians(seg_angles[i-1]))*(z-prev_z)
        prev_z = z
        cx, cy = math.cos(phi)*off, math.sin(phi)*off
        tw = rng.uniform(-0.10, 0.10)
        ring = [m.vert((cx + r0*rm*math.cos(math.pi/4 + tw + 2*math.pi*j/sides),
                        cy + r0*rm*math.sin(math.pi/4 + tw + 2*math.pi*j/sides), z)) for j in range(sides)]
        rings.append(ring); centers.append((cx, cy))
    for i in range(len(rings)-1):
        cx = (centers[i][0]+centers[i+1][0])/2; cy = (centers[i][1]+centers[i+1][1])/2
        for j in range(sides):
            a, b = rings[i][j], rings[i][(j+1) % sides]
            c, d = rings[i+1][(j+1) % sides], rings[i+1][j]
            for tri in ((a, b, c), (a, c, d)):
                pts = [m.v[q] for q in tri]
                ref = (sum(p[0] for p in pts)/3 - cx, sum(p[1] for p in pts)/3 - cy, 0)
                m.tri(*tri, "trunk", ref)
    return m


# ---------------------------------------------------------------- FOLIAGE
def gen_foliage(pot_w=2.2, pot_h=2.0, height_mult=1.9, width_mult=1.25,
                n_shards=44, double_sided=False, seed=1):
    """Ragged tapered-column foliage, widest at ~38% of height, blunt flattish top, flat-shaded.
    Lathe (8-sided, 6 rings) + random radial/vertical displacement + 3 big lumps + ~35% of facets
    split into 3 (mixed facet sizes) + n_shards folded leaf blades (2 tris each, single-sided,
    pointing up and out so they shingle over the surface like clipped-shrub leaves).
    ~245 tris with defaults. Origin = bottom centre of the mass. Tags: leaf / shard."""
    rng = random.Random(seed)
    H = pot_h*height_mult
    R = pot_w*width_mult/2
    prof = [(0.62, 0.00), (0.90, 0.16), (1.00, 0.38), (0.84, 0.60), (0.56, 0.80), (0.34, 0.94)]
    m = Mesh()
    rings = []
    for rf, tf in prof:
        ring = []
        for k in range(8):
            ang = math.pi/8 + 2*math.pi*k/8 + rng.uniform(-0.10, 0.10)
            r = rf*R*(1 + rng.uniform(-0.10, 0.10))
            ring.append(m.vert((r*math.cos(ang), r*math.sin(ang), tf*H + rng.uniform(-0.03, 0.03)*H)))
        rings.append(ring)
    for _ in range(3):                                     # larger lumps / notches
        i = rng.randrange(1, 5); k = rng.randrange(8)
        x, y, z = m.v[rings[i][k]]
        s = rng.choice([1.18, 1.22, 0.82])
        m.v[rings[i][k]] = (x*s, y*s, z)
    bc = m.vert((0, 0, 0)); tc = m.vert((0, 0, H))
    band_ids = []
    for i in range(len(prof)-1):
        dr = (prof[i+1][0]-prof[i][0])*R; dz = (prof[i+1][1]-prof[i][1])*H
        before = len(m.f)
        _lathe_band(m, rings[i], rings[i+1], dz, -dr, "leaf")
        band_ids += list(range(before, len(m.f)))
    _cap(m, bc, rings[0], -1, "leaf")
    _cap(m, tc, rings[-1], 1, "leaf")
    # split ~35% of band facets into 3 around a pushed-in/out centroid -> mixed facet sizes
    split = set(rng.sample(band_ids, int(0.35*len(band_ids))))
    nf, nt = [], []
    for idx, (f, tg) in enumerate(zip(m.f, m.tag)):
        if idx in split:
            a, b, c = f
            A, B, C = m.v[a], m.v[b], m.v[c]
            cx, cy, cz = [(A[j]+B[j]+C[j])/3 for j in range(3)]
            rad = math.hypot(cx, cy)
            s = (rad + rng.uniform(-0.10, 0.10)*R)/max(rad, 1e-6)
            p = m.vert((cx*s, cy*s, cz))
            nf += [(a, b, p), (b, c, p), (c, a, p)]; nt += [tg]*3
        else:
            nf.append(f); nt.append(tg)
    m.f, m.tag = nf, nt
    for _ in range(n_shards):                              # leaf blades: shingled over the whole surface
        ri = rng.choices([1, 2, 3, 4, 5], weights=[1, 3, 3, 3, 2])[0]
        p = m.v[rings[ri][rng.randrange(8)]]
        rad = math.hypot(p[0], p[1]); n = (p[0]/rad, p[1]/rad, 0.0)            # outward
        t = (-n[1], n[0], 0.0)                                                 # sideways tangent
        dvec = (0.55*n[0], 0.55*n[1], 0.85)                                    # blade points up and out
        dl = math.sqrt(sum(c*c for c in dvec)); dvec = tuple(c/dl for c in dvec)
        size = rng.uniform(0.22, 0.40)*pot_w
        wid = rng.uniform(0.30, 0.42)*size
        fold = 0.18*size                                                       # V-fold toward the outside
        P0 = tuple(p[j] - n[j]*0.06*size for j in range(3))
        def pt(a, b, lift=0.0):
            return m.vert(tuple(P0[j] + t[j]*a + dvec[j]*b + n[j]*lift for j in range(3)))
        base = pt(0, 0); lft = pt(-wid, 0.42*size, fold); rgt = pt(wid, 0.42*size, fold)
        tip = pt(rng.uniform(-0.05, 0.05)*size, size, 0.0)
        m.tri(base, lft, tip, "shard", n)
        m.tri(base, tip, rgt, "shard", n)
        if double_sided:
            m.tri(base, lft, tip, "shard", tuple(-c for c in n))
            m.tri(base, tip, rgt, "shard", tuple(-c for c in n))
    zs = [v[2] for v in m.v]
    translate(m, (0, 0, -min(zs)))
    return m


# ---------------------------------------------------------------- PLANT (pot + soil + trunk + foliage)
def gen_plant(pot_w=2.2, pot_h=2.0, seed=1):
    """Returns dict of 4 separate meshes already positioned in plant space (origin = bottom centre
    of the pot). Material tags: pot / soil / trunk / leaf+shard. Total tris ~ 430 (budget < 600)."""
    soil_z = 0.85*pot_h
    foliage_h = pot_h*1.9
    pot = gen_pot(pot_w, pot_h)
    soil = translate(gen_soil(pot_w, seed+2), (0, 0, soil_z))
    trunk = translate(gen_trunk(pot_w, foliage_h, seed=seed+1), (0, 0, soil_z + 0.04*pot_w))
    foliage = translate(gen_foliage(pot_w, pot_h, seed=seed), (0, 0, soil_z + 0.04*pot_w + 0.12*foliage_h))
    return {"pot": pot, "soil": soil, "trunk": trunk, "foliage": foliage}


# ---------------------------------------------------------------- WALL CLOCK
def _rot_front(m):
    """local (x, y, z) with z = front, y = up  ->  Blender (x, -z, y): front faces -Y, back at y = 0."""
    m.v = [(x, -z, y) for x, y, z in m.v]
    return m


def gen_clock(R=1.5, hour_deg=305, minute_deg=60, wedge=False, plate=False):
    """Classic octagonal WALL clock. R = half flat-to-flat (R=1.5 -> 3 studs across, ~0.4 deep).
    Parts: thick chamfered dark bezel, recessed light face, 12 inward-pointing triangle ticks
    (4 bigger at 12/3/6/9), octagonal hub, two chunky kite-shaped hands (hour under minute).
    Optional extras (use at most ONE, they are off by default): a flat accent wedge, or a dark centre plate.
    Angles are clockwise from 12 o'clock; defaults read 10:10. ~145 tris (+~40 with plate).
    Pivot = back centre, front faces -Y. Tags: bezel / face / tick / hand / hub / accent / plate."""
    m = Mesh()
    Rc = R/math.cos(math.pi/8)
    P = [(0.94, 0.00), (1.00, 0.06), (1.00, 0.20), (0.94, 0.26), (0.82, 0.26), (0.78, 0.12)]
    ang = [math.pi/8 + 2*math.pi*k/8 for k in range(8)]
    rings = [[m.vert((rf*Rc*math.cos(a), rf*Rc*math.sin(a), zf*R)) for a in ang] for rf, zf in P]
    for i in range(len(P)-1):
        _lathe_band(m, rings[i], rings[i+1], (P[i+1][1]-P[i][1])*R, -(P[i+1][0]-P[i][0])*Rc, "bezel")
    _cap(m, m.vert((0, 0, 0)), rings[0], -1, "bezel")
    zf0 = P[-1][1]*R                                       # face plane
    _cap(m, m.vert((0, 0, zf0)), rings[-1], 1, "face")

    def d2(th):                                            # clockwise-from-12 unit vector in the face plane
        t = math.radians(th); return (math.sin(t), math.cos(t))

    z = zf0 + 0.006*R
    for k in range(12):                                    # ticks: triangles pointing inward, base at the rim
        major = (k % 3 == 0)
        dx, dy = d2(k*30); px, py = dy, -dx
        ro = 0.72*R; ri = ro - (0.22 if major else 0.14)*R; hw = (0.07 if major else 0.045)*R
        a = m.vert((dx*ro + px*hw, dy*ro + py*hw, z)); b = m.vert((dx*ro - px*hw, dy*ro - py*hw, z))
        c = m.vert((dx*ri, dy*ri, z))
        m.tri(a, b, c, "tick", (0, 0, 1))
    if wedge:                                              # flat accent sector (e.g. lower-left like the reference)
        zw = zf0 + 0.003*R; c0 = m.vert((0, 0, zw)); pts = []
        for th in (200, 225, 250, 275):
            dx, dy = d2(th); pts.append(m.vert((dx*0.74*R, dy*0.74*R, zw)))
        for a, b in zip(pts, pts[1:]):
            m.tri(c0, a, b, "accent", (0, 0, 1))
    if plate:
        chamfer_box(m, (-0.34*R, -0.13*R, zf0), (0.34*R, 0.13*R, zf0 + 0.03*R), 0.012*R, "plate", skip=[(2, 0)])
    hr = [(0.075*R, 0.0), (0.075*R, 0.075*R), (0.05*R, 0.10*R)]   # hub
    hring = [[m.vert((r/math.cos(math.pi/8)*math.cos(a), r/math.cos(math.pi/8)*math.sin(a), zf0 + dz))
              for a in ang] for r, dz in hr]
    for i in range(len(hr)-1):
        _lathe_band(m, hring[i], hring[i+1], hr[i+1][1]-hr[i][1], -(hr[i+1][0]-hr[i][0]), "hub")
    _cap(m, m.vert((0, 0, zf0 + 0.10*R)), hring[-1], 1, "hub")

    def hand(L, w, z0, th, deg):
        dx, dy = d2(deg); px, py = dy, -dx
        k = [(-0.16*L, 0), (0.14*L, w), (L, 0), (0.14*L, -w)]
        fr = [m.vert((dx*u + px*v, dy*u + py*v, z0 + th)) for u, v in k]
        bk = [m.vert((dx*u + px*v, dy*u + py*v, z0)) for u, v in k]
        m.quad(*fr, tag="hand", ref=(0, 0, 1))
        for i in range(4):
            j = (i+1) % 4
            mx = (m.v[fr[i]][0] + m.v[fr[j]][0])/2 - (m.v[fr[0]][0] + m.v[fr[2]][0])/2
            my = (m.v[fr[i]][1] + m.v[fr[j]][1])/2 - (m.v[fr[0]][1] + m.v[fr[2]][1])/2
            m.quad(fr[i], fr[j], bk[j], bk[i], tag="hand", ref=(mx, my, 0))
    hand(0.48*R, 0.085*R, zf0 + 0.02*R, 0.03*R, hour_deg)
    hand(0.70*R, 0.070*R, zf0 + 0.05*R, 0.03*R, minute_deg)
    return _rot_front(m)


# ---------------------------------------------------------------- palette + auto materials + review rig (Blender only)
PALETTE = {  # tag: (Color3 hex, Roblox Enum.Material). STARTER mapping: confirm in Studio (Sec. 2D). No custom textures.
    "cover": ("#8E4636", "Fabric"), "spine": ("#8E4636", "Fabric"), "band": ("#E3B88A", "Fabric"),
    "pages": ("#E3B88A", "SmoothPlastic"),
    "pot": ("#A4432E", "Wood"), "soil": ("#3B332C", "Ground"), "trunk": ("#8A6A48", "Wood"),
    "leaf": ("#5E5B2C", "LeafyGrass"), "shard": ("#76703A", "LeafyGrass"),
    "bezel": ("#3A2D28", "Wood"), "face": ("#D4C3A0", "Plastic"), "tick": ("#3A2D28", "Plastic"),
    "hand": ("#2A2320", "Plastic"), "hub": ("#2A2320", "Plastic"), "accent": ("#A8503C", "Plastic"),
    "plate": ("#1C1A1A", "SmoothPlastic"),
    "dome": ("#9A7B5A", "Metal"), "base": ("#3A2D28", "Metal"), "emissive": ("#FFD58A", "Neon"),
}


def _lin(h):
    c = [int(h[i:i+2], 16)/255 for i in (1, 3, 5)]
    return [(x/12.92 if x <= 0.04045 else ((x+0.055)/1.055)**2.4) for x in c]


def make_materials():
    """Blender PREVIEW materials only (flat colour per tag so nothing renders gray). The real look in Roblox
    comes from the built-in Material + Color3 stored on each part (see to_blender / luau_apply_script)."""
    import bpy
    out = {}
    for tag, (hx, rmat) in PALETTE.items():
        mat = bpy.data.materials.get("PREVIEW_" + tag) or bpy.data.materials.new("PREVIEW_" + tag)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = _lin(hx) + [1.0]
        bsdf.inputs["Roughness"].default_value = 0.5 if rmat in ("Metal", "SmoothPlastic") else 0.85
        bsdf.inputs["Metallic"].default_value = 0.6 if rmat == "Metal" else 0.0
        mat.diffuse_color = _lin(hx) + [1.0]
        out[tag] = mat
    return out


def setup_review_rig(target=(0, 0, 1.5), distance=11.0):
    """Sec. 2C.7 rig: dark warm world #2A211C, ONE warm point light #FFD58A upper-front, camera ~3x object width,
    and every 3D viewport switched to Material Preview so colours show (Solid mode is NOT a review)."""
    import bpy, mathutils
    w = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = _lin("#2A211C") + [1.0]
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
    ld = bpy.data.lights.new("ReviewKey", "POINT"); ld.color = _lin("#FFD58A")[:3]; ld.energy = 1500
    lo = bpy.data.objects.new("ReviewKey", ld); bpy.context.collection.objects.link(lo)
    lo.location = (target[0] - 2.0, target[1] - 6.0, target[2] + 5.0)
    cd = bpy.data.cameras.new("ReviewCam"); co = bpy.data.objects.new("ReviewCam", cd)
    bpy.context.collection.objects.link(co)
    co.location = (target[0], target[1] - distance, target[2] + 2.0)
    direction = mathutils.Vector(target) - co.location
    co.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            for sp in area.spaces:
                if sp.type == "VIEW_3D":
                    sp.shading.type = "MATERIAL"
    return co, lo


# ---------------------------------------------------------------- Blender glue (needs bpy; UNTESTED outside Blender)
def to_blender(name, mesh, location=(0, 0, 0)):
    """Roblox-style export: a MeshPart holds ONE Material + Color3, so every tag becomes its OWN Blender object
    named <name>_<tag>, grouped under an Empty called <name> (becomes a Model in Studio).
    Each object gets custom properties roblox_material (Enum.Material name) and roblox_color (hex), flat shading,
    and a flat PREVIEW material. Returns the list of part objects. Run luau_apply_script(parts) for the Studio side."""
    import bpy
    group = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(group); group.location = location
    mats = make_materials(); parts = []
    for tg in sorted(set(mesh.tag)):
        idx = [i for i, t in enumerate(mesh.tag) if t == tg]
        used = sorted({v for i in idx for v in mesh.f[i]}); remap = {v: k for k, v in enumerate(used)}
        me = bpy.data.meshes.new(f"{name}_{tg}")
        me.from_pydata([mesh.v[v] for v in used], [], [tuple(remap[v] for v in mesh.f[i]) for i in idx])
        me.update()
        for poly in me.polygons:
            poly.use_smooth = False                       # flat-shaded; only a bell dome (built separately) is smooth
        ob = bpy.data.objects.new(f"{name}_{tg}", me)
        bpy.context.collection.objects.link(ob); ob.parent = group
        hx, rmat = PALETTE.get(tg, ("#808080", "Plastic"))
        ob["roblox_material"] = rmat; ob["roblox_color"] = hx
        me.materials.append(mats.get(tg) or bpy.data.materials.new("PREVIEW_" + tg))
        parts.append(ob)
    return parts


def luau_apply_script(parts):
    """Returns Luau text to paste into the Studio command bar AFTER importing the meshes (select the imported Model).
    It sets Material and Color on each MeshPart by name. Roblox's built-in materials only: no textures."""
    rows = ",\n".join(f'\t["{o.name}"] = {{Enum.Material.{o["roblox_material"]}, Color3.fromHex("{o["roblox_color"]}")}}'
                      for o in parts)
    return ("local map = {\n" + rows + "\n}\n"
            "local function apply(p)\n"
            "\tlocal m = p:IsA('MeshPart') and map[p.Name]\n"
            "\tif m then p.Material, p.Color = m[1], m[2] end\n"
            "end\n"
            "for _, root in ipairs(game:GetService('Selection'):Get()) do\n"
            "\tapply(root)\n"
            "\tfor _, p in ipairs(root:GetDescendants()) do apply(p) end\n"
            "end\n")


def handoff_manifest(group_name, parts):
    """Markdown table the user can follow by hand in Studio: mesh name -> Roblox Material -> Color3 -> tris."""
    rows = ["| Mesh name (must match in Studio) | Roblox Material | Color3 | Tris |", "|---|---|---|---|"]
    for o in parts:
        rows.append(f'| {o.name} | {o["roblox_material"]} | {o["roblox_color"]} | {len(o.data.polygons)} |')
    return f"# Studio hand-off: {group_name}\n\n" + "\n".join(rows) + "\n"


def write_handoff(folder, group_name, parts):
    """Writes <group>_apply_materials.luau and <group>_manifest.md into `folder` and returns both paths.
    Call this AFTER the final part names are set; if you rename any mesh, call it again."""
    import os
    lp = os.path.join(folder, f"{group_name}_apply_materials.luau")
    mp = os.path.join(folder, f"{group_name}_manifest.md")
    with open(lp, "w") as f:
        f.write(luau_apply_script(parts))
    with open(mp, "w") as f:
        f.write(handoff_manifest(group_name, parts))
    return lp, mp
