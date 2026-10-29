import math

import dtk
from dtk import Builder, v

S = 0.70710678


def build():
    m = Builder()
    L, R = 9.0, 2.1  # shell length, half flat-to-flat
    cz = 2.95  # shell centre height
    # Shell: 8-sided drum along X, 45° chamfered ends, flats up/front
    m.lathe(
        "Shell",
        [(1.5, 0), (R, 0.6), (R, L - 0.6), (1.5, L)],
        (-L / 2, 0, cz),
        (1, 0, 0),
    )
    # weld seams between the shell's plates: the shell's own section pushed out 2%
    for sx in (-1.5, 1.5):
        m.lathe("Shell", [(R + 0.04, 0), (R + 0.04, 0.12)], (sx - 0.06, 0, cz), (1, 0, 0))
    bottom = cz - R  # 0.85
    flat = R * math.tan(math.pi / 8)  # half width of the bottom flat

    # Skid: two rails, cross members T-joined between them (buried 0.1), end member under ladder
    for s in (-1, 1):
        m.box("Frame", (-5.6, s * 1.5 - 0.2, 0), (5.0, s * 1.5 + 0.2, 0.35))
    for x in (-2.9, 0.0, 2.9, 4.65):
        m.box("Frame", (x - 0.18, -1.4, 0.04), (x + 0.18, 1.4, 0.3))
    m.box("Frame", (-5.45, -1.4, 0.0), (-4.95, 1.4, 0.35))
    # Saddles: foot pad on the rails, notched plate cradling the shell's bottom facets
    for x in (-2.9, 2.9):
        m.box("Frame", (x - 0.45, -1.75, 0.35), (x + 0.45, 1.75, 0.45), c=0.04, axes="xy", flat=("-z",))
        y1 = 1.55
        z1 = bottom + (y1 - flat)
        poly = [(-y1, 0.45), (y1, 0.45), (y1, z1), (flat, bottom), (-flat, bottom), (-y1, z1)]
        rings = [[v(xx, a, b) for a, b in poly] for xx in (x - 0.16, x + 0.16)]
        m.loft("Frame", rings)
        # stiffening rib down the saddle's outer face
        m.box("Frame", (x - 0.06, -0.12, 0.45), (x + 0.06, 0.12, bottom), flat=())

    # Ladder on the -X end: stiles rise from feet, bend over the top and run into the shell
    stile_x = -5.2
    for y in (-0.55, 0.55):
        m.box("Frame", (stile_x - 0.18, y - 0.18, 0.35), (stile_x + 0.18, y + 0.18, 0.43))
        pts = Builder.turtle(
            (stile_x, y, 0.43),
            (0, 0, 1),
            (0, 1, 0),
            [("f", 4.92), ("t", 45), ("f", 0.6), ("t", 45), ("f", 0.75), ("t", 45), ("f", 0.6), ("t", 45), ("f", 0.42)],
        )
        m.tube("Frame", pts, 0.09)
        # brace from the stile into the end disc
        m.tube("Frame", [(stile_x, y, cz + 0.6), (-L / 2 + 0.05, y, cz + 0.6)], 0.07)
    for z in (1.05, 1.75, 2.45, 3.15, 3.85, 4.55):
        m.tube("Frame", [(stile_x, -0.55, z), (stile_x, 0.55, z)], 0.07)

    top = cz + R
    # Manway (hero): collar into the top flat, bolted lid, lift handle
    mx = -1.2
    m.lathe("Fitting", [(0.75, 0), (0.75, 0.4)], (mx, 0, top - 0.05))
    m.lathe("Fitting", [(0.9, 0), (0.9, 0.1), (0.8, 0.2)], (mx, 0, top + 0.35))
    for i in range(6):
        a = math.pi / 6 + i * math.pi / 3
        m.cyl("Frame", (mx + math.cos(a) * 0.68, math.sin(a) * 0.68, top + 0.5), (mx + math.cos(a) * 0.68, math.sin(a) * 0.68, top + 0.6), 0.07)
    hp = Builder.turtle((mx - 0.3, 0, top + 0.52), (0, 0, 1), (0, 1, 0), [("f", 0.15), ("t", 45), ("f", 0.15), ("t", 45), ("f", 0.3), ("t", 45), ("f", 0.15), ("t", 45), ("f", 0.15)])
    m.tube("Fitting", hp, 0.045)

    # Vents: base flange, pipe, mushroom cap
    for vx in (1.4, 2.6):
        m.lathe("Fitting", [(0.26, 0), (0.26, 0.12)], (vx, 0, top - 0.02))
        m.cyl("Fitting", (vx, 0, top + 0.08), (vx, 0, top + 0.62), 0.12)
        m.lathe("Fitting", [(0.18, 0), (0.32, 0.12), (0.32, 0.2), (0.1, 0.3)], (vx, 0, top + 0.6))

    # Pressure gauge on a riser beside the vents
    gx = 0.4
    m.cyl("Fitting", (gx, -0.49, top - 0.05), (gx, -0.49, top + 0.5), 0.08)
    m.lathe("Fitting", [(0.32, 0), (0.32, 0.18)], (gx, -0.4, top + 0.8), (0, -1, 0))
    m.cyl("Fitting", (gx, -0.49, top + 0.4), (gx, -0.49, top + 0.55), 0.12)
    m.lathe("Shell", [(0.25, 0), (0.25, 0.03)], (gx, -0.58, top + 0.8), (0, -1, 0))
    m.box("Frame", (gx - 0.03, -0.63, top + 0.78), (gx + 0.2, -0.6, top + 0.82))

    ex = L / 2
    # End gauge + level sight tube on the +X end disc
    m.cyl("Fitting", (ex - 0.05, -0.6, cz + 0.8), (ex + 0.35, -0.6, cz + 0.8), 0.08)
    m.lathe("Fitting", [(0.36, 0), (0.36, 0.2)], (ex + 0.35, -0.6, cz + 0.8), (1, 0, 0))
    m.lathe("Shell", [(0.29, 0), (0.29, 0.03)], (ex + 0.55, -0.6, cz + 0.8), (1, 0, 0))
    m.box("Frame", (ex + 0.58, -0.62, cz + 0.78), (ex + 0.61, -0.4, cz + 0.82))
    for z in (cz - 1.0, cz + 1.1):
        m.cyl("Fitting", (ex - 0.05, 0.65, z), (ex + 0.3, 0.65, z), 0.08)
        m.lathe("Fitting", [(0.14, 0), (0.14, 0.24)], (ex + 0.3, 0.65, z - 0.12))
    m.cyl("Fitting", (ex + 0.3, 0.65, cz - 0.88), (ex + 0.3, 0.65, cz + 0.98), 0.08)

    # Outlet valve (operating detail): pipe, flanges, gate body, stem, red handwheel
    vz = cz - 1.05
    m.cyl("Fitting", (ex - 0.05, -0.2, vz), (ex + 0.5, -0.2, vz), 0.13)
    m.lathe("Fitting", [(0.22, 0), (0.22, 0.08)], (ex + 0.42, -0.2, vz), (1, 0, 0))
    m.box("Fitting", (ex + 0.5, -0.45, vz - 0.25), (ex + 0.95, 0.05, vz + 0.25), c=0.05)
    m.lathe("Fitting", [(0.22, 0), (0.22, 0.08)], (ex + 0.95, -0.2, vz), (1, 0, 0))
    m.cyl("Fitting", (ex + 1.03, -0.2, vz), (ex + 1.3, -0.2, vz), 0.13)
    m.lathe("Fitting", [(0.2, 0), (0.2, 0.1)], (ex + 1.3, -0.2, vz), (1, 0, 0))
    m.cyl("Fitting", (ex + 0.725, -0.2, vz + 0.2), (ex + 0.725, -0.2, vz + 0.62), 0.05)
    wc = v(ex + 0.725, -0.2, vz + 0.62)
    m.ring_tube("Accent", wc, (0, 0, 1), 0.32, 0.05)
    m.cyl("Accent", wc - v(0, 0, 0.05), wc + v(0, 0, 0.05), 0.09)
    for a in (0, math.pi * 2 / 3, math.pi * 4 / 3):
        d = v(math.cos(a + math.pi / 8), math.sin(a + math.pi / 8), 0)
        m.tube("Accent", [wc + d * 0.05, wc + d * 0.3], 0.03)
    return m


PALETTE = {
    "Shell": ("#B9B2A0", "Metal"),
    "Frame": ("#3A2D28", "DiamondPlate"),
    "Fitting": ("#56604E", "Metal"),
    "Accent": ("#A8402E", "SmoothPlastic"),
}
