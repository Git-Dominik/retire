import math

import dtk
from dtk import Builder, v

# Two-high mill stand. Line runs along X, rolls along Y. Origin: floor under the roll centre.
# Drive (spindles, gearbox, motor) on the -Y side, matching the old stand-in's layout.

PASS = 2.85  # top of the conveyor rollers
RR = 0.9  # work roll radius (half flat-to-flat)


def build():
    m = Builder()
    zb = PASS - RR  # bottom roll centre
    zt = zb + 2 * RR + 0.15  # top roll centre
    hy0, hy1 = 2.1, 3.5  # housing inner / outer face (each side)
    post_x0, post_x1 = 1.0, 2.0
    sole_top = 0.6
    top_z0, top_z1 = 6.0, 7.0

    for s in (-1, 1):
        ya, yb = sorted((s * hy0, s * hy1))
        # soleplate with anchor bosses
        sa, sb = sorted((s * 1.7, s * 4.1))
        m.box("Dark", (-2.15, sa, 0), (2.15, sb, sole_top), c=0.06, flat=("-z",))
        for x in (-1.75, 1.75):
            for y in (s * 1.95, s * 3.85):
                m.cyl("Dark", (x, y, sole_top - 0.02), (x, y, sole_top + 0.14), 0.13)
        # housing window: two posts full height, top and bottom beams buried between them
        for sx in (-1, 1):
            xa, xb = sorted((sx * post_x0, sx * post_x1))
            m.box("Paint", (xa, ya, sole_top), (xb, yb, top_z1), c=0.07, axes="z", flat=())
        m.box("Paint", (-post_x0 - 0.1, ya, top_z0), (post_x0 + 0.1, yb, top_z1))
        m.box("Paint", (-post_x0 - 0.1, ya, sole_top), (post_x0 + 0.1, yb, 1.0))
        # tie-bolt nuts on the posts' outer faces
        for sx in (-1, 1):
            for z in (1.6, 6.5):
                x0 = sx * post_x1
                m.cyl("Dark", (x0 - sx * 0.02, (ya + yb) / 2, z), (x0 + sx * 0.16, (ya + yb) / 2, z), 0.22)
        # chocks holding the roll necks
        m.box("Dark", (-post_x0, ya - 0.05, 1.0), (post_x0, yb + 0.05, zb + 0.75), c=0.05, flat=("-z",))
        m.box("Dark", (-post_x0, ya - 0.05, zt - 0.75), (post_x0, yb + 0.05, top_z0), c=0.05, flat=("+z",))

    # work rolls (hero): chamfered barrels, necks into the chocks, groove ridges
    for zc in (zb, zt):
        m.cyl("Roll", (0, -hy0 + 0.25, zc), (0, hy0 - 0.25, zc), RR, c=0.12)
        m.cyl("Roll", (0, -hy1 - 0.05, zc), (0, hy1 - 0.1, zc), 0.5)
        for y in (-1.05, -0.35, 0.35, 1.05):
            m.lathe("Roll", [(RR + 0.04, 0), (RR + 0.04, 0.12)], (0, y - 0.06, zc), (0, 1, 0))

    # crossbeam over both housings, screwdown boxes, handwheel (operating detail)
    m.box("Paint", (-1.3, -hy1 - 0.1, top_z1), (1.3, hy1 + 0.1, top_z1 + 0.7), c=0.07, flat=("-z",))
    for y in (-(hy0 + hy1) / 2, (hy0 + hy1) / 2):
        m.lathe("Paint", [(0.6, 0), (0.6, 0.7), (0.48, 0.82)], (0, y, top_z1 + 0.68))
        m.lathe("Dark", [(0.24, 0), (0.24, 0.3)], (0, y, top_z1 + 1.48))
    wy = -(hy0 + hy1) / 2
    m.cyl("Dark", (0, wy, top_z1 + 1.75), (0, wy, top_z1 + 1.95), 0.14)
    wc = v(0, wy, top_z1 + 1.9)
    m.ring_tube("Accent", wc, (0, 0, 1), 0.55, 0.06)
    for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
        d = v(math.cos(a), math.sin(a), 0)
        m.tube("Accent", [wc + d * 0.1, wc + d * 0.52], 0.04)

    # drive: couplings, spindles, gearbox with bearing caps, motor
    gy0, gy1 = -8.7, -12.1
    for zc in (zb, zt):
        m.cyl("Dark", (0, -hy1 - 0.05, zc), (0, -hy1 - 0.65, zc), 0.62, c=0.08)
        m.cyl("Roll", (0, -hy1 - 0.6, zc), (0, gy0 + 0.55, zc), 0.36)
        m.cyl("Dark", (0, gy0 + 0.6, zc), (0, gy0 - 0.05, zc), 0.62, c=0.08)
    my0, my1 = gy1, gy1 - 2.0
    m.box("Dark", (-2.0, my1 - 0.3, 0), (2.0, gy0 + 0.2, 0.45), c=0.05, flat=("-z",))
    m.box("Paint", (-1.7, gy1, 0.45), (1.7, gy0, 4.6), c=0.08, flat=("-z",))
    m.box("Paint", (-1.85, gy1 - 0.1, 2.35), (1.85, gy0 + 0.1, 2.6), c=0.04)
    m.box("Dark", (-0.8, my1 - 0.1, 0.45), (0.8, my0, 0.95), flat=("-z",))
    m.cyl("Paint", (0, my0 + 0.05, 1.8), (0, my1, 1.8), 0.95, c=0.12)
    for y in (my0 - 0.6, my0 - 1.2):
        m.lathe("Paint", [(0.99, 0), (0.99, 0.12)], (0, y, 1.8), (0, -1, 0))
    m.lathe("Dark", [(0.8, 0), (0.8, 0.25), (0.55, 0.4)], (0, my1 + 0.02, 1.8), (0, -1, 0))
    return m


PALETTE = {
    "Paint": ("#5C6B42", "Metal"),
    "Roll": ("#8C8780", "Metal"),
    "Dark": ("#2E2A24", "DiamondPlate"),
    "Accent": ("#E8A21E", "Metal"),
}
